# Highlights 图片存储配置指南

## 概述
Highlights 功能的图片会保存到 Supabase Storage。目前使用现有的 `avatars` bucket 来存储图片。

## Storage Bucket 配置

### 方案 1：使用现有的 `avatars` bucket（推荐）
当前代码已经配置为使用 `avatars` bucket，图片会保存在 `{userId}/moments/` 目录下。

**优点：**
- 无需额外配置
- 可以立即使用

**存储路径格式：**
```
avatars/{userId}/moments/moment_{userId}_{uuid}.jpg
```

### 方案 2：创建专用的 `highlights` bucket（可选）
如果你希望将 highlights 图片与头像分开管理，可以创建一个新的 bucket。

## 配置步骤

### 1. 检查 `avatars` bucket 是否存在

1. 登录 Supabase Dashboard
2. 进入 **Storage** 页面
3. 检查是否存在 `avatars` bucket

### 2. 如果 `avatars` bucket 不存在，创建它

1. 在 Storage 页面点击 **"New bucket"**
2. 输入 bucket 名称：`avatars`
3. 设置为 **Public bucket**（这样图片可以通过公共 URL 访问）
4. 点击 **"Create bucket"**

### 3. 配置 Bucket 权限（RLS Policies）

在 Supabase Dashboard 的 **Storage** > **Policies** 中，为 `avatars` bucket 添加以下策略：

#### 上传权限（INSERT）
```sql
-- 允许用户上传自己的图片
CREATE POLICY "Users can upload their own moment images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
```

#### 读取权限（SELECT）
```sql
-- 允许所有人读取公共图片
CREATE POLICY "Public can view moment images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');
```

#### 更新权限（UPDATE）
```sql
-- 允许用户更新自己的图片
CREATE POLICY "Users can update their own moment images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
```

#### 删除权限（DELETE）
```sql
-- 允许用户删除自己的图片
CREATE POLICY "Users can delete their own moment images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);
```

### 4. 验证配置

上传一张图片后，检查：
1. Storage 中是否出现了 `{userId}/moments/` 目录
2. 图片文件是否成功上传
3. 图片的公共 URL 是否可以访问

## 图片存储结构

```
avatars/
  └── {userId}/
      └── moments/
          ├── moment_{userId}_{uuid1}.jpg
          ├── moment_{userId}_{uuid2}.jpg
          └── ...
```

## 注意事项

1. **存储限制**：Supabase 免费版有存储空间限制，请注意控制图片大小
2. **图片格式**：当前代码将图片保存为 JPEG 格式
3. **文件大小**：建议在客户端压缩图片后再上传，以减少存储和带宽使用
4. **清理策略**：当用户删除 highlight 时，对应的图片文件也会从 Storage 中删除（需要实现删除逻辑）

## 故障排查

如果图片上传失败，检查：
1. `avatars` bucket 是否存在
2. RLS policies 是否正确配置
3. 用户是否已通过身份验证
4. 网络连接是否正常

