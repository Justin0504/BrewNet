-- =====================================================
-- BrewNet Supabase Storage 配置
-- 用于用户头像上传和管理
-- =====================================================

-- =====================================================
-- 1. 创建 avatars 存储桶
-- =====================================================

-- 注意：Supabase Storage 需要使用 REST API 或 Dashboard UI 创建
-- 此 SQL 脚本提供配置指导和验证

-- 存储桶配置说明：
-- 名称: avatars
-- 类型: public (允许公共访问)
-- 文件大小限制: 5MB (推荐)
-- 允许的文件类型: .jpg, .jpeg, .png, .webp, .gif

-- =====================================================
-- 2. 配置存储桶策略 (RLS Policies)
-- =====================================================

-- 注意：这些策略需要在 Supabase Dashboard 的 Storage > Policies 中手动创建

-- 策略 1: 允许用户上传自己的头像
-- INSERT INTO storage.policies (name, bucket_id, definition, check_definition)
-- VALUES (
--     'Users can upload their own avatars',
--     'avatars',
--     '(bucket_id = ''avatars''::text) AND (auth.uid()::text = (storage.foldername(name))[1])',
--     '(bucket_id = ''avatars''::text) AND (auth.uid()::text = (storage.foldername(name))[1])'
-- );

-- 策略 2: 允许用户更新自己的头像
-- INSERT INTO storage.policies (name, bucket_id, definition, check_definition)
-- VALUES (
--     'Users can update their own avatars',
--     'avatars',
--     '(bucket_id = ''avatars''::text) AND (auth.uid()::text = (storage.foldername(name))[1])',
--     '(bucket_id = ''avatars''::text) AND (auth.uid()::text = (storage.foldername(name))[1])'
-- );

-- 策略 3: 允许用户删除自己的头像
-- INSERT INTO storage.policies (name, bucket_id, definition, check_definition)
-- VALUES (
--     'Users can delete their own avatars',
--     'avatars',
--     '(bucket_id = ''avatars''::text) AND (auth.uid()::text = (storage.foldername(name))[1])',
--     '(bucket_id = ''avatars''::text) AND (auth.uid()::text = (storage.foldername(name))[1])'
-- );

-- 策略 4: 允许所有人查看头像（公共访问）
-- INSERT INTO storage.policies (name, bucket_id, definition, check_definition)
-- VALUES (
--     'Anyone can view avatars',
--     'avatars',
--     '(bucket_id = ''avatars''::text)',
--     '(bucket_id = ''avatars''::text)'
-- );

-- =====================================================
-- 3. 验证 Storage 配置
-- =====================================================

-- 检查存储桶是否存在
DO $$
DECLARE
    v_bucket_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM storage.buckets 
        WHERE name = 'avatars'
    ) INTO v_bucket_exists;
    
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Storage Bucket 检查结果';
    RAISE NOTICE '=====================================================';
    
    IF v_bucket_exists THEN
        RAISE NOTICE '✅ avatars 存储桶已存在';
    ELSE
        RAISE NOTICE '❌ avatars 存储桶不存在';
        RAISE NOTICE '';
        RAISE NOTICE '请在 Supabase Dashboard 中创建存储桶：';
        RAISE NOTICE '1. 打开 Storage > Buckets';
        RAISE NOTICE '2. 点击 "New bucket"';
        RAISE NOTICE '3. 名称: avatars';
        RAISE NOTICE '4. 类型: Public (允许公共访问)';
        RAISE NOTICE '5. 点击 "Create bucket"';
    END IF;
    
    RAISE NOTICE '=====================================================';
END $$;

-- 检查存储桶策略
DO $$
BEGIN
    RAISE NOTICE 'Storage 策略检查：';
    RAISE NOTICE '';
    RAISE NOTICE 'Supabase Storage 策略需要通过 Dashboard UI 配置';
    RAISE NOTICE '';
    RAISE NOTICE '请按以下步骤在 Supabase Dashboard 中配置：';
    RAISE NOTICE '1. 打开 Storage > Policies';
    RAISE NOTICE '2. 选择 avatars 存储桶';
    RAISE NOTICE '3. 创建以下策略：';
    RAISE NOTICE '   - Users can upload their own avatars (INSERT)';
    RAISE NOTICE '   - Users can update their own avatars (UPDATE)';
    RAISE NOTICE '   - Users can delete their own avatars (DELETE)';
    RAISE NOTICE '   - Anyone can view avatars (SELECT)';
END $$;

-- =====================================================
-- 4. 存储桶配置说明
-- =====================================================

/*
STORAGE SETUP INSTRUCTIONS:

1. 创建存储桶 (avatars)
   - 登录 Supabase Dashboard
   - 进入 Storage > Buckets
   - 点击 "New bucket"
   - 设置:
     * Name: avatars
     * Public bucket: ✅ Enabled
   - 点击 "Create bucket"

2. 配置存储策略 (手动在 Dashboard 配置)
   
   策略 1: 上传头像
   - Name: "Users can upload their own avatars"
   - Target roles: All
   - SELECT policy:
     * Operation: INSERT
     * Policy definition: 
       auth.uid()::text = (storage.foldername(name))[1]
   
   策略 2: 更新头像
   - Name: "Users can update their own avatars"
   - Target roles: All
   - SELECT policy:
     * Operation: UPDATE
     * Policy definition: 
       auth.uid()::text = (storage.foldername(name))[1]
   
   策略 3: 删除头像
   - Name: "Users can delete their own avatars"
   - Target roles: All
   - SELECT policy:
     * Operation: DELETE
     * Policy definition: 
       auth.uid()::text = (storage.foldername(name))[1]
   
   策略 4: 查看头像（公共）
   - Name: "Anyone can view avatars"
   - Target roles: All
   - SELECT policy:
     * Operation: SELECT
     * Policy definition: 
       true

3. 文件路径结构
   - 路径格式: {user_id}/avatar.{ext}
   - 示例: dbb4d116-84f0-4ba5-82f5-161f27976bb8/avatar.jpg

4. 获取公共 URL
   - 格式: https://jcxvdolcdifdghaibspy.supabase.co/storage/v1/object/public/avatars/{user_id}/avatar.{ext}
   - 示例: https://jcxvdolcdifdghaibspy.supabase.co/storage/v1/object/public/avatars/dbb4d116-84f0-4ba5-82f5-161f27976bb8/avatar.jpg

5. 文件类型限制
   - 允许: .jpg, .jpeg, .png, .webp, .gif
   - 最大大小: 5MB
   - 推荐尺寸: 400x400 像素

*/

-- =====================================================
-- 完成
-- =====================================================

SELECT 
    'Storage 配置脚本执行完成！' AS status,
    '请在 Supabase Dashboard 中手动创建存储桶和策略' AS next_step;

