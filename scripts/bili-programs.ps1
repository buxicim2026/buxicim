# bili-programs.ps1 —— 抓取 B站 UP 主的合集 / 系列，以及其中的视频（BV 号 + 标题 + 播放量）
#
# 用途：给「原创节目」栏目提供真实节目名与视频清单，不必手工逐条复制 BV 号。
#      合集/系列接口不受投稿列表那套 412 风控影响，且能拿到「全部集数」。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/bili-programs.ps1                      # 每个节目取最新 3 条
#   powershell -ExecutionPolicy Bypass -File scripts/bili-programs.ps1 -All                 # 每个节目取全部集数
#   powershell -ExecutionPolicy Bypass -File scripts/bili-programs.ps1 -All -Mids 385015308 -OutFile out.json
#
# 说明：只用 Windows 自带 PowerShell，不依赖 Node / Python。
param(
  [int[]]$Mids = @(385015308, 11817627, 131365661),
  [int]$TopPerSeason = 3,
  [switch]$All,                    # 抓全部集数（自动分页）
  [int]$PageSize = 100,
  [string]$OutFile = 'bili-programs.json'
)

$ErrorActionPreference = 'Stop'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
if ($All) { $TopPerSeason = [int]::MaxValue }

function Get-Api([string]$url, [string]$referer) {
  Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = $ua; 'Referer' = $referer } -WebSession $session -TimeoutSec 25
}

$epoch = [datetime]'1970-01-01T00:00:00Z'

function Convert-Archives($archives) {
  $out = @()
  foreach ($a in $archives) {
    $out += [ordered]@{
      bvid  = $a.bvid
      title = $a.title
      date  = $epoch.AddSeconds([double]$a.pubdate).ToLocalTime().ToString('yyyy-MM-dd')
      views = $a.stat.view
    }
  }
  return $out
}

# 合集：按页抓，直到取够 total
function Get-SeasonVideos([int]$mid, [long]$sid, [int]$total, [string]$ref) {
  $all = @()
  $pn = 1
  while ($pn -le 30) {
    $want = [Math]::Min($PageSize, $TopPerSeason - $all.Count)
    if ($want -le 0) { break }
    $url = "https://api.bilibili.com/x/polymer/web-space/seasons_archives_list?mid=$mid&season_id=$sid&page_num=$pn&page_size=$want&sort_reverse=false"
    $d = Get-Api $url $ref
    if ($d.code -ne 0) { Write-Warning "合集 $sid 第 $pn 页失败：$($d.message)"; break }
    if (-not $d.data.archives -or $d.data.archives.Count -eq 0) { break }
    $all += $d.data.archives
    if ($all.Count -ge $total -or $d.data.archives.Count -lt $want) { break }
    $pn++
    Start-Sleep -Milliseconds 400
  }
  return $all
}

# 系列：按页抓
function Get-SeriesVideos([int]$mid, [long]$rid, [int]$total, [string]$ref) {
  $all = @()
  $pn = 1
  while ($pn -le 30) {
    $want = [Math]::Min($PageSize, $TopPerSeason - $all.Count)
    if ($want -le 0) { break }
    $url = "https://api.bilibili.com/x/series/archives?mid=$mid&series_id=$rid&only_normal=true&sort=desc&pn=$pn&ps=$want"
    $d = Get-Api $url $ref
    if ($d.code -ne 0) { Write-Warning "系列 $rid 第 $pn 页失败：$($d.message)"; break }
    if (-not $d.data.archives -or $d.data.archives.Count -eq 0) { break }
    $all += $d.data.archives
    if ($all.Count -ge $total -or $d.data.archives.Count -lt $want) { break }
    $pn++
    Start-Sleep -Milliseconds 400
  }
  return $all
}

$result = @()

foreach ($mid in $Mids) {
  $ref = "https://space.bilibili.com/$mid"
  Write-Host "==> UID $mid" -ForegroundColor Cyan

  $list = Get-Api "https://api.bilibili.com/x/polymer/web-space/seasons_series_list?mid=$mid&page_num=1&page_size=20&web_location=333.1387" $ref
  if ($list.code -ne 0) {
    Write-Warning "UID $mid 合集列表失败：code=$($list.code) $($list.message)"
    continue
  }

  $entry = [ordered]@{ mid = $mid; seasons = @(); series = @() }

  foreach ($s in $list.data.items_lists.seasons_list) {
    $arch = Get-SeasonVideos $mid $s.meta.season_id $s.meta.total $ref
    $vids = Convert-Archives $arch
    $entry.seasons += [ordered]@{ id = $s.meta.season_id; name = $s.meta.name; total = $s.meta.total; videos = $vids }
    Write-Host ("  合集 {0}（共 {1} 集，取到 {2}）" -f $s.meta.name, $s.meta.total, $vids.Count)
    Start-Sleep -Milliseconds 400
  }

  foreach ($s in $list.data.items_lists.series_list) {
    $arch = Get-SeriesVideos $mid $s.meta.series_id $s.meta.total $ref
    $vids = Convert-Archives $arch
    $entry.series += [ordered]@{ id = $s.meta.series_id; name = $s.meta.name; total = $s.meta.total; videos = $vids }
    Write-Host ("  系列 {0}（共 {1} 集，取到 {2}）" -f $s.meta.name, $s.meta.total, $vids.Count)
    Start-Sleep -Milliseconds 400
  }

  $result += $entry
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host ""
Write-Host "已保存：$OutFile" -ForegroundColor Green
