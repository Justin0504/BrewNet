-- Brew Agent: worth-it votes(北极星指标云端落库)
-- 轻量表:不绑 meeting/GPS 流程,记录"这次认识值不值"的一键回访。
-- 在 Supabase SQL Editor 运行;客户端在表不存在时自动降级为仅本地日志。

CREATE TABLE IF NOT EXISTS brew_worthit_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,          -- 回访者(app 内 user id)
    subject_user_id TEXT,           -- 被评价的对象 user id
    subject_name TEXT NOT NULL,
    worth_it BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_worthit_user ON brew_worthit_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_worthit_created ON brew_worthit_votes(created_at);

ALTER TABLE brew_worthit_votes ENABLE ROW LEVEL SECURITY;

-- 注:app 存在自定义登录路径(无 Supabase Auth 会话),与库内其它表保持一致:
-- 允许 anon 插入(只写不读);读取仅 service role(分析用)
CREATE POLICY "Anyone can insert worthit votes" ON brew_worthit_votes
    FOR INSERT WITH CHECK (true);
