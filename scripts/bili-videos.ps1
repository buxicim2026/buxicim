# bili-videos.ps1 —— 批量导出 B站 UP 主的全部投稿（BV 号 + 标题）
#
# 为什么需要它：B站 的「投稿列表」接口对未登录请求会返回 412/352 风控，
#              借浏览器的登录 cookie 就能稳定拿到全量列表。
#
# 用法（任选一种 cookie 来源）：
#   1) 自动读浏览器 cookie（需要先完全退出该浏览器，否则数据库被锁）：
#        powershell -ExecutionPolicy Bypass -File scripts/bili-videos.ps1 -Browser edge
#   2) 用导出的 cookies.txt（推荐，最省事）：
#        用浏览器扩展 "Get cookies.txt LOCALLY" 在 bilibili.com 导出，
#        powershell -ExecutionPolicy Bypass -File scripts/bili-videos.ps1 -CookiesFile D:\cookies.txt
#
# 前置：yt-dlp.exe（单文件，无需 Python）
#   https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe
#
# 若只想拿各节目的代表作（不需要登录），用 scripts/bili-programs.ps1 更简单。
param(
  [int[]]$Mids = @(385015308, 11817627, 131365661),
  [string]$Browser = '',          # edge / chrome / firefox / brave ...
  [string]$CookiesFile = '',      # 导出的 cookies.txt
  [string]$YtDlp = '',            # yt-dlp.exe 路径，留空则自动查找
  [switch]$NoTitle,               # 跳过标题补全（更快）
  [string]$OutFile = 'bili-bvids.json'
)

$ErrorActionPreference = 'Stop'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

# ---- 定位 yt-dlp ----
if (-not $YtDlp) {
  $candidates = @(
    (Join-Path $PSScriptRoot 'yt-dlp.exe'),
    (Join-Path (Split-Path $PSScriptRoot -Parent) 'yt-dlp.exe'),
    'yt-dlp.exe'
  )
  foreach ($c in $candidates) {
    if ($c -eq 'yt-dlp.exe' -or (Test-Path $c)) { $YtDlp = $c; break }
  }
}
try { & $YtDlp --version | Out-Null } catch {
  throw "找不到 yt-dlp.exe。请先下载：https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
}

# ---- cookie 参数 ----
$cookieArgs = @()
if ($CookiesFile) {
  if (-not (Test-Path $CookiesFile)) { throw "cookies 文件不存在：$CookiesFile" }
  $cookieArgs = @('--cookies', $CookiesFile)
  Write-Host "使用 cookies.txt：$CookiesFile" -ForegroundColor DarkGray
} elseif ($Browser) {
  $cookieArgs = @('--cookies-from-browser', $Browser)
  Write-Host "尝试从 $Browser 读取 cookie（需先完全退出该浏览器）" -ForegroundColor DarkGray
} else {
  Write-Warning '未指定 -Browser 或 -CookiesFile，B站 很可能返回 412 风控。'
}

function Get-Title([string]$bvid) {
  try {
    $r = Invoke-RestMethod -Uri "https://api.bilibili.com/x/web-interface/view?bvid=$bvid" `
      -Headers @{ 'User-Agent' = $ua; 'Referer' = 'https://www.bilibili.com' } -TimeoutSec 20
    if ($r.code -eq 0) { return $r.data.title }
  } catch { }
  return ''
}

$all = @()

foreach ($mid in $Mids) {
  Write-Host "==> UID $mid" -ForegroundColor Cyan
  $url = "https://space.bilibili.com/$mid/video"

  $out = & $YtDlp @cookieArgs --flat-playlist --no-warnings --print '%(id)s' $url 2>&1
  $bvs = @($out | Where-Object { $_ -is [string] -and $_ -match '^BV[0-9A-Za-z]{10}$' })

  if (-not $bvs.Count) {
    Write-Warning "没取到 BV 号，yt-dlp 输出：`n$($out | Select-Object -First 5 | Out-String)"
    Write-Warning '提示：412 风控时请完全退出浏览器后重试，或改用 -CookiesFile 方式。'
    continue
  }

  Write-Host ("    共 {0} 条" -f $bvs.Count)
  $i = 0
  foreach ($bv in $bvs) {
    $i++
    $title = ''
    if (-not $NoTitle) {
      $title = Get-Title $bv
      Start-Sleep -Milliseconds 220   # 温和限速
    }
    $all += [pscustomobject]@{ mid = $mid; bvid = $bv; title = $title; url = "https://www.bilibili.com/video/$bv" }
    if ($i % 20 -eq 0) { Write-Host ("    ... 已处理 {0}/{1}" -f $i, $bvs.Count) }
  }
}

$all | ConvertTo-Json -Depth 4 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host ""
Write-Host ("已保存：{0}（共 {1} 条）" -f $OutFile, $all.Count) -ForegroundColor Green
