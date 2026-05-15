# init.ps1 - New API 项目初始化脚本（双模式通用版）
# 用法：
#   个人模式（默认）: .\init.ps1
#   企业模式       : .\init.ps1 -Mode Enterprise
#   切换模式       : .\init.ps1 -SwitchMode

param(
    [ValidateSet("Personal", "Enterprise")]
    [string]$Mode = "Personal",
    [switch]$SwitchMode
)

Write-Host "🚀 开始初始化 New API 项目配置..." -ForegroundColor Cyan
Write-Host "   当前模式: $Mode" -ForegroundColor Gray

# ─────────────────────────────────────────────────────
# 1️⃣ 生成高强度随机密钥 (SESSION_SECRET)
# ─────────────────────────────────────────────────────
Write-Host "🔐 生成随机 SESSION_SECRET..." -ForegroundColor Yellow
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
$rng.GetBytes($bytes)
$generatedSecret = -join ($bytes | ForEach-Object { '{0:x2}' -f $_ })

# ─────────────────────────────────────────────────────
# 2️⃣ 创建持久化目录（两种模式共用）
# ─────────────────────────────────────────────────────
Write-Host "📁 创建持久化目录..." -ForegroundColor Yellow
New-Item -Path "data", "logs", "mysql_data" -ItemType Directory -Force | Out-Null

# ─────────────────────────────────────────────────────
# 3️⃣ 生成 .env 配置文件（根据模式分流）
# ─────────────────────────────────────────────────────
Write-Host "⚙️ 生成 .env 配置文件 (模式: $Mode)..." -ForegroundColor Yellow
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

if ($Mode -eq "Personal") {
    # 🔹 个人模式：SQLite（默认，简单轻量）
    $envContent = @"
# === New API 核心配置 ===
TZ=Asia/Shanghai
SESSION_SECRET=$generatedSecret

# 🔹 数据库配置：个人模式使用 SQLite（无需额外配置）
#    如需切换企业模式，运行: .\init.ps1 -Mode Enterprise -SwitchMode

# 注册与登录设置
REGISTER_ENABLED=false
PASSWORD_LOGIN_ENABLED=true

# 服务器端口
HOST_PORT=9528

# 日志配置
LOG_LEVEL=info
ENABLE_REQUEST_LOGS=false
ENABLE_RESPONSE_LOGS=false

# === 企业模式配置（当前未启用，切换后自动生效）===
# DB_TYPE=mysql
# MYSQL_ROOT_PASSWORD=ChangeMe123!
# MYSQL_DATABASE=newapi
# MYSQL_USER=newapi
# MYSQL_PASSWORD=ChangeMe456!
# REDIS_PASSWORD=ChangeMe789!
"@
} else {
    # 🔹 企业模式：MySQL + Redis（高可用，支持集群）
    $mysqlRootPass = -join ((65..90) + (97..122) + (48..57) + (33,35,36,37,38) | Get-Random -Count 16 | % {[char]$_})
    $mysqlUserPass = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})
    $redisPass = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})
    
    $envContent = @"
# === New API 核心配置 ===
TZ=Asia/Shanghai
SESSION_SECRET=$generatedSecret

# 🔹 数据库配置：企业模式使用 MySQL + Redis
DB_TYPE=mysql
MYSQL_ROOT_PASSWORD=$mysqlRootPass
MYSQL_DATABASE=newapi
MYSQL_USER=newapi
MYSQL_PASSWORD=$mysqlUserPass
REDIS_PASSWORD=$redisPass

# 注册与登录设置
REGISTER_ENABLED=false
PASSWORD_LOGIN_ENABLED=true

# 服务器端口
HOST_PORT=9528

# 日志配置（企业模式建议关闭详细日志）
LOG_LEVEL=warn
ENABLE_REQUEST_LOGS=false
ENABLE_RESPONSE_LOGS=false

# === 个人模式配置（当前未启用，切换后自动生效）===
# DB_TYPE=sqlite
"@
    
    Write-Host "   🔐 已生成 MySQL/Redis 随机密码（已保存至 .env）" -ForegroundColor Green
    Write-Host "      MySQL Root: $mysqlRootPass" -ForegroundColor Gray
    Write-Host "      MySQL User: $mysqlUserPass" -ForegroundColor Gray
    Write-Host "      Redis     : $redisPass" -ForegroundColor Gray
}

[IO.File]::WriteAllText("$PWD\.env", $envContent.Trim(), $utf8NoBom)

# ─────────────────────────────────────────────────────
# 4️⃣ 生成 docker-compose.override.yml（根据模式分流）
# ─────────────────────────────────────────────────────
Write-Host "🐳 生成 docker-compose.override.yml (模式: $Mode)..." -ForegroundColor Yellow

