// Supabase Edge Function: LLM Proxy (multi-provider)
//
// v2 (2026-07): 从单一 Gemini SDK 升级为多 provider fetch 直调链:
//   Gemini(多模型名依次尝试)→ Anthropic Claude Haiku → OpenAI
// 设计原则:
//   - 快速失败:单 provider 单次尝试(8s 超时),失败立刻切下一家,
//     不再做 429 重试等待(旧版重试循环导致客户端白等 10s+)
//   - 响应契约不变:{ text, category, provider } —— app 端零改动
// 环境变量(Supabase secrets):GEMINI_API_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')

// Gemini 免费层的模型可用性随时间变化(2.0-flash 免费额度已降为 0),
// 依次尝试新→旧模型名。2.5 系默认开 thinking(慢 5s+),显式关闭;
// flash-lite 优先(延迟最低,匹配任务足够)
const GEMINI_MODELS = [
  { name: 'gemini-2.5-flash-lite', disableThinking: true },
  { name: 'gemini-flash-latest', disableThinking: false },
]
const ANTHROPIC_MODEL = 'claude-haiku-4-5-20251001'
const OPENAI_MODEL = 'gpt-4o-mini'

const PER_ATTEMPT_TIMEOUT_MS = 8000

interface RequestBody {
  prompt: string
  category?: string
  generationConfig?: {
    temperature?: number
    topK?: number
    topP?: number
    maxOutputTokens?: number
  }
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function fetchWithTimeout(url: string, init: RequestInit): Promise<Response> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), PER_ATTEMPT_TIMEOUT_MS)
  return fetch(url, { ...init, signal: controller.signal }).finally(() => clearTimeout(timer))
}

// ---------- Providers ----------

async function tryGemini(prompt: string, config: Required<Pick<NonNullable<RequestBody['generationConfig']>, never>> & { temperature: number; topK: number; topP: number; maxOutputTokens: number }): Promise<{ text: string; provider: string } | null> {
  if (!GEMINI_API_KEY) return null
  for (const model of GEMINI_MODELS) {
    try {
      const generationConfig: Record<string, unknown> = {
        temperature: config.temperature,
        topK: config.topK,
        topP: config.topP,
        maxOutputTokens: config.maxOutputTokens,
      }
      if (model.disableThinking) {
        // 2.5 系默认 thinking 会拖慢 5s+,匹配/对话任务不需要
        generationConfig.thinkingConfig = { thinkingBudget: 0 }
      }
      const res = await fetchWithTimeout(
        `https://generativelanguage.googleapis.com/v1beta/models/${model.name}:generateContent?key=${GEMINI_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig,
          }),
        },
      )
      if (!res.ok) {
        console.warn(`[gemini:${model.name}] HTTP ${res.status}`)
        continue
      }
      const data = await res.json()
      const text = data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? '').join('') ?? ''
      if (text.trim()) return { text, provider: `gemini:${model.name}` }
    } catch (e) {
      console.warn(`[gemini:${model.name}] ${e instanceof Error ? e.message : e}`)
    }
  }
  return null
}

async function tryAnthropic(prompt: string, config: { temperature: number; maxOutputTokens: number }): Promise<{ text: string; provider: string } | null> {
  if (!ANTHROPIC_API_KEY) return null
  try {
    const res = await fetchWithTimeout('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: config.maxOutputTokens,
        temperature: Math.min(config.temperature, 1.0),
        messages: [{ role: 'user', content: prompt }],
      }),
    })
    if (!res.ok) {
      console.warn(`[anthropic] HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`)
      return null
    }
    const data = await res.json()
    const text = (data?.content ?? [])
      .filter((b: { type?: string }) => b.type === 'text')
      .map((b: { text?: string }) => b.text ?? '')
      .join('')
    if (text.trim()) return { text, provider: `anthropic:${ANTHROPIC_MODEL}` }
  } catch (e) {
    console.warn(`[anthropic] ${e instanceof Error ? e.message : e}`)
  }
  return null
}

async function tryOpenAI(prompt: string, config: { temperature: number; maxOutputTokens: number }): Promise<{ text: string; provider: string } | null> {
  if (!OPENAI_API_KEY) return null
  try {
    const res = await fetchWithTimeout('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        temperature: config.temperature,
        max_tokens: config.maxOutputTokens,
        messages: [{ role: 'user', content: prompt }],
      }),
    })
    if (!res.ok) {
      console.warn(`[openai] HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`)
      return null
    }
    const data = await res.json()
    const text = data?.choices?.[0]?.message?.content ?? ''
    if (text.trim()) return { text, provider: `openai:${OPENAI_MODEL}` }
  } catch (e) {
    console.warn(`[openai] ${e instanceof Error ? e.message : e}`)
  }
  return null
}

// ---------- Handler ----------

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
      )
    }

    const body: RequestBody = await req.json()
    const { prompt, category, generationConfig } = body
    if (!prompt) {
      return new Response(
        JSON.stringify({ error: 'Missing prompt' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
      )
    }

    const config = {
      temperature: generationConfig?.temperature ?? 0.7,
      topK: generationConfig?.topK ?? 40,
      topP: generationConfig?.topP ?? 0.95,
      maxOutputTokens: generationConfig?.maxOutputTokens ?? 1024,
    }

    const started = Date.now()
    // 顺序:Anthropic Haiku 主力(3-4s 稳定、质量最好)→ OpenAI → Gemini 免费层兜底
    // (Gemini 免费层 2026-07 实测延迟方差大:2.0-flash 配额归零、2.5 系 thinking 拖慢)
    const result =
      (await tryAnthropic(prompt, config)) ??
      (await tryOpenAI(prompt, config)) ??
      (await tryGemini(prompt, config))

    if (!result) {
      return new Response(
        JSON.stringify({ error: 'All LLM providers failed', message: 'Gemini/Anthropic/OpenAI all unavailable' }),
        { status: 502, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
      )
    }

    console.log(`[llm-proxy] provider=${result.provider} category=${category ?? '-'} latency=${Date.now() - started}ms`)

    return new Response(
      JSON.stringify({ text: result.text, category: category, provider: result.provider }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'LLM proxy error', message: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } },
    )
  }
})
