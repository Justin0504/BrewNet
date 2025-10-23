# 🗄️ BrewNet Supabase Database Setup Guide

## 📋 完整的数据库设置

### 🚀 快速设置（推荐）

1. **打开 Supabase Dashboard**
   - 进入您的项目
   - 点击左侧菜单的 "SQL Editor"

2. **执行完整设置脚本**
   ```sql
   -- 复制并粘贴 complete_database_setup.sql 的全部内容
   -- 点击 "Run" 按钮执行
   ```

3. **验证设置**
   ```sql
   -- 复制并粘贴 verify_database.sql 的全部内容
   -- 点击 "Run" 按钮执行
   ```

### 📊 数据库结构

#### 核心表
- ✅ **users** - 用户基础信息
- ✅ **profiles** - 详细用户资料（JSONB 格式）
- ✅ **posts** - 帖子内容
- ✅ **likes** - 点赞记录
- ✅ **saves** - 收藏记录

#### 社交功能表
- ✅ **matches** - 用户匹配
- ✅ **coffee_chats** - 咖啡聊天安排
- ✅ **messages** - 私信系统
- ✅ **anonymous_posts** - 匿名帖子

### 🔒 安全特性

#### Row Level Security (RLS)
- ✅ 所有表都启用了 RLS
- ✅ 用户只能访问自己的数据
- ✅ 公开内容（如帖子）所有人可查看

#### 权限策略
- ✅ 用户管理自己的资料
- ✅ 用户管理自己的帖子
- ✅ 用户管理自己的匹配和聊天

### ⚡ 性能优化

#### 索引
- ✅ 用户邮箱索引
- ✅ 帖子作者索引
- ✅ 时间戳索引
- ✅ 标签索引

#### 触发器
- ✅ 自动更新时间戳
- ✅ 数据一致性维护

### 🧪 测试数据

#### 示例用户
- ✅ 测试用户账户
- ✅ 完整资料示例
- ✅ 所有字段填充

#### 验证查询
- ✅ 表存在性检查
- ✅ RLS 状态检查
- ✅ 策略数量检查
- ✅ 索引状态检查

### 🔧 故障排除

#### 常见问题

1. **表不存在**
   ```sql
   -- 检查表是否存在
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public';
   ```

2. **RLS 未启用**
   ```sql
   -- 检查 RLS 状态
   SELECT tablename, rowsecurity FROM pg_tables 
   WHERE schemaname = 'public';
   ```

3. **权限问题**
   ```sql
   -- 检查策略
   SELECT * FROM pg_policies WHERE schemaname = 'public';
   ```

#### 重新设置
如果遇到问题，可以删除所有表并重新运行设置脚本：

```sql
-- 删除所有表（谨慎使用）
DROP TABLE IF EXISTS anonymous_posts CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS coffee_chats CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS saves CASCADE;
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
```

### 📈 监控和维护

#### 性能监控
- 使用 Supabase Dashboard 监控查询性能
- 检查慢查询日志
- 监控数据库连接数

#### 数据备份
- Supabase 自动备份
- 定期导出重要数据
- 测试恢复流程

### 🎯 下一步

1. **测试应用连接**
   - 验证 Supabase 配置
   - 测试 CRUD 操作
   - 检查错误日志

2. **优化性能**
   - 添加更多索引（如需要）
   - 优化查询语句
   - 监控使用情况

3. **扩展功能**
   - 添加新表（如需要）
   - 实现高级搜索
   - 添加数据分析

---

## ✅ 设置完成检查清单

- [ ] 执行 `complete_database_setup.sql`
- [ ] 运行 `verify_database.sql`
- [ ] 确认所有表都存在
- [ ] 确认 RLS 已启用
- [ ] 确认策略已创建
- [ ] 确认索引已创建
- [ ] 确认触发器已创建
- [ ] 确认示例数据已插入
- [ ] 测试应用连接

**🎉 完成！您的 BrewNet 数据库现在已经完全设置好了！**
