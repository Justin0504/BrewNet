-- ============================================================
-- 修复 matches 表缺少 updated_at 列的脚本
-- ============================================================

-- 如果 matches 表已存在但没有 updated_at 列，添加它
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'matches' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE matches 
        ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        
        -- 更新现有记录的 updated_at 为 created_at（如果没有的话）
        UPDATE matches 
        SET updated_at = COALESCE(created_at, NOW()) 
        WHERE updated_at IS NULL;
        
        RAISE NOTICE '✅ Added updated_at column to matches table';
    ELSE
        RAISE NOTICE 'ℹ️ updated_at column already exists in matches table';
    END IF;
END $$;

-- 确保触发器存在（如果 updated_at 列刚被添加）
DROP TRIGGER IF EXISTS update_matches_updated_at ON matches;
CREATE TRIGGER update_matches_updated_at
    BEFORE UPDATE ON matches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

SELECT '✅ matches table updated_at column fix completed!' as result;

