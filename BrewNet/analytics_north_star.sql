-- BrewNet 北极星 & Match v4 分析查询(Supabase SQL Editor 直接跑)
-- 数据源:match_decisions(每次精选)⟕ invitations/proposals/worthit(结果)= match_outcomes 视图

-- 1️⃣ 北极星:worth-it 率(见面后 👍 占比)
SELECT count(*) FILTER (WHERE worth_it) AS thumbs_up,
       count(*) AS total_votes,
       round(100.0 * count(*) FILTER (WHERE worth_it) / nullif(count(*), 0), 1) AS worthit_rate_pct
FROM brew_worthit_votes;

-- 2️⃣ 漏斗:展示 → 邀请 → 接受(按周)
SELECT date_trunc('week', shown_at)::date AS week,
       count(*) AS shown,
       count(invited_at) AS invited,
       count(*) FILTER (WHERE invitation_status = 'accepted' OR proposal_status = 'accepted') AS accepted,
       round(100.0 * count(invited_at) / nullif(count(*), 0), 1) AS shown_to_invite_pct,
       round(100.0 * count(*) FILTER (WHERE invitation_status = 'accepted' OR proposal_status = 'accepted')
             / nullif(count(invited_at), 0), 1) AS invite_to_accept_pct
FROM match_outcomes
GROUP BY 1 ORDER BY 1 DESC;

-- 3️⃣ LLM 精排 vs 规则排序的结果对比(GEPA 前的基线)
SELECT llm_applied,
       count(*) AS shown,
       round(100.0 * count(invited_at) / nullif(count(*), 0), 1) AS invite_rate_pct,
       round(avg(fit_score), 1) AS avg_reciprocal_score
FROM match_outcomes
GROUP BY 1;

-- 4️⃣ 曝光分布(公平监控:Gini 前哨)
SELECT candidate_id, count(*) AS times_shown
FROM match_decisions
WHERE created_at > now() - interval '14 days'
GROUP BY 1 ORDER BY 2 DESC LIMIT 20;

-- 5️⃣ GEPA 训练数据就绪度(目标:≥100 条有结果的决策)
SELECT count(*) AS decisions_with_outcome
FROM match_outcomes
WHERE invitation_status IS NOT NULL OR proposal_status IS NOT NULL OR worth_it IS NOT NULL;
