// Supabase Edge Function: intro
// 开放图谱 warm intro 的公开落地页 —— 非用户无需下载即可接受/婉拒。
//
//   GET  /functions/v1/intro?token=xxx           → 品牌化 HTML 落地页
//   POST /functions/v1/intro   {token, action}   → accept / decline,回流通知发起人
//
// 落地页对未登录公众开放(verify_jwt=false),所有 DB 操作走 service role,
// 绕过 external_intros 的 RLS(RLS 只保护 App 内 inviter 自己的读写)。
//
// Deploy: supabase functions deploy intro --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const APNS_FN = `${SUPABASE_URL}/functions/v1/apns-push`

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
})

const BROWN = "#5c3317"
const CREAM = "#faf7f2"
const TEAL = "#128070"

function esc(s: string): string {
  return (s || "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!))
}

function page(body: string, title = "BrewNet", ogDesc = "A warm coffee intro, set up by Brew — your AI networking agent."): Response {
  const html = `<!DOCTYPE html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title>
<meta property="og:type" content="website">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(ogDesc)}">
<meta property="og:site_name" content="BrewNet">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(ogDesc)}">
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
    background:${CREAM};color:#2a1c12;line-height:1.5;
    min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}
  .card{background:#fff;border-radius:22px;max-width:440px;width:100%;
    box-shadow:0 12px 40px rgba(92,51,23,.10);overflow:hidden}
  .hd{background:${BROWN};color:#fff;padding:26px 26px 22px;text-align:center}
  .logo{font-size:13px;letter-spacing:2px;font-weight:800;opacity:.85;text-transform:uppercase}
  .hd h1{font-size:22px;margin-top:10px;font-weight:800}
  .bd{padding:26px}
  .row{display:flex;align-items:center;gap:12px;margin-bottom:18px}
  .avatar{width:52px;height:52px;border-radius:14px;background:${BROWN};color:#fff;
    display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:800;flex-shrink:0}
  .who .name{font-size:18px;font-weight:800}
  .who .sub{font-size:13px;color:#8a7560}
  .msg{background:${CREAM};border-radius:16px;padding:16px 18px;font-size:15px;
    color:#3a2a1c;margin-bottom:18px;white-space:pre-wrap}
  .meta{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:22px}
  .chip{background:#fff;border:1px solid #ece3d8;border-radius:999px;padding:7px 13px;
    font-size:13px;color:${BROWN};font-weight:600}
  .btn{display:block;width:100%;border:0;border-radius:14px;padding:15px;font-size:16px;
    font-weight:700;cursor:pointer;text-align:center;text-decoration:none}
  .accept{background:${TEAL};color:#fff;margin-bottom:10px}
  .decline{background:transparent;color:#8a7560}
  .note{width:100%;border:1px solid #ece3d8;border-radius:12px;padding:12px;font-size:14px;
    font-family:inherit;margin-bottom:12px;resize:vertical;min-height:44px}
  .foot{text-align:center;font-size:12px;color:#a89680;padding:18px}
  .foot a{color:${BROWN};font-weight:700;text-decoration:none}
</style></head><body><div class="card">${body}</div></body></html>`
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } })
}

function notFound(): Response {
  return page(`<div class="hd"><div class="logo">BrewNet</div><h1>Invite not found</h1></div>
    <div class="bd"><p class="msg">This coffee invite link is invalid or has expired.</p></div>`, "BrewNet")
}

async function notifyInviter(intro: any, accepted: boolean) {
  try {
    const first = (intro.target_name || "They").split(" ")[0]
    const title = accepted ? "☕️ Coffee's on!" : "Intro update"
    const body = accepted
      ? `${first} accepted your coffee invite. Time to lock it in.`
      : `${first} passed on the intro this time.`
    // apns-push 自己按 user_id 查 device_tokens 并投递
    await fetch(APNS_FN, {
      method: "POST",
      headers: { "content-type": "application/json", "authorization": `Bearer ${SERVICE_ROLE}` },
      body: JSON.stringify({ user_id: intro.inviter_id, title, body }),
    }).catch(() => {})
  } catch (_) { /* 通知失败不影响接受流程 */ }
}

serve(async (req) => {
  const url = new URL(req.url)

  // ---- POST: accept / decline ----
  if (req.method === "POST") {
    let payload: any = {}
    try { payload = await req.json() } catch (_) {}
    const token = payload.token
    const action = payload.action
    if (!token || !["accept", "decline"].includes(action)) {
      return new Response(JSON.stringify({ error: "bad request" }), { status: 400 })
    }
    const { data: intro } = await admin
      .from("external_intros").select("*").eq("token", token).maybeSingle()
    if (!intro) return new Response(JSON.stringify({ error: "not found" }), { status: 404 })

    // 只有首次终态才回流通知(幂等,防重复点击刷推送)
    const firstResponse = intro.status !== "accepted" && intro.status !== "declined"
    await admin.from("external_intros").update({
      status: action === "accept" ? "accepted" : "declined",
      responded_at: new Date().toISOString(),
      target_reply_email: payload.email || intro.target_reply_email,
      target_reply_note: payload.note || intro.target_reply_note,
    }).eq("token", token)

    if (firstResponse) await notifyInviter(intro, action === "accept")
    return new Response(JSON.stringify({ ok: true }), {
      headers: { "content-type": "application/json" },
    })
  }

  // ---- GET: 落地页 ----
  const token = url.searchParams.get("token")
  if (!token) return notFound()

  const { data: intro } = await admin
    .from("external_intros").select("*").eq("token", token).maybeSingle()
  if (!intro) return notFound()

  // 首次浏览标记 viewed
  if (intro.status === "created") {
    await admin.from("external_intros")
      .update({ status: "viewed", viewed_at: new Date().toISOString() }).eq("token", token)
  }

  const firstName = (intro.target_name || "there").split(" ")[0]
  const initial = (intro.inviter_name || "B").trim().charAt(0).toUpperCase()

  // 已回应 → 确认态
  if (intro.status === "accepted" || intro.status === "declined") {
    const accepted = intro.status === "accepted"
    return page(`
      <div class="hd"><div class="logo">BrewNet · Warm Intro</div>
        <h1>${accepted ? "You're all set ☕️" : "No worries"}</h1></div>
      <div class="bd">
        <p class="msg">${accepted
          ? `${esc(intro.inviter_name)} has been let know. They'll reach out to lock in the details.`
          : `We've let ${esc(intro.inviter_name)} know. Maybe another time.`}</p>
        <a class="btn accept" href="https://apps.apple.com/app/id6796967801">Get your own Brew agent →</a>
      </div>
      <div class="foot">Brew is your AI networking agent. It sets up coffees worth having.</div>`,
      "BrewNet")
  }

  const chips = [
    intro.window_text ? `<span class="chip">🗓 ${esc(intro.window_text)}</span>` : "",
    intro.venue ? `<span class="chip">📍 ${esc(intro.venue)}</span>` : "",
  ].join("")

  return page(`
    <div class="hd"><div class="logo">BrewNet · Warm Intro</div>
      <h1>${esc(firstName)}, someone wants to grab coffee</h1></div>
    <div class="bd">
      <div class="row">
        <div class="avatar">${esc(initial)}</div>
        <div class="who">
          <div class="name">${esc(intro.inviter_name)}</div>
          ${intro.inviter_headline ? `<div class="sub">${esc(intro.inviter_headline)}</div>` : ""}
        </div>
      </div>
      <div class="msg">${esc(intro.message)}</div>
      ${chips ? `<div class="meta">${chips}</div>` : ""}
      <form id="f">
        <textarea class="note" name="note" placeholder="Add a quick note (optional)"></textarea>
        <button class="btn accept" type="button" onclick="respond('accept')">Yes, I'm in ☕️</button>
        <button class="btn decline" type="button" onclick="respond('decline')">Not right now</button>
      </form>
    </div>
    <div class="foot">Set up by <a href="https://apps.apple.com/app/id6796967801">Brew</a>, ${esc(intro.inviter_name.split(" ")[0])}'s AI networking agent.</div>
    <script>
      async function respond(action){
        var note=document.querySelector('[name=note]').value;
        document.querySelectorAll('.btn').forEach(function(b){b.disabled=true;b.style.opacity=.5});
        try{
          await fetch(window.location.pathname+window.location.search,{method:'POST',
            headers:{'content-type':'application/json'},
            body:JSON.stringify({token:${JSON.stringify(token)},action:action,note:note})});
        }catch(e){}
        window.location.reload();
      }
    </script>`,
    `${intro.inviter_name} wants to grab coffee · BrewNet`,
    `${intro.inviter_name}${intro.inviter_headline ? " (" + intro.inviter_headline + ")" : ""} would love to grab a coffee with you. Tap to say yes — no download needed.`)
})
