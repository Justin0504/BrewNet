// Supabase Edge Function: Push Cron(Stage 3,2026-08)
// 由 pg_cron 每 10 分钟触发。扫描四类事件 → 调 apns-push 发推:
//   1. 🤝 新的双盲提案(target 未通知)
//   2. 🎉 提案被接受(proposer 未通知)
//   3. ☕ 24h 内的已定咖啡(双方未简报提醒)
//   4. 🗓 每周一杯唤醒(有 token 且 >7 天没推过)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!

async function sendPush(userId: string, title: string, body: string, data: Record<string, unknown> = {}) {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/apns-push`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${ANON}` },
    body: JSON.stringify({ user_id: userId, title, body, data }),
  })
  const out = await res.json().catch(() => ({}))
  console.log(`[cron→push] ${userId.slice(0, 8)} "${title}" → ${JSON.stringify(out)}`)
  return out
}

serve(async (req) => {
  if (!req.headers.get("authorization")) {
    return new Response("unauthorized", { status: 401 })
  }
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE)
  const now = new Date().toISOString()
  const report: Record<string, number> = { proposals: 0, accepts: 0, preps: 0, weekly: 0 }

  try {
    // 1) 新双盲提案 → 通知 target
    const { data: newProposals } = await admin.from("brew_proposals")
      .select("id,target_id,window_text,venue")
      .eq("status", "pending").is("target_notified_at", null).limit(20)
    for (const p of newProposals ?? []) {
      const plan = [p.window_text, p.venue].filter(Boolean).join(" at ")
      await sendPush(p.target_id, "🤝 Your Brew has a proposal",
        `Someone's agent thinks you two should grab coffee${plan ? ` — ${plan}` : ""}. They won't see a no.`,
        { type: "proposal", id: p.id })
      await admin.from("brew_proposals").update({ target_notified_at: now }).eq("id", p.id)
      report.proposals++
    }

    // 2) 提案被接受 → 通知 proposer
    const { data: accepted } = await admin.from("brew_proposals")
      .select("id,proposer_id,window_text,venue")
      .eq("status", "accepted").is("accepted_notified_at", null).limit(20)
    for (const p of accepted ?? []) {
      const plan = [p.window_text, p.venue].filter(Boolean).join(" at ")
      await sendPush(p.proposer_id, "☕️ It's on!",
        `They said yes${plan ? ` — ${plan}` : ""}. Open Brew for your prep brief.`,
        { type: "accepted", id: p.id })
      await admin.from("brew_proposals").update({ accepted_notified_at: now }).eq("id", p.id)
      report.accepts++
    }

    // 3) 24h 内的咖啡 → 双方简报提醒
    const dayAhead = new Date(Date.now() + 24 * 3600 * 1000).toISOString()
    const { data: upcoming } = await admin.from("coffee_chat_invitations")
      .select("id,sender_id,receiver_id,sender_name,receiver_name,scheduled_date,location")
      .eq("status", "accepted").is("prep_notified_at", null)
      .gte("scheduled_date", now).lte("scheduled_date", dayAhead).limit(20)
    for (const c of upcoming ?? []) {
      const when = c.scheduled_date ? new Date(c.scheduled_date).toLocaleString("en-US", { weekday: "long", hour: "numeric" }) : "soon"
      await sendPush(c.sender_id, "☕ Coffee coming up",
        `You're meeting ${c.receiver_name ?? "your match"} ${when}${c.location ? ` at ${c.location}` : ""}. Tap for your prep brief.`,
        { type: "prep", id: c.id })
      await sendPush(c.receiver_id, "☕ Coffee coming up",
        `You're meeting ${c.sender_name ?? "your match"} ${when}${c.location ? ` at ${c.location}` : ""}. Tap for your prep brief.`,
        { type: "prep", id: c.id })
      await admin.from("coffee_chat_invitations").update({ prep_notified_at: now }).eq("id", c.id)
      report.preps++
    }

    // 4) 每周一杯唤醒(有 token,>7 天没推)
    const { data: tokenUsers } = await admin.from("device_tokens").select("user_id")
    const uniqueUsers = [...new Set((tokenUsers ?? []).map((t) => t.user_id))]
    for (const uid of uniqueUsers) {
      const { data: state } = await admin.from("brew_push_state")
        .select("last_weekly_push_at").eq("user_id", uid).maybeSingle()
      const last = state?.last_weekly_push_at ? new Date(state.last_weekly_push_at).getTime() : 0
      if (Date.now() - last > 7 * 24 * 3600 * 1000) {
        await sendPush(uid, "☕ Your Weekly Brew is ready",
          "I picked ONE person worth your coffee this week. Come see who.",
          { type: "weekly" })
        await admin.from("brew_push_state").upsert({ user_id: uid, last_weekly_push_at: now })
        report.weekly++
      }
    }

    console.log(`[push-cron] ${JSON.stringify(report)}`)
    return new Response(JSON.stringify(report), { headers: { "Content-Type": "application/json" } })
  } catch (e) {
    console.error("[push-cron] error", e)
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
