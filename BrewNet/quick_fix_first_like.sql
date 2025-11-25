-- ============================================
-- 快速修复 first_like_today 问题
-- ============================================
-- 按顺序运行以下命令

-- 1️⃣ 添加字段（如果不存在）
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS first_like_today DATE;

-- 2️⃣ 创建索引
CREATE INDEX IF NOT EXISTS idx_users_first_like_today 
ON users(first_like_today);

-- 3️⃣ 检查字段是否创建成功
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'first_like_today';
-- 预期: 返回 first_like_today | date | YES

-- 4️⃣ 检查现有的 UPDATE 策略
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'users'
AND cmd IN ('UPDATE', 'ALL');
-- 预期: 至少有一个策略允许 UPDATE

-- 5️⃣ 如果没有 UPDATE 策略，创建一个（根据实际情况调整）
-- 取消下面的注释来创建策略：
/*
CREATE POLICY IF NOT EXISTS "Users can update own data"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
*/

-- 6️⃣ 测试手动更新（替换 YOUR_USER_ID）
/*
UPDATE users 
SET first_like_today = CURRENT_DATE 
WHERE id = 'YOUR_USER_ID';

SELECT id, name, email, first_like_today 
FROM users 
WHERE id = 'YOUR_USER_ID';
*/

-- 7️⃣ 查看最近更新的记录
SELECT id, name, first_like_today, updated_at
FROM users 
WHERE first_like_today IS NOT NULL
ORDER BY updated_at DESC
LIMIT 10;

-- ✅ 如果以上都正常，问题已修复
-- ❌ 如果仍然失败，检查 Xcode 日志中的 [First Like] 错误信息

