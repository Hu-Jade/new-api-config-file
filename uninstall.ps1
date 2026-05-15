# uninstall.ps1 - New API 项目彻底卸载脚本
# ⚠️ 警告：此操作不可逆，将删除所有数据和配置！

param([switch]$KeepData)

Write-Host "🛑 开始卸载 New API 项目..." -ForegroundColor Red

# 确认提示（如果未选择保留数据）
if (-not $KeepData) {
    $confirm = Read-Host "⚠️  这将删除所有配置和数据 (.env, data/, logs/)。确定继续吗？(yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "❌ 操作已取消" -ForegroundColor Yellow
        exit
    }
}

# 1. 停止并删除容器/网络
Write-Host "📦 停止并删除容器..." -ForegroundColor Cyan
docker compose down

# 2. 删除本地持久化数据（如果未选择保留）
if (-not $KeepData) {
    Write-Host "🗑️  删除本地配置和数据..." -ForegroundColor Cyan
    Remove-Item -Path "data", "logs", ".env", "docker-compose.override.yml" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "🗑️  删除基础配置文件 (可选)..." -ForegroundColor Gray
    Remove-Item -Path "docker-compose.yml", ".gitignore" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "💾 已保留数据目录 (data/, logs/) 和配置文件" -ForegroundColor Green
}

# 3. 删除镜像
Write-Host "🖼️  删除 New API 镜像..." -ForegroundColor Cyan
docker rmi ghcr.io/quantumnous/new-api:latest -ErrorAction SilentlyContinue
# 也尝试删除可能的其他标签
docker rmi justsong/new-api:latest -ErrorAction SilentlyContinue

# 4. 清理系统残留
Write-Host "🧹 清理 Docker 系统残留..." -ForegroundColor Cyan
docker system prune -f

# 5. 完成提示
Write-Host " "
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
if ($KeepData) {
    Write-Host "✅ 卸载完成（数据已保留）！" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    Write-Host " "
    Write-Host "📁 你的数据仍在: .\data\" -ForegroundColor Cyan
    Write-Host "🔧 重新部署: 运行 .\init.ps1 后执行 docker compose up -d" -ForegroundColor White
} else {
    Write-Host "✅ 彻底卸载完成！" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    Write-Host " "
    Write-Host "🗑️  所有配置和数据已删除" -ForegroundColor Yellow
}
Write-Host " "