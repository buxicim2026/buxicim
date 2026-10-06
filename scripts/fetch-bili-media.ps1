# fetch-bili-media.ps1 —— 抓取各 UP 的头像与节目代表视频的封面图，下载到站点本地
#
# 素材本地化的好处：不依赖 B站 图床的外链策略，页面加载也更快。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/fetch-bili-media.ps1 -ProgramsJson D:\bili-programs.json
#   powershell -ExecutionPolicy Bypass -File scripts/fetch-bili-media.ps1 -Bvids BV1BMhqzhEH5,BV1xZqPBSEDW
#
# 输出：
#   assets/img/avatars/{uid}.webp          各 UP 头像
#   assets/img/covers/{bvid}.webp          节目代表视频封面（16:9）
#   assets/img/covers/index.json           文件名映射，便于维护页面
param(
  [string]$ProgramsJson = '',                       # bili-programs.ps1 的输出（推荐）
  [string[]]$Bvids = @(),                           # 也可以直接给一批 BV 号
  [int[]]$Mids = @(385015308, 11817627, 131365661), # 需要头像的 UID
  [string]$SiteRoot = '',
  [int]$CoverWidth = 640
)

$ErrorActionPreference = 'Stop'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
if (-not $SiteRoot) { $SiteRoot = Split-Path $PSScriptRoot -Parent }
$imgDir = Join-Path $SiteRoot 'assets/img'
$coverDir = Join-Path $imgDir 'covers'
$avatarDir = Join-Path $imgDir 'avatars'
New-Item -ItemType Directory -Force -Path $coverDir, $avatarDir | Out-Null

function Get-Api([string]$url) {
  Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = $ua; 'Referer' = 'https://www.bilibili.com' } -TimeoutSec 25
}

function Save-Image([string]$url, [string]$path, [string]$suffix) {
  if ([string]::IsNullOrWhiteSpace($url)) { return $false }
  if ($url.StartsWith('http://')) { $url = 'https://' + $url.Substring(7) }
  $base = ($url -split '@')[0]
  if ($suffix) { $url = $base + $suffix }
  try {
    Invoke-WebRequest -Uri $url -Headers @{ 'User-Agent' = $ua; 'Referer' = 'https://www.bilibili.com' } `
      -OutFile $path -TimeoutSec 40
    return (Test-Path $path) -and ((Get-Item $path).Length -gt 500)
  } catch {
    Write-Warning "下载失败：$url`n         $($_.Exception.Message)"
    return $false
  }
}

# ---- 收集需要封面的 BV 号 ----
$targets = @()   # @{ bvid=..; name=..; mid=.. }
if ($ProgramsJson) {
  if (-not (Test-Path $ProgramsJson)) { throw "找不到 $ProgramsJson，请先跑 scripts/bili-programs.ps1" }
  $data = Get-Content $ProgramsJson -Raw | ConvertFrom-Json
  foreach ($entry in $data) {
    foreach ($p in ($entry.seasons + $entry.series)) {
      if ($p.videos -and $p.videos.Count -gt 0) {
        $targets += [pscustomobject]@{ bvid = $p.videos[0].bvid; name = $p.name; mid = $entry.mid }
      }
    }
  }
}
foreach ($bv in $Bvids) { $targets += [pscustomobject]@{ bvid = $bv; name = $bv; mid = 0 } }
$targets = $targets | Where-Object { $_.bvid } | Sort-Object bvid -Unique

$coverSuffix = "@${CoverWidth}w_$([int]($CoverWidth * 9 / 16))h_1c.webp"
$index = @()

Write-Host "==> 抓取封面（$($targets.Count) 张）" -ForegroundColor Cyan
foreach ($t in $targets) {
  try {
    $v = Get-Api "https://api.bilibili.com/x/web-interface/view?bvid=$($t.bvid)"
    if ($v.code -ne 0) { Write-Warning "取不到 $($t.bvid)：$($v.message)"; continue }
    $out = Join-Path $coverDir "$($t.bvid).webp"
    if (Save-Image $v.data.pic $out $coverSuffix) {
      Write-Host ("    OK {0}  {1}" -f $t.bvid, $t.name)
      $index += [pscustomobject]@{
        bvid  = $t.bvid
        name  = $t.name
        mid   = $t.mid
        cover = "assets/img/covers/$($t.bvid).webp"
        title = $v.data.title
      }
    }
  } catch {
    Write-Warning "$($t.bvid) 出错：$($_.Exception.Message)"
  }
  Start-Sleep -Milliseconds 250
}

Write-Host "==> 抓取头像（$($Mids.Count) 个）" -ForegroundColor Cyan
foreach ($mid in $Mids) {
  $bv = ($targets | Where-Object { $_.mid -eq $mid } | Select-Object -First 1).bvid
  if (-not $bv) { Write-Warning "UID $mid 没有可用视频，跳过头像"; continue }
  try {
    $v = Get-Api "https://api.bilibili.com/x/web-interface/view?bvid=$bv"
    if ($v.code -ne 0) { continue }
    $out = Join-Path $avatarDir "$mid.webp"
    if (Save-Image $v.data.owner.face $out '@128w_128h_1c.webp') {
      Write-Host ("    OK {0}  {1}" -f $mid, $v.data.owner.name)
    }
  } catch {
    Write-Warning "UID $mid 头像出错：$($_.Exception.Message)"
  }
  Start-Sleep -Milliseconds 250
}

$index | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $coverDir 'index.json') -Encoding UTF8
Write-Host ""
Write-Host "完成。封面目录：$coverDir" -ForegroundColor Green
