// Supabase Edge Function: APNs Push(2026-08)
// 直调 Apple Push Notification service(HTTP/2 + ES256 JWT)。
// 入参: { user_id, title, body, data? } → 查 device_tokens → 逐个推送。
// Secrets: APNS_KEY_ID / APNS_TEAM_ID / APNS_TOPIC / APNS_P8
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!
const APNS_TOPIC = Deno.env.get("APNS_TOPIC")!
const APNS_P8 = Deno.env.get("APNS_P8")!
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

// —— ES256 JWT(缓存 ~50 分钟,APNs 允许 20-60 分钟) ——
let cachedJWT: { token: string; issuedAt: number } | null = null

async function importP8Key(pem: string): Promise<CryptoKey> {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  return await crypto.subtle.importKey(
    "pkcs8", der,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"],
  )
}

function b64url(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

async function apnsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedJWT && now - cachedJWT.issuedAt < 3000) return cachedJWT.token
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID })))
  const payload = b64url(new TextEncoder().encode(JSON.stringify({ iss: APNS_TEAM_ID, iat: now })))
  const signingInput = `${header}.${payload}`
  const key = await importP8Key(APNS_P8)
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(signingInput),
  )
  const token = `${signingInput}.${b64url(new Uint8Array(sig))}`
  cachedJWT = { token, issuedAt: now }
  return token
}

async function pushToToken(deviceToken: string, title: string, body: string, data: Record<string, unknown>): Promise<{ ok: boolean; status: number; reason?: string }> {
  const jwt = await apnsJWT()
  const payload = {
    aps: { alert: { title, body }, sound: "default", badge: 1 },
    ...data,
  }
  const res = await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  })
  if (res.ok) return { ok: true, status: res.status }
  const errBody = await res.text()
  let reason: string | undefined
  try { reason = JSON.parse(errBody).reason } catch { reason = errBody.slice(0, 80) }
  return { ok: false, status: res.status, reason }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    })
  }
  try {
    if (!req.headers.get("authorization")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 })
    }
    const { user_id, title, body, data } = await req.json()
    if (!user_id || !title) {
      return new Response(JSON.stringify({ error: "user_id and title required" }), { status: 400 })
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE)
    const { data: tokens, error } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id.toLowerCase())
    if (error) throw error
    if (!tokens?.length) {
      return new Response(JSON.stringify({ sent: 0, reason: "no tokens for user" }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      })
    }

    const results = []
    for (const row of tokens) {
      const r = await pushToToken(row.token, title, body ?? "", data ?? {})
      results.push(r)
      // 失效 token 清理(410 Unregistered / 400 BadDeviceToken)
      if (!r.ok && (r.status === 410 || r.reason === "BadDeviceToken")) {
        await admin.from("device_tokens").delete().eq("token", row.token)
      }
    }
    const sent = results.filter((r) => r.ok).length
    console.log(`[apns] user=${user_id} sent=${sent}/${results.length} ${JSON.stringify(results)}`)
    return new Response(JSON.stringify({ sent, results }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    })
  } catch (e) {
    console.error("[apns] error", e)
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "unknown" }), { status: 500 })
  }
})
