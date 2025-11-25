# 注册失败错误排查与分析

## 错误信息
**"Registration failed, please try again later"**

这个错误消息来自 `AuthError.unknownError` 的 `errorDescription`（`AuthManager.swift` 第 1003 行）。

---

## 注册流程分析

### 完整注册流程

```
1. RegisterView.createAccount()
   ↓
2. AuthManager.register(email, password, name)
   ↓
3. AuthManager.supabaseRegister(email, password, name)
   ↓
4. Supabase auth.signUp() ✅ 成功
   ↓
5. 创建 SupabaseUser 对象
   ↓
6. supabaseService.createUser(user: supabaseUser) ❌ 可能失败
   ↓
7. catch 块捕获错误 → 返回 .unknownError
   ↓
8. RegisterView 显示 "Registration failed, please try again later"
```

---

## 可能失败的原因

### 1. **SupabaseService 为 nil** ⚠️

**位置**: `AuthManager.swift` 第 652、770 行

```swift
if let createdUser = try await supabaseService?.createUser(user: supabaseUser) {
    // 成功
} else {
    // supabaseService 为 nil
    print("⚠️ Supabase 服务不可用")
    return .failure(.unknownError)
}
```

**原因**:
- `supabaseService` 未正确注入到 `AuthManager`
- 初始化顺序问题

**检查方法**:
```swift
// 在 AuthManager.supabaseRegister() 中添加日志
print("🔍 [注册] supabaseService 状态: \(supabaseService != nil ? "可用" : "nil")")
```

---

### 2. **数据库插入失败** ⚠️⚠️⚠️

**位置**: `SupabaseService.swift` 第 255-261 行

```swift
func createUser(user: SupabaseUser) async throws -> SupabaseUser {
    let response = try await client
        .from(SupabaseTable.users.rawValue)
        .insert(user)
        .select()
        .single()
        .execute()
    // ...
}
```

**可能原因**:

#### A. **字段缺失或 NULL 约束违反**

**问题**: `users` 表可能有 NOT NULL 约束的字段，但 `SupabaseUser` 对象中某些字段为 `nil`。

**检查字段**:
- `id` ✅ (必需)
- `email` ✅ (必需)
- `name` ✅ (必需)
- `is_guest` ✅ (必需，默认 false)
- `profile_setup_completed` ✅ (必需，默认 false)
- `created_at` ✅ (必需)
- `last_login_at` ✅ (必需)
- `updated_at` ✅ (必需)
- `is_pro` ✅ (必需，默认 false)
- `likes_remaining` ✅ (必需，默认 6)

**可能的问题字段**:
- `phone_number` - 如果表定义为 NOT NULL，但注册时可能为 nil
- `profile_image` - 如果表定义为 NOT NULL
- 其他可选字段

#### B. **字段类型不匹配**

**问题**: Swift 模型中的类型与数据库列类型不匹配。

**检查**:
- `is_pro`: Swift `Bool` vs 数据库 `BOOLEAN` ✅
- `likes_remaining`: Swift `Int` vs 数据库 `INTEGER` ✅
- `created_at`: Swift `String` (ISO8601) vs 数据库 `TIMESTAMP` ✅

#### C. **重复键错误**

**问题**: 如果 `id` 或 `email` 已存在。

**检查**:
```sql
-- 在 Supabase SQL Editor 中执行
SELECT id, email FROM users WHERE id = 'user-id-here' OR email = 'user-email-here';
```

#### D. **RLS (Row Level Security) 策略阻止插入**

**问题**: Supabase 的 RLS 策略可能阻止新用户插入。

**检查方法**:
1. 登录 Supabase Dashboard
2. 进入 `Authentication` → `Policies`
3. 检查 `users` 表的 INSERT 策略

**建议策略**:
```sql
-- 允许认证用户插入自己的记录
CREATE POLICY "Users can insert their own record"
ON users FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id);
```

#### E. **网络连接问题**

**问题**: 插入操作时网络连接失败或超时。

**检查**:
- 查看 Xcode 控制台的网络错误日志
- 检查 Supabase 服务状态

---

### 3. **JSON 编码/解码失败** ⚠️

