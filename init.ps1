# init.ps1 - New API 项目初次配置脚本
# 用法：在项目根目录 (new-api/) 下执行 .\init.ps1

Write-Host "🚀 开始初始化 New API 项目配置..." -ForegroundColor Cyan

# 1️⃣ 生成高强度随机密钥 (SESSION_SECRET)
Write-Host "🔐 生成随机 SESSION_SECRET..." -ForegroundColor Yellow
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
$rng.GetBytes($bytes)
$generatedSecret = -join ($bytes | ForEach-Object { '{0:x2}' -f $_ })

# 2️⃣ 创建持久化目录
Write-Host "📁 创建持久化目录..." -ForegroundColor Yellow
New-Item -Path "data", "logs" -ItemType Directory -Force | Out-Null

# 3️⃣ 生成 .env 配置文件
Write-Host "⚙️ 生成 .env 配置文件..." -ForegroundColor Yellow
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$envContent = @"
# === New API 核心配置 ===
# 时区设置
TZ=Asia/Shanghai

# Session 加密密钥（自动生成的随机字符串）
SESSION_SECRET=$generatedSecret

# 数据库配置（默认使用 SQLite）
# 如需使用 MySQL，取消注释并填写：
# SQL_DSN=root:password@tcp(mysql:3306)/newapi

# 注册与登录设置
REGISTER_ENABLED=false
PASSWORD_LOGIN_ENABLED=true

# 服务器端口（容器内固定 3000，此处配置宿主机映射端口）
HOST_PORT=9528

# 日志级别
LOG_LEVEL=info

# 是否启用请求/响应日志（生产环境建议 false）
ENABLE_REQUEST_LOGS=false
ENABLE_RESPONSE_LOGS=false
"@
[IO.File]::WriteAllText("$PWD\.env", $envContent.Trim(), $utf8NoBom)

# 4️⃣ 生成 docker-compose.override.yml
Write-Host "🐳 生成 docker-compose.override.yml..." -ForegroundColor Yellow
$overrideContent = @'
version: '3.8'

services:
  new-api:
    ports:
      - "${HOST_PORT:-9528}:3000"
    environment:
      - TZ=${TZ}
      - SESSION_SECRET=${SESSION_SECRET}
      - SQL_DSN=${SQL_DSN:-/data/new-api.db}
      - REGISTER_ENABLED=${REGISTER_ENABLED}
      - PASSWORD_LOGIN_ENABLED=${PASSWORD_LOGIN_ENABLED}
      - LOG_LEVEL=${LOG_LEVEL}
      - ENABLE_REQUEST_LOGS=${ENABLE_REQUEST_LOGS}
      - ENABLE_RESPONSE_LOGS=${ENABLE_RESPONSE_LOGS}
    volumes:
      - ./data:/data:rw
      - ./logs:/app/logs:rw
    env_file:
      - ./.env
    restart: always
    networks:
      - new-api-network

networks:
  new-api-network:
    driver: bridge
'@
Set-Content -Path "docker-compose.override.yml" -Value $overrideContent -Encoding UTF8NoBOM -Force

# 5️⃣ 生成基础 docker-compose.yml（如果不存在）
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "📋 生成基础 docker-compose.yml..." -ForegroundColor Yellow
    $baseContent = @'
version: '3.8'

services:
  new-api:
    image: ghcr.io/quantumnous/new-api:latest
    container_name: new-api
    networks:
      - new-api-network

networks:
  new-api-network:
    driver: bridge
'@
    Set-Content -Path "docker-compose.yml" -Value $baseContent -Encoding UTF8NoBOM -Force
}

# 6️⃣ 配置 .gitignore
Write-Host "🔐 配置 .gitignore..." -ForegroundColor Yellow
$gitignoreRules = @"
# === Local setup & personal configs (NEVER commit) ===
.env
docker-compose.override.yml
data/
logs/
*.db
*.log
*.sqlite
"@
# 如果 .gitignore 不存在则创建，存在则追加（避免重复）
if (-not (Test-Path ".gitignore")) {
    Set-Content -Path ".gitignore" -Value $gitignoreRules -Encoding UTF8NoBOM -Force
} else {
    Add-Content -Path ".gitignore" -Value "`n$gitignoreRules" -Encoding UTF8NoBOM
}

# 7️⃣ 输出结果
Write-Host " "
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "✅ New API 配置初始化完成！" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " "
Write-Host "🔑 您的 SESSION_SECRET (请妥善保存):" -ForegroundColor Cyan
Write-Host "   $generatedSecret" -ForegroundColor White
Write-Host " "
Write-Host "🌐 服务访问信息:" -ForegroundColor Cyan
Write-Host "   管理面板: http://localhost:9528" -ForegroundColor White
Write-Host "   API 接口: http://localhost:9528/v1" -ForegroundColor White
Write-Host " "
Write-Host "👤 默认管理员账号:" -ForegroundColor Cyan
Write-Host "   用户名: root" -ForegroundColor White
Write-Host "   密码: 123456" -ForegroundColor Yellow
Write-Host "   ⚠️ 首次登录后请立即修改默认密码！" -ForegroundColor Yellow
Write-Host " "
Write-Host "📁 数据持久化目录: .\data\" -ForegroundColor Cyan
Write-Host "   包含: SQLite 数据库、用户数据、渠道配置等" -ForegroundColor Gray
Write-Host " "
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " "
Write-Host "🚀 下一步：执行以下命令启动服务" -ForegroundColor Cyan
Write-Host "   docker compose up -d" -ForegroundColor White
Write-Host " "
Write-Host "🔍 查看日志: docker compose logs -f new-api" -ForegroundColor Gray
Write-Host "🛑 停止服务: docker compose down" -ForegroundColor Gray
Write-Host " "
