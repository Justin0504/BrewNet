# 快速修复指南 - Profile Error

## 🎯 问题
主页面显示：**"Error: Some profile data is incomplete. Please refresh to try again."**

## ✅ 快速修复步骤（5分钟）

### 1️⃣ 诊断问题
在Supabase Dashboard的SQL Editor中运行：
```sql
-- 检查不完整的profiles数量
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN networking_preferences->'available_timeslot' IS NULL THEN 1 END) as missing_timeslot,
    COUNT(CASE WHEN core_identity ? 'available_timeslot' THEN 1 END) as timeslot_in_wrong_place
FROM profiles;
```

### 2️⃣ 运行自动修复
复制并运行 `fix_incomplete_profiles.sql` 文件中的所有SQL语句。

**或者，运行这个快速修复（最常见问题）：**
```sql
-- 快速修复：移动available_timeslot到正确位置
DO $$
DECLARE
    profile_record RECORD;
    timeslot_data jsonb;
BEGIN
    FOR profile_record IN 
        SELECT id, user_id, core_identity, networking_preferences
        FROM profiles
        WHERE core_identity ? 'available_timeslot'
           OR networking_preferences->'available_timeslot' IS NULL
    LOOP
        IF profile_record.core_identity ? 'available_timeslot' THEN
            timeslot_data := profile_record.core_identity->'available_timeslot';
            
            UPDATE profiles
            SET networking_preferences = jsonb_set(
                networking_preferences,
                '{available_timeslot}',
                timeslot_data
            )
            WHERE id = profile_record.id;
            
            UPDATE profiles
            SET core_identity = core_identity - 'available_timeslot'
            WHERE id = profile_record.id;
        END IF;
        
        IF (SELECT networking_preferences->'available_timeslot' FROM profiles WHERE id = profile_record.id) IS NULL THEN
            UPDATE profiles
            SET networking_preferences = jsonb_set(
                networking_preferences,
                '{available_timeslot}',
                '{
                    "sunday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "monday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "tuesday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "wednesday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "thursday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "friday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false},
                    "saturday": {"morning": false, "noon": false, "afternoon": false, "evening": false, "night": false}
                }'::jsonb
            )
            WHERE id = profile_record.id;
        END IF;
    END LOOP;
END $$;

-- 修复空数组字段
UPDATE profiles SET professional_background = jsonb_set(professional_background, '{skills}', '[]'::jsonb) WHERE professional_background->'skills' IS NULL;
UPDATE profiles SET networking_intention = jsonb_set(networking_intention, '{selected_sub_intentions}', '[]'::jsonb) WHERE networking_intention->'selected_sub_intentions' IS NULL;
UPDATE profiles SET personality_social = jsonb_set(personality_social, '{icebreaker_prompts}', '[]'::jsonb) WHERE personality_social->'icebreaker_prompts' IS NULL;
UPDATE profiles SET personality_social = jsonb_set(personality_social, '{values_tags}', '[]'::jsonb) WHERE personality_social->'values_tags' IS NULL;
UPDATE profiles SET personality_social = jsonb_set(personality_social, '{hobbies}', '[]'::jsonb) WHERE personality_social->'hobbies' IS NULL;
```

### 3️⃣ 验证修复
```sql
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN 
        networking_preferences->'available_timeslot' IS NOT NULL
        AND professional_background->'skills' IS NOT NULL
        AND networking_intention->'selected_sub_intentions' IS NOT NULL
    THEN 1 END) as fixed_profiles
FROM profiles;
```

应该看到：`total_profiles` = `fixed_profiles`

### 4️⃣ 重启应用
1. 完全关闭应用
2. 重新启动
3. 导航到主页面
4. ✅ 错误应该消失了！

## 🔍 如何查看详细错误信息

现在当错误发生时，Xcode控制台会显示：

```
🔍 详细错误: Data format issue: Missing 'available_timeslot' at networking_preferences
❌ Failed to decode networking_preferences for user [user-id]: [error details]
```

而不是简单的："Some profile data is incomplete"

## 📊 代码改进摘要

### 1. BrewNetMatchesView.swift
- ✅ 增强错误诊断，显示具体缺失字段
- ✅ 显示字段路径（例如：`networking_preferences.available_timeslot`）

### 2. SupabaseModels.swift
- ✅ 为每个JSONB字段添加独立错误捕获
- ✅ 打印具体哪个用户的哪个字段解码失败

### 3. SQL修复脚本
- ✅ `debug_profile_data.sql` - 诊断工具
- ✅ `fix_incomplete_profiles.sql` - 自动修复工具

## 🛟 如果问题仍然存在

1. 查看Xcode控制台，找到详细错误
2. 记下用户ID和缺失的字段
3. 在Supabase中查询该用户：
```sql
SELECT * FROM profiles WHERE user_id = 'USER_ID_FROM_ERROR';
```
4. 检查JSON结构，对比正常的profile

## 📝 需要更多帮助？

查看完整文档：`PROFILE_ERROR_DIAGNOSIS_AND_FIX.md`