if ($Mode -eq "Personal") {
    # 🔹 个人模式：仅 new-api + SQLite
    $overrideContent = @'
services:
  new-api:
    ports:
      - "${HOST_PORT:-9528}:3000"
    environment:
      - TZ=${TZ}
      - SESSION_SECRET=${SESSION_SECRET}
      # SQLite 模式：不设置 SQL_DSN，程序自动使用 /data/new-api.db
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
} else {
    # 🔹 企业模式：new-api + MySQL + Redis
    $overrideContent = @'
services:
  new-api:
    ports:
      - "${HOST_PORT:-9528}:3000"
    environment:
      - TZ=${TZ}
      - SESSION_SECRET=${SESSION_SECRET}
      # MySQL 连接字符串（自动从 .env 读取变量）
      - SQL_DSN=${MYSQL_USER}:${MYSQL_PASSWORD}@tcp(mysql:3306)/${MYSQL_DATABASE}?charset=utf8mb4&parseTime=True&loc=Local
      - REGISTER_ENABLED=${REGISTER_ENABLED}
      - PASSWORD_LOGIN_ENABLED=${PASSWORD_LOGIN_ENABLED}
      - LOG_LEVEL=${LOG_LEVEL}
      - ENABLE_REQUEST_LOGS=${ENABLE_REQUEST_LOGS}
      - ENABLE_RESPONSE_LOGS=${ENABLE_RESPONSE_LOGS}
      - REDIS_CONN_STRING=redis://default:${REDIS_PASSWORD}@redis:6379/0
    volumes:
      - ./logs:/app/logs:rw
    env_file:
      - ./.env
    restart: always
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - new-api-network

  mysql:
    image: mysql:8.0
    container_name: new-api-mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - TZ=${TZ}
    volumes:
      - ./mysql_data:/var/lib/mysql:rw
    command: --default-authentication-plugin=mysql_native_socket
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: always
    networks:
      - new-api-network

  redis:
    image: redis:7-alpine
    container_name: new-api-redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - ./data/redis:/data:rw
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
    restart: always
    networks:
      - new-api-network

networks:
  new-api-network:
    driver: bridge
'@
}

Set-Content -Path "docker-compose.override.yml" -Value $overrideContent -Encoding UTF8NoBOM -Force

# ─────────────────────────────────────────────────────
# 5️⃣ 生成基础 docker-compose.yml（如果不存在）
# ─────────────────────────────────────────────────────
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "📋 生成基础 docker-compose.yml..." -ForegroundColor Yellow
    $baseContent = @'
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

# ─────────────────────────────────────────────────────
# 6️⃣ 配置 .gitignore（保护本地配置）
# ─────────────────────────────────────────────────────
Write-Host "🔐 配置 .gitignore..." -ForegroundColor Yellow
$gitignoreRules = @"

# === New API 本地配置 (NEVER commit) ===
# 初始化/卸载脚本（避免覆盖个人配置）
init.ps1
uninstall.ps1

# 敏感配置与环境变量
.env
docker-compose.override.yml
docker-compose.yml.bak

# 数据持久化目录
data/
logs/
mysql_data/

# 数据库与日志文件
*.db
*.log
*.sqlite
"@

if (-not (Test-Path ".gitignore")) {
    # 首次创建 .gitignore
    Set-Content -Path ".gitignore" -Value "# New API Git Ignore`n$gitignoreRules" -Encoding UTF8NoBOM -Force
    Write-Host "   ✓ 已创建 .gitignore" -ForegroundColor Green
} else {
    # 已存在则智能追加（避免重复）
    $existing = Get-Content -Path ".gitignore" -Raw
    $rulesToAdd = @("init.ps1", "uninstall.ps1", "docker-compose.yml.bak")
    
    foreach ($rule in $rulesToAdd) {
        if ($existing -notmatch [regex]::Escape($rule)) {
            Add-Content -Path ".gitignore" -Value $rule -Encoding UTF8NoBOM
            Write-Host "   ✓ 已添加忽略规则: $rule" -ForegroundColor Green
        }
    }
}

# ─────────────────────────────────────────────────────
# 7️⃣ 输出结果（根据模式显示不同信息）
# ─────────────────────────────────────────────────────
Write-Host " "
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "✅ New API 配置初始化完成！" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " "
Write-Host "🔑 您的 SESSION_SECRET (请妥善保存):" -ForegroundColor Cyan
Write-Host "   $generatedSecret" -ForegroundColor White
Write-Host " "

if ($Mode -eq "Personal") {
    Write-Host "🔹 当前模式: 个人模式 (SQLite)" -ForegroundColor Cyan
    Write-Host "   ✅ 轻量部署，适合个人/小团队使用" -ForegroundColor Gray
    Write-Host "   📦 数据库: SQLite (单文件，自动创建)" -ForegroundColor Gray
} else {
    Write-Host "🔹 当前模式: 企业模式 (MySQL + Redis)" -ForegroundColor Cyan
    Write-Host "   ✅ 高可用部署，适合生产环境/多用户" -ForegroundColor Gray
    Write-Host "   📦 数据库: MySQL 8.0 + Redis 7" -ForegroundColor Gray
    Write-Host "   🔐 MySQL/Redis 密码已随机生成并保存至 .env" -ForegroundColor Gray
}

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
Write-Host "📁 数据持久化目录:" -ForegroundColor Cyan
if ($Mode -eq "Personal") {
    Write-Host "   ./data/          → SQLite 数据库 + 日志" -ForegroundColor Gray
} else {
    Write-Host "   ./data/          → Redis 数据 + 日志" -ForegroundColor Gray
    Write-Host "   ./mysql_data/    → MySQL 数据库文件" -ForegroundColor Gray
}
Write-Host " "
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " "
Write-Host "🚀 下一步：执行以下命令启动服务" -ForegroundColor Cyan
Write-Host "   docker compose up -d" -ForegroundColor White
Write-Host " "
Write-Host "🔄 切换部署模式（部署后可随时切换）:" -ForegroundColor Cyan
Write-Host "   个人→企业: .\init.ps1 -Mode Enterprise -SwitchMode" -ForegroundColor White
Write-Host "   企业→个人: .\init.ps1 -Mode Personal -SwitchMode" -ForegroundColor White
Write-Host "   ⚠️  切换模式会重建数据库，请提前备份 ./data 目录！" -ForegroundColor Yellow
Write-Host " "
Write-Host "🔍 查看日志: docker compose logs -f new-api" -ForegroundColor Gray
Write-Host "🛑 停止服务: docker compose down" -ForegroundColor Gray
Write-Host " "
