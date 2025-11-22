-- ============================================
-- 为 meeting_ratings 表添加 comment 字段
-- ============================================

-- 如果表已存在，添加 comment 字段
ALTER TABLE meeting_ratings
ADD COLUMN IF NOT EXISTS comment TEXT;

-- 添加注释
COMMENT ON COLUMN meeting_ratings.comment IS '用户评分时的评论内容（可选）';

-- 验证字段已添加
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'meeting_ratings'
  AND column_name = 'comment';

