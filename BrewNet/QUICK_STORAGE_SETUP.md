# 快速设置 Supabase Storage

## 🚨 错误：Bucket not found

您需要在 Supabase Dashboard 中创建 `avatars` 存储桶。

---

## ⚡ 快速修复步骤

### 1️⃣ 创建存储桶（1 分钟）

1. **打开 Supabase Dashboard**
   - 访问: https://supabase.com/dashboard
   - 选择项目: `jcxvdolcdifdghaibspy`

2. **进入 Storage**
   - 左侧菜单：**Storage**
   - 顶部标签：**Buckets**

3. **创建新桶**
   - 点击 **"New bucket"**
   - 填写：
     ```
     名称: avatars
     ```
   - ✅ 勾选 **"Public bucket"**（重要！）
   - 点击 **"Create bucket"**

4. **完成！**

---

### 2️⃣ 配置存储策略（2 分钟）

**重要：** 如果不配置策略，上传会失败！

#### 方式 1：使用 SQL 脚本（推荐）

1. **打开 SQL Editor**
   - Supabase Dashboard > SQL Editor

2. **执行脚本**
   - 复制 `create_storage_policies.sql` 文件中的所有 SQL
   - 粘贴到 SQL Editor
   - 点击 "Run" 执行

3. **完成！**

#### 方式 2：手动创建策略

1. **进入 Policies**
   - **Storage** > **Policies**
   - 选择 **avatars** 桶

2. **创建策略**

   点击 **"New Policy"** 四次，分别创建：

   **Policy 1 - Upload avatars**
   ```
   Policy name: Users can upload their own avatars
   Target roles: Authenticated
   Operation: INSERT
   
   Policy definition:
   bucket_id = 'avatars'
   
   Policy with check:
   bucket_id = 'avatars' AND owner_id = auth.uid()
   ```

   **Policy 2 - Update avatars**
   ```
   Policy name: Users can update their own avatars
   Target roles: Authenticated
   Operation: UPDATE
   
   Policy definition:
   bucket_id = 'avatars' AND owner_id = auth.uid()
   
   Policy with check:
   bucket_id = 'avatars' AND owner_id = auth.uid()
   ```

   **Policy 3 - Delete avatars**
   ```
   Policy name: Users can delete their own avatars
   Target roles: Authenticated
   Operation: DELETE
   
   Policy definition:
   bucket_id = 'avatars' AND owner_id = auth.uid()
   ```

   **Policy 4 - View avatars (public access)**
   ```
   Policy name: Anyone can view avatars
   Target roles: Public
   Operation: SELECT
   
   Policy definition:
   bucket_id = 'avatars'
   ```

3. **保存所有策略**

---

### 3️⃣ 验证配置

1. **在 Dashboard 中检查**
   - Storage > Buckets
   - 确认 `avatars` 桶存在且为 Public

2. **在应用中测试**
   - 打开 Profile Setup
   - 尝试上传头像
   - 应成功上传

---

## 📸 截图参考

### 创建桶界面
```
┌─────────────────────────────────────┐
│ Bucket name          [ avatars   ] │
│                                     │
│ ☑ Public bucket                    │
│   Makes bucket publicly accessible  │
│                                     │
│ ☐ File size limit                  │
│ ☐ Allowed MIME types               │
│                                     │
│        [ Cancel ]  [ Create bucket ]│
└─────────────────────────────────────┘
```

### 策略配置界面
```
┌─────────────────────────────────────────┐
│ avatars bucket policies                 │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Users can upload their own avatars  │ │
│ │ Operation: INSERT                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Users can update their own avatars  │ │
│ │ Operation: UPDATE                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Users can delete their own avatars  │ │
│ │ Operation: DELETE                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Anyone can view avatars             │ │
│ │ Operation: SELECT                   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│           [ New Policy ]                │
└─────────────────────────────────────────┘
```

---

## ❌ 常见错误

### 错误 1: "Bucket not found"
**原因：** 存储桶未创建  
**解决：** 按照步骤 1️⃣ 创建 `avatars` 桶

### 错误 2: "new row violates row-level security policy"
**原因：** 策略未配置  
**解决：** 按照步骤 2️⃣ 创建所有策略

### 错误 3: 上传成功但图片无法显示
**原因：** 桶不是 Public  
**解决：** 编辑 `avatars` 桶，开启 "Public bucket"

### 错误 4: "permission denied"
**原因：** 策略配置错误  
**解决：** 检查策略中的 policy definition 是否正确

---

## ✅ 完成检查清单

- [ ] `avatars` 桶已创建
- [ ] 桶设置为 Public
- [ ] 4 个策略已创建
- [ ] 上传策略（INSERT）
- [ ] 更新策略（UPDATE）
- [ ] 删除策略（DELETE）
- [ ] 查看策略（SELECT）
- [ ] 在应用中测试上传成功

---

## 🆘 仍然遇到问题？

1. **检查项目选择**
   - 确认选择了正确的项目：`jcxvdolcdifdghaibspy`

2. **清除缓存**
   - 重新登录应用
   - 重启应用

3. **查看日志**
   - 应用控制台中的详细错误信息
   - Supabase Dashboard > Logs

4. **验证 URL**
   - 确认 SupabaseConfig.swift 中的 URL 正确

---

**设置完成后，头像上传功能即可正常工作！** 🎉