**位置**: `SupabaseService.swift` 第 264 行

```swift
let createdUser = try JSONDecoder().decode(SupabaseUser.self, from: data)
```

**可能原因**:
- 数据库返回的字段与 `SupabaseUser` 模型不匹配
- 日期格式不匹配
- 字段类型不匹配

---

## 排查步骤

### 步骤 1: 检查控制台日志

在 Xcode 控制台中查找以下日志：

```
🚀 开始 Supabase 注册: [email]
✅ Supabase 注册响应成功
👤 用户 ID: [uuid]
⚠️ Supabase 数据保存失败: [error message]
❌ Supabase 注册失败:
🔍 错误类型: [error type]
📝 错误信息: [error description]
```

**关键日志**:
- 如果看到 "✅ Supabase 注册响应成功" 但后续失败 → 问题在 `createUser()`
- 如果看到 "⚠️ Supabase 服务不可用" → `supabaseService` 为 nil
- 如果看到网络错误 → 网络连接问题

---

### 步骤 2: 检查 Supabase Dashboard

1. **检查 users 表结构**:
   - 进入 `Table Editor` → `users`
   - 查看所有列及其约束（NOT NULL, DEFAULT 值等）

2. **检查 RLS 策略**:
   - 进入 `Authentication` → `Policies`
   - 查看 `users` 表的 INSERT 策略

3. **检查错误日志**:
   - 进入 `Logs` → `Postgres Logs`
   - 查看最近的错误信息

---

### 步骤 3: 测试数据库插入

在 Supabase SQL Editor 中执行测试插入：

```sql
-- 测试插入（使用实际值替换）
INSERT INTO users (
    id,
    email,
    name,
    is_guest,
    profile_setup_completed,
    created_at,
    last_login_at,
    updated_at,
    is_pro,
    likes_remaining
) VALUES (
    gen_random_uuid(),
    'test@example.com',
    'Test User',
    false,
    false,
    NOW(),
    NOW(),
    NOW(),
    false,
    6
);
```

**如果插入失败**:
- 查看错误消息
- 检查哪个字段有问题
- 修复表结构或 Swift 模型

---

### 步骤 4: 添加详细错误日志

在 `SupabaseService.createUser()` 中添加更详细的错误处理：

```swift
func createUser(user: SupabaseUser) async throws -> SupabaseUser {
    do {
        print("🔍 [createUser] 开始插入用户: \(user.id)")
        print("📊 [createUser] 用户数据: email=\(user.email), name=\(user.name)")
        
        let response = try await client
            .from(SupabaseTable.users.rawValue)
            .insert(user)
            .select()
            .single()
            .execute()
        
        print("✅ [createUser] 插入成功，状态码: \(response.response.statusCode)")
        
        let data = response.data
        print("📦 [createUser] 响应数据大小: \(data.count) bytes")
        print("📄 [createUser] 响应内容: \(String(data: data, encoding: .utf8) ?? "无法解析")")
        
        let createdUser = try JSONDecoder().decode(SupabaseUser.self, from: data)
        print("✅ [createUser] 解码成功: \(createdUser.name)")
        
        return createdUser
        
    } catch {
        print("❌ [createUser] 插入失败:")
        print("   - 错误类型: \(type(of: error))")
        print("   - 错误信息: \(error.localizedDescription)")
        
        // 尝试解析 Supabase 错误响应
        if let httpError = error as? URLError {
            print("   - URLError 代码: \(httpError.code.rawValue)")
        }
        
        // 如果是 Supabase 错误，尝试获取详细错误信息
        if let nsError = error as NSError? {
            print("   - NSError 代码: \(nsError.code)")
            print("   - NSError 域: \(nsError.domain)")
            print("   - NSError 用户信息: \(nsError.userInfo)")
        }
        
        throw error
    }
}
```

---

## 改进建议

### 1. **改进错误处理**

在 `AuthManager.supabaseRegister()` 中提供更具体的错误信息：

