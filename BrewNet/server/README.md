# LinkedIn OAuth Callback Redirect Server

这个服务器接收 LinkedIn 的 OAuth 回调并重定向到 iOS App 的 custom URL scheme。

## 功能

- 接收 LinkedIn OAuth 回调：`https://brewnet.app/auth/linkedin/callback?code=XXX&state=YYY`
- 302 重定向到 App Scheme：`brewnet://auth/linkedin?code=XXX&state=YYY`
- 处理 OAuth 错误并转发到 App

## 部署方案

### 方案 1: Supabase Edge Function（推荐）

如果你已经在使用 Supabase，这是最简单的方案。

**部署步骤：**

1. 安装 Supabase CLI：
   ```bash
   npm install -g supabase
   ```

2. 登录 Supabase：
   ```bash
   supabase login
   ```

3. 链接到你的项目：
   ```bash
   supabase link --project-ref jcxvdolcdifdghaibspy
   ```

4. 部署函数：
   ```bash
   supabase functions deploy linkedin-callback
   ```

5. 配置自定义域名（可选）：
   - 在 Supabase Dashboard → Settings → Custom Domains
   - 添加 `brewnet.app`
   - 配置 DNS 记录
   - 设置路由：`/auth/linkedin/callback` → `linkedin-callback` function

**函数 URL：**
- 默认：`https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/linkedin-callback`
- 自定义域名：`https://brewnet.app/auth/linkedin/callback`（需要配置）

### 方案 2: 独立 Node.js 服务器

**本地开发：**

1. 安装依赖：
   ```bash
   cd server
   npm install
   ```

2. 运行服务器：
   ```bash
   npm start
   ```

3. 服务器将在 `http://localhost:3001` 运行

**生产部署选项：**

#### A. Vercel（推荐用于简单部署）

1. 安装 Vercel CLI：
   ```bash
   npm i -g vercel
   ```

2. 创建 `vercel.json`：
   ```json
   {
     "version": 2,
     "builds": [
       {
         "src": "linkedin-callback-server.js",
         "use": "@vercel/node"
       }
     ],
     "routes": [
       {
         "src": "/auth/linkedin/callback",
         "dest": "/linkedin-callback-server.js"
       }
     ]
   }
   ```

3. 部署：
   ```bash
   vercel
   ```

4. 配置自定义域名：
   - Vercel Dashboard → Settings → Domains
   - 添加 `brewnet.app`
   - 配置 DNS 记录

#### B. Railway

1. 创建 `railway.json`：
   ```json
   {
     "build": {
       "builder": "NIXPACKS"
     },
     "deploy": {
       "startCommand": "node linkedin-callback-server.js",
       "restartPolicyType": "ON_FAILURE",
       "restartPolicyMaxRetries": 10
     }
   }
   ```

2. 在 Railway 创建新项目并连接 GitHub
3. 设置环境变量：`PORT=3001`, `APP_SCHEME=brewnet`
4. 配置自定义域名：`brewnet.app`

#### C. Render

1. 在 Render 创建新的 Web Service
2. 连接 GitHub 仓库
3. 设置：
   - Build Command: `npm install`
   - Start Command: `node linkedin-callback-server.js`
   - Environment: `PORT=3001`, `APP_SCHEME=brewnet`
4. 配置自定义域名：`brewnet.app`

#### D. DigitalOcean App Platform

1. 创建新 App
2. 选择 Node.js 环境
3. 设置：
   - Run Command: `node linkedin-callback-server.js`
   - Environment Variables: `PORT=3001`, `APP_SCHEME=brewnet`
4. 配置自定义域名：`brewnet.app`

#### E. AWS Lambda + API Gateway

需要转换为 serverless 函数格式（参考 AWS Lambda 文档）

## 配置 Nginx 反向代理（如果使用独立服务器）

如果你在 VPS 上运行服务器，需要配置 Nginx：

```nginx
server {
    listen 443 ssl http2;
    server_name brewnet.app;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location /auth/linkedin/callback {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 环境变量

- `PORT`: 服务器端口（默认：3001）
- `APP_SCHEME`: App 的 URL scheme（默认：brewnet）

## 测试

1. 启动服务器
2. 访问：`http://localhost:3001/auth/linkedin/callback?code=test123&state=test456`
3. 应该重定向到：`brewnet://auth/linkedin?code=test123&state=test456`

## LinkedIn Developer Portal 配置

确保在 LinkedIn Developer Portal 中添加了以下 Redirect URL：

- `https://brewnet.app/auth/linkedin/callback`

## 故障排除

1. **302 重定向不工作**：
   - 检查 App 的 Info.plist 中是否配置了 `brewnet` URL scheme
   - 检查 `ASWebAuthenticationSession` 的 `callbackURLScheme` 是否设置为 `"brewnet"`

2. **服务器无法访问**：
   - 检查防火墙设置
   - 检查 DNS 配置
   - 验证 SSL 证书

3. **重定向到错误的 URL**：
   - 检查 `APP_SCHEME` 环境变量
   - 验证 URL 编码是否正确

