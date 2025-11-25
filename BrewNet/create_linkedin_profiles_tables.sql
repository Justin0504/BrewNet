-- 创建 LinkedIn 数据导入相关表
-- 执行顺序：先执行这个文件创建表结构

-- linkedin_profiles 表：存储 LinkedIn 抓取的数据 + 状态 + consent 日志
CREATE TABLE IF NOT EXISTS linkedin_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  linkedin_id text UNIQUE,                -- LinkedIn member id (sub)
  vanity_name text,                       -- slug from linkedin URL
  headline text,
  raw_profile jsonb,                      -- raw JSON from /me
  email text,
  avatar_url text,
  import_status text DEFAULT 'pending',   -- pending / confirmed / failed / deleted
  consent_log jsonb,                      -- e.g. {consent_ts, ip, ua}
  last_fetched_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- linkedin_import_audit 表：可选的审计日志，记录导入操作历史
CREATE TABLE IF NOT EXISTS linkedin_import_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  linkedin_profile_id uuid,
  action text,            -- requested, fetched, user_confirmed, deleted
  detail jsonb,
  created_at timestamptz DEFAULT now()
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_user_id ON linkedin_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_linkedin_id ON linkedin_profiles(linkedin_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_import_status ON linkedin_profiles(import_status);
CREATE INDEX IF NOT EXISTS idx_linkedin_profiles_last_fetched_at ON linkedin_profiles(last_fetched_at);

CREATE INDEX IF NOT EXISTS idx_linkedin_import_audit_user_id ON linkedin_import_audit(user_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_import_audit_action ON linkedin_import_audit(action);

-- RLS 策略：用户只能访问自己的 LinkedIn 资料
ALTER TABLE linkedin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE linkedin_import_audit ENABLE ROW LEVEL SECURITY;

-- LinkedIn profiles 策略
CREATE POLICY "Users can view their own linkedin profiles" ON linkedin_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own linkedin profiles" ON linkedin_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own linkedin profiles" ON linkedin_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- LinkedIn import audit 策略
CREATE POLICY "Users can view their own import audit" ON linkedin_import_audit
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert import audit" ON linkedin_import_audit
  FOR INSERT WITH CHECK (true); -- 允许系统插入审计日志

-- 添加注释
COMMENT ON TABLE linkedin_profiles IS '存储用户从 LinkedIn 导入的个人资料数据';
COMMENT ON COLUMN linkedin_profiles.linkedin_id IS 'LinkedIn 用户的唯一标识符';
COMMENT ON COLUMN linkedin_profiles.vanity_name IS 'LinkedIn 个人资料页面的自定义 URL 后缀';
COMMENT ON COLUMN linkedin_profiles.headline IS 'LinkedIn 个人简介/职位描述';
COMMENT ON COLUMN linkedin_profiles.raw_profile IS '从 LinkedIn API 获取的原始 JSON 数据';
COMMENT ON COLUMN linkedin_profiles.import_status IS '导入状态：pending(待确认)/confirmed(已确认)/failed(失败)/deleted(已删除)';
COMMENT ON COLUMN linkedin_profiles.consent_log IS '用户同意导入时的元数据，包括时间戳、IP、User-Agent等';

COMMENT ON TABLE linkedin_import_audit IS 'LinkedIn 数据导入的审计日志';
COMMENT ON COLUMN linkedin_import_audit.action IS '操作类型：requested(请求导入)/fetched(已抓取)/user_confirmed(用户确认)/deleted(已删除)';
COMMENT ON COLUMN linkedin_import_audit.detail IS '操作详情的 JSON 数据';
