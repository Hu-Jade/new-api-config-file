# fix-ports.ps1 - 注释 docker-compose.yml 中的硬编码 3000 端口
$filePath = "docker-compose.yml"
$lines = Get-Content $filePath -Encoding UTF8
$modified = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    # 匹配 ports: 行（允许任意空格）
    if ($lines[$i] -match '^\s*ports:\s*(#.*)?$') {
        # 注释 ports: 行
        $lines[$i] = $lines[$i] -replace '^(\s*)ports:', '$1# ports:'
        $modified = $true
        
        # 检查下一行是否是 3000:3000
        if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*-\s*["'']?3000:3000["'']?') {
            # 注释掉端口映射行
            $lines[$i + 1] = $lines[$i + 1] -replace '^(\s*)-', '$1# -'
            $i++  # 跳过已处理的下一行
        }
    }
}

if ($modified) {
    $lines | Set-Content $filePath -Encoding UTF8NoBOM
    Write-Host "✅ 已成功注释 3000:3000 端口配置" -ForegroundColor Green
} else {
    Write-Host "⚠️  未找到需要注释的端口配置" -ForegroundColor Yellow
}