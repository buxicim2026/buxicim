# cookie-to-netscape.ps1 —— 把浏览器里复制出来的 Cookie 请求头，转成 yt-dlp 能用的 cookies.txt
#
# 为什么需要：新版 Edge / Chrome（127+）对 cookie 启用了 App-Bound 加密，
#            yt-dlp 直接读浏览器会报 "Failed to decrypt with DPAPI"。
#            手动把 Cookie 头转成 cookies.txt 是最稳的办法。
#
# 从浏览器拿 Cookie 的方法（Edge / Chrome 通用）：
#   1. 登录 bilibili.com，按 F12 打开开发者工具
#   2. 切到「网络 / Network」标签，按 F5 刷新页面
#   3. 在请求列表里点任意一条 api.bilibili.com 的请求
#   4. 右侧「标头 / Headers」→ Request Headers → 找到 Cookie: 这一行
#   5. 复制冒号后面整串（形如 SESSDATA=xxx; bili_jct=yyy; ...），存成 txt 文件
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/cookie-to-netscape.ps1 -CookieFile D:\cookie_raw.txt -OutFile D:\cookies.txt
#   powershell -ExecutionPolicy Bypass -File scripts/cookie-to-netscape.ps1 -CookieString "SESSDATA=xxx; bili_jct=yyy" -OutFile D:\cookies.txt
#
# 注意：cookies.txt 等同于登录凭据，请勿提交到仓库或分享给他人；用完后建议在 B站 退出登录使其失效。
param(
  [string]$CookieFile = '',
  [string]$CookieString = '',
  [string]$OutFile = 'cookies.txt'
)

$ErrorActionPreference = 'Stop'

if ($CookieFile) {
  if (-not (Test-Path $CookieFile)) { throw "找不到文件：$CookieFile" }
  $CookieString = Get-Content $CookieFile -Raw
}
if (-not $CookieString) { throw '请用 -CookieFile 或 -CookieString 提供 Cookie 内容。' }

# 已经是 Netscape 格式就原样复制
if ($CookieString -match '(?m)^\s*\.?bilibili\.com\s') {
  Set-Content -Path $OutFile -Value $CookieString -Encoding UTF8
  Write-Host "看起来已经是 Netscape 格式，已直接写出：$OutFile" -ForegroundColor Green
  return
}

$pairs = $CookieString -split '[;\r\n]+' |
  ForEach-Object { $_.Trim() } |
  Where-Object { $_ -match '^[^=]+=' }

$lines = @('# Netscape HTTP Cookie File', '# 由 cookies-to-netscape 生成，仅本地使用')
$count = 0
foreach ($p in $pairs) {
  $i = $p.IndexOf('=')
  $name = $p.Substring(0, $i).Trim()
  $value = $p.Substring($i + 1).Trim()
  if (-not $name) { continue }
  $lines += ".bilibili.com`tTRUE`t/`tFALSE`t0`t$name`t$value"
  $count++
}

Set-Content -Path $OutFile -Value $lines -Encoding UTF8
Write-Host "已写出 $count 条 cookie → $OutFile" -ForegroundColor Green
Write-Host "接下来可执行：" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts/bili-videos.ps1 -CookiesFile $OutFile -OutFile bili-bvids.json"
