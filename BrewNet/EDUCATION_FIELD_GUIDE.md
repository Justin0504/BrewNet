# Education 字段存储指南

## 问题诊断

根据你提供的 JSON 数据：
```json
{
  "skills": ["1"],
  "industry": "Education & Research",
  "job_title": "1",
  "career_stage": "Early-career",
  "certifications": [],
  "current_company": "1",
  "experience_level": "Exec",
  "languages_spoken": [],
  "work_experiences": [...],
  "years_of_experience": 111
}
```

**没有 `educations` 字段**，这说明：
1. 在填写 Profile 时，没有点击"Add Education"按钮添加教育信息
2. 或者添加后被删除了

## 数据结构说明

### ProfessionalBackground 包含两个教育相关字段：

1. **`education` (旧字段)**: `String?`
   - 单行文本，例如："MIT · B.S. in Computer Science"
   - 保留用于向后兼容

2. **`educations` (新字段)**: `[Education]?`
   - 数组，可以存储多个详细的教育信息
   - 每个 Education 包含：
     ```swift
     {
       "id": "UUID",
       "school_name": "学校名称",
       "start_year": 2020,
       "end_year": 2024,
       "degree": "Bachelor's",
       "field_of_study": "Computer Science"
     }
     ```

## 使用步骤

### 在 App 中添加 Education：

1. 进入 Profile Setup 的 Step 2 (Professional Background)
2. 找到 "Education" 部分
3. 点击右侧的 "+" 按钮
4. 填写教育信息：
   - School Name（必填）
   - Start Year（必填）
   - End Year（可选，如果还在就读可以不选）
   - Degree（选择学位类型）
   - Field of Study（专业领域）
5. 点击 "Save"
6. 添加的教育会显示在列表中
7. 继续点击 "Next" 或 "Complete Setup"

### 验证数据是否保存：

运行以下 SQL 查询（在 Supabase Dashboard 的 SQL Editor 中）：

```sql
-- 查看你的 profile 数据（替换 YOUR_USER_ID）
SELECT 
    user_id,
    professional_background->'educations' as educations,
    jsonb_pretty(professional_background) as full_data
FROM profiles
WHERE user_id = 'YOUR_USER_ID';
```

## 代码逻辑确认

### 保存逻辑（ProfileSetupView.swift 第 1545 行）：

```swift
educations: educations.isEmpty ? nil : educations,
```

- 如果 `educations` 数组不为空，会保存到数据库
- 如果数组为空，字段设置为 `nil`（不会出现在 JSON 中）

### 更新触发（ProfileSetupView.swift 第 1524 行）：

```swift
.onChange(of: educations) { _ in updateProfileData() }
```

- 每次添加或删除 education，都会自动调用 `updateProfileData()`
- 确保数据实时更新到 `profileData`

## 常见问题

### Q1: 为什么我添加的 education 没有保存？

**A**: 检查以下几点：
1. 确认点击了 "Save" 按钮（在 AddEducationView 中）
2. 确认在 Step 2 页面看到了添加的 education 卡片
3. 确认点击了 "Next" 或 "Complete Setup" 完成整个流程
4. 检查是否有网络错误或保存失败的提示

### Q2: 数据库中看不到 educations 字段？

**A**: 
- 如果 educations 数组为空，字段不会出现在 JSON 中（这是正常的）
- 使用 SQL 查询验证：
  ```sql
  SELECT professional_background ? 'educations' as has_educations
  FROM profiles WHERE user_id = 'YOUR_USER_ID';
  ```

### Q3: 我可以同时使用旧的 education 字段和新的 educations 数组吗？

**A**: 
- 可以，两个字段都会被保存
- 推荐使用 `educations` 数组（新字段），因为它支持多个教育记录和更详细的信息

## 测试步骤

1. **运行 SQL 验证脚本**：
   - 在 Supabase Dashboard 打开 SQL Editor
   - 复制 `test_and_fix_education.sql` 中的查询
   - 运行步骤 1-3 验证表结构

2. **在 App 中测试**：
   - 编辑 Profile
   - 添加一个测试 Education
   - 保存并完成设置
   - 返回查看是否显示

3. **验证数据库**：
   - 运行步骤 6 的查询查看所有用户数据
   - 或使用步骤 5 查看特定用户数据

## 手动修复（如果需要）

如果需要手动在数据库中添加 education 数据：

```sql
-- 替换 YOUR_USER_ID 和教育信息
UPDATE profiles
SET professional_background = jsonb_set(
    professional_background,
    '{educations}',
    '[
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "school_name": "Stanford University",
            "start_year": 2016,
            "end_year": 2020,
            "degree": "Bachelor''s",
            "field_of_study": "Computer Science"
        }
    ]'::jsonb,
    true
),
updated_at = NOW()
WHERE user_id = 'YOUR_USER_ID';
```

## 文件清单

- `verify_education_field.sql` - 验证和诊断 SQL 查询
- `test_and_fix_education.sql` - 完整的测试和修复脚本
- `EDUCATION_FIELD_GUIDE.md` - 本文档

## 修改的代码文件

1. **ProfileModels.swift** (第 113-141 行)
   - 添加了 `educations: [Education]?` 字段
   - 保留了 `education: String?` 用于向后兼容

2. **ProfileSetupView.swift** (第 1545 行)
   - 更新了 `updateProfileData()` 方法
   - 添加 `educations` 到 `ProfessionalBackground` 初始化

3. **BrewNetMatchesView.swift**
   - 更新了示例数据，添加 `educations: nil`

4. **ChatInterfaceView.swift**
   - 更新了临时 profile 创建，添加 `educations: nil`

## 总结

- ✅ 代码逻辑正确，支持保存 educations 数组
- ✅ 数据库结构正确，JSONB 可以存储任何结构
- ⚠️ 从你的数据看，可能是没有添加任何 education
- 📝 使用提供的 SQL 脚本验证和测试

如果问题仍然存在，请：
1. 运行 `test_and_fix_education.sql` 中的诊断查询
2. 检查 App 中是否有错误提示
3. 查看 Xcode 控制台的日志输出

