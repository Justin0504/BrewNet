-- Add has_met column to coffee_chat_schedules table
-- 在 Supabase Dashboard 的 SQL Editor 中执行此脚本

ALTER TABLE coffee_chat_schedules
ADD COLUMN IF NOT EXISTS has_met BOOLEAN DEFAULT FALSE;

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_coffee_chat_schedules_has_met 
    ON coffee_chat_schedules(has_met) 
    WHERE has_met = true;

-- 添加注释
COMMENT ON COLUMN coffee_chat_schedules.has_met IS '标记用户是否已见面';

