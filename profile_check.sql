-- BrewNet Profile 数据库完整性检查 - 一行结果输出
SELECT CASE 
    WHEN (
        -- 检查 users 表存在
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') AND
        -- 检查 profiles 表存在
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') AND
        -- 检查 users 表关键字段
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'id') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'email') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'name') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'profile_setup_completed') AND
        -- 检查 profiles 表关键字段
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'id') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'user_id') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'core_identity') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'professional_background') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'networking_intention') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'networking_preferences') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'personality_social') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'privacy_trust') AND
        -- 检查 JSONB 数据类型
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'core_identity' AND data_type = 'jsonb') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'professional_background' AND data_type = 'jsonb') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'networking_intention' AND data_type = 'jsonb') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'networking_preferences' AND data_type = 'jsonb') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'personality_social' AND data_type = 'jsonb') AND
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'privacy_trust' AND data_type = 'jsonb') AND
        -- 检查外键约束
        EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'profiles' AND constraint_type = 'FOREIGN KEY') AND
        -- 检查 RLS 策略
        EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles')
    ) THEN '✅ BrewNet Profile 数据库检查通过 - 所有字段和配置正确'
    ELSE '❌ BrewNet Profile 数据库检查失败 - 缺少必要字段或配置'
END as check_result;
