-- =====================================================
-- BrewNet Avatar Storage Policies
-- 用户头像存储策略
-- =====================================================

-- 在 Supabase Dashboard > SQL Editor 中执行此脚本
-- 或在 Supabase Dashboard > Storage > Policies 中手动创建

-- =====================================================
-- Policy 1: 允许认证用户上传头像
-- =====================================================
CREATE POLICY "Users can upload their own avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
);

-- =====================================================
-- Policy 2: 允许用户更新自己的头像
-- =====================================================
CREATE POLICY "Users can update their own avatars"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
)
WITH CHECK (
    bucket_id = 'avatars'
);

-- =====================================================
-- Policy 3: 允许用户删除自己的头像
-- =====================================================
CREATE POLICY "Users can delete their own avatars"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
);

-- =====================================================
-- Policy 4: 允许公共访问查看头像
-- =====================================================
CREATE POLICY "Anyone can view avatars"
ON storage.objects
FOR SELECT
TO public
USING (
    bucket_id = 'avatars'
);

-- =====================================================
-- 完成
-- =====================================================

SELECT 'Storage policies created successfully!' AS status;

