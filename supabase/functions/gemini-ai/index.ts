// Supabase Edge Function: Gemini AI Proxy
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { GoogleGenerativeAI } from "npm:@google/generative-ai@^0.1.0"

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'API Key not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    const authHeader = req.headers.get('authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    const body: RequestBody = await req.json()
    const { prompt, category, generationConfig } = body

    if (!prompt) {
      return new Response(
        JSON.stringify({ error: 'Missing prompt' }),
        { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY)
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' })

    const config = {
      temperature: generationConfig?.temperature ?? 0.7,
      topK: generationConfig?.topK ?? 40,
      topP: generationConfig?.topP ?? 0.95,
      maxOutputTokens: generationConfig?.maxOutputTokens ?? 1024,
    }

    // 添加重试逻辑处理 429 错误
    let result
    let retries = 3
    let lastError
    
    while (retries > 0) {
      try {
        result = await model.generateContent({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: config,
        })
        break // 成功，退出循环
      } catch (error: any) {
        lastError = error
        // 如果是 429 错误（配额限制），等待后重试
        if (error.message?.includes('429') || error.message?.includes('Resource exhausted')) {
          retries--
          if (retries > 0) {
            // 等待 2 秒后重试（指数退避）
            const waitTime = (4 - retries) * 2000 // 2秒, 4秒, 6秒
            await new Promise(resolve => setTimeout(resolve, waitTime))
            continue
          }
        }
        // 其他错误直接抛出
        throw error
      }
    }
    
    if (!result) {
      throw lastError || new Error('Failed to generate content after retries')
    }

    const response = await result.response
    const text = response.text()

    return new Response(
      JSON.stringify({ text: text, category: category }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Failed to call Gemini API', message: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})