```swift
} catch {
    print("❌ Supabase 注册失败:")
    print("🔍 错误类型: \(type(of: error))")
    print("📝 错误信息: \(error.localizedDescription)")
    
    // 解析具体错误类型
    let errorMessage = error.localizedDescription.lowercased()
    
    if errorMessage.contains("duplicate") || errorMessage.contains("already exists") {
        return .failure(.emailAlreadyExists)
    } else if errorMessage.contains("null") || errorMessage.contains("not null") {
        return .failure(.unknownError) // 可以添加新的错误类型：.databaseError
    } else if errorMessage.contains("permission") || errorMessage.contains("policy") {
        return .failure(.unknownError) // 可以添加新的错误类型：.permissionDenied
    } else if let httpError = error as? URLError {
        return .failure(.networkError)
    } else {
        // 提供更详细的错误信息
        print("📋 完整错误详情:")
        if let nsError = error as NSError? {
            print("   - 代码: \(nsError.code)")
            print("   - 域: \(nsError.domain)")
            print("   - 用户信息: \(nsError.userInfo)")
        }
        return .failure(.unknownError)
    }
}
```

### 2. **验证 SupabaseUser 数据完整性**

在插入前验证所有必需字段：

```swift
func createUser(user: SupabaseUser) async throws -> SupabaseUser {
    // 验证必需字段
    guard !user.id.isEmpty,
          !user.email.isEmpty,
          !user.name.isEmpty,
          !user.createdAt.isEmpty,
          !user.lastLoginAt.isEmpty,
          !user.updatedAt.isEmpty else {
        throw ProfileError.invalidData("必需字段缺失")
    }
    
    // 继续插入...
}
```

### 3. **添加重试机制**

对于网络错误，添加重试逻辑：

```swift
func createUser(user: SupabaseUser) async throws -> SupabaseUser {
    var lastError: Error?
    let maxRetries = 3
    
    for attempt in 1...maxRetries {
        do {
            return try await performInsert(user: user)
        } catch {
            lastError = error
            if attempt < maxRetries {
                print("⚠️ 插入失败，重试 \(attempt)/\(maxRetries)")
                try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(attempt)) // 递增延迟
            }
        }
    }
    
    throw lastError ?? ProfileError.creationFailed("插入失败")
}
```

### 4. **检查 SupabaseService 初始化**

确保 `supabaseService` 在 `AuthManager` 初始化时已正确注入：

```swift
// 在 ContentView 或 App 入口处
let authManager = AuthManager()
let supabaseService = SupabaseService.shared

authManager.supabaseService = supabaseService
supabaseService.setDependencies(databaseManager: databaseManager)
```

---

## 快速修复检查清单

- [ ] 检查 Xcode 控制台的详细错误日志
- [ ] 验证 `supabaseService` 不为 nil
- [ ] 检查 Supabase Dashboard 中的 `users` 表结构
- [ ] 验证所有 NOT NULL 字段都有值
- [ ] 检查 RLS 策略是否允许 INSERT
- [ ] 测试在 Supabase SQL Editor 中手动插入用户
- [ ] 检查网络连接
- [ ] 验证 Supabase 服务状态

---

## 常见错误消息对照表

| 错误消息 | 可能原因 | 解决方案 |
|---------|---------|---------|
| "duplicate key value violates unique constraint" | 用户已存在 | 检查 email 或 id 是否重复 |
| "null value in column violates not-null constraint" | 必需字段为 NULL | 检查所有 NOT NULL 字段 |
| "permission denied for table users" | RLS 策略阻止 | 检查并更新 RLS 策略 |
| "network connection failed" | 网络问题 | 检查网络连接和 Supabase 状态 |
| "column does not exist" | 表结构不匹配 | 检查表结构并更新模型 |

---

## 下一步行动

1. **立即检查**: 查看 Xcode 控制台的完整错误日志
2. **验证数据库**: 在 Supabase Dashboard 中检查 `users` 表结构和 RLS 策略
3. **添加日志**: 在 `createUser()` 中添加详细错误日志
4. **测试插入**: 在 Supabase SQL Editor 中测试手动插入
5. **修复问题**: 根据具体错误消息修复问题

---

## 相关文件

- `AuthManager.swift` - 注册逻辑
- `SupabaseService.swift` - 数据库操作
- `SupabaseModels.swift` - 数据模型
- `RegisterView.swift` - UI 和错误显示

