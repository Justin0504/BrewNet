# 修复 BrewNet Pro 数据库错误

## ⚠️ 错误症状
```
Error: Failed to load profiles: Status Code: 400 Body: Bad Request
```

## 🔍 原因
数据库 `users` 表中缺少 BrewNet Pro 相关的列。

## ✅ 解决方案

### 步骤 1: 检查数据库列是否存在

在 **Supabase Dashboard > SQL Editor** 中运行：

```sql
-- 检查 users 表中是否有 Pro 相关的列
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('is_pro', 'pro_start', 'pro_end', 'likes_remaining', 'likes_depleted_at')
ORDER BY column_name;
```

**期望结果：** 应该返回 5 行
- `is_pro` (boolean)
- `likes_depleted_at` (timestamp with time zone)
- `likes_remaining` (integer)
- `pro_end` (timestamp with time zone)
- `pro_start` (timestamp with time zone)

**如果返回 0 行或少于 5 行，继续下一步。**

### 步骤 2: 运行 Pro 列迁移脚本

在 **Supabase Dashboard > SQL Editor** 中，复制粘贴并运行整个 `add_brewnet_pro_columns.sql` 文件的内容：

```sql
-- Add BrewNet Pro subscription fields to users table

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS pro_start TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS pro_end TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS likes_remaining INTEGER DEFAULT 10,
ADD COLUMN IF NOT EXISTS likes_depleted_at TIMESTAMP WITH TIME ZONE;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_is_pro ON users(is_pro);
CREATE INDEX IF NOT EXISTS idx_users_pro_end ON users(pro_end);

-- Create function to auto-reset likes
CREATE OR REPLACE FUNCTION reset_likes_if_expired()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_pro = FALSE AND 
       NEW.likes_depleted_at IS NOT NULL AND 
       (CURRENT_TIMESTAMP - NEW.likes_depleted_at) >= INTERVAL '24 hours' THEN
        NEW.likes_remaining := 10;
        NEW.likes_depleted_at := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_reset_likes ON users;
CREATE TRIGGER trigger_reset_likes
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION reset_likes_if_expired();
```

### 步骤 3: 验证迁移成功

再次运行检查查询：

```sql
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('is_pro', 'pro_start', 'pro_end', 'likes_remaining', 'likes_depleted_at')
ORDER BY column_name;
```

**应该看到 5 行结果！**

### 步骤 4: 重启 App

1. 完全关闭 BrewNet app
2. 从 Xcode 重新运行
3. 错误应该消失了！

## 🎁 可选：给现有用户赠送 Pro

如果你想给所有现有用户赠送 1 周免费 Pro：

```sql
-- 给所有现有用户赠送 1 周免费 Pro
UPDATE users
SET 
    is_pro = TRUE,
    pro_start = NOW(),
    pro_end = NOW() + INTERVAL '7 days',
    likes_remaining = 999999
WHERE is_pro IS NULL OR is_pro = FALSE;
```

## 🧪 测试 Pro 功能

运行迁移后，测试以下功能：

1. ✅ 创建新账号 → 应该自动获得 1 周免费 Pro
2. ✅ Profile 页面显示 Pro badge
3. ✅ 滑动卡片显示 Pro badge
4. ✅ 点赞 10 次以上 → 显示付款页面
5. ✅ 点击临时聊天 (非Pro账号) → 显示付款页面
6. ✅ 点击 Pro-only filters → 显示付款页面

## 📞 如果问题仍然存在

### 检查具体错误

查看 Xcode 控制台，找到具体的错误信息：
```
❌ Failed to fetch with Pro columns, trying without: [错误详情]
```

### 常见问题

1. **RLS (Row Level Security) 问题**
   
   如果迁移成功但仍有错误，可能是 RLS 策略问题：
   ```sql
   -- 允许用户读取自己的数据
   ALTER TABLE users ENABLE ROW LEVEL SECURITY;
   
   CREATE POLICY "Users can read own data" ON users
       FOR SELECT USING (auth.uid()::text = id);
   
   CREATE POLICY "Users can update own data" ON users
       FOR UPDATE USING (auth.uid()::text = id);
   ```

2. **权限问题**
   
   确保你的 Supabase 服务角色有权限修改表结构：
   ```sql
   -- 检查当前用户权限
   SELECT current_user, session_user;
   ```

## 🔄 代码已优化

代码已更新为向后兼容模式：
- 首先尝试获取包含 Pro 列的数据
- 如果失败（列不存在），回退到不包含 Pro 列的查询
- 解码时使用默认值（isPro: false, likesRemaining: 10）

这样即使暂时不运行迁移，app 也不会崩溃。但建议尽快运行迁移以启用完整的 Pro 功能。

