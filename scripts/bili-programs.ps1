# bili-programs.ps1 —— 抓取 B站 UP 主的合集 / 系列，以及每个合集的最新若干条视频（BV 号 + 标题）
#
# 用途：给「原创节目」栏目提供真实节目名与代表视频，不必手工逐条复制 BV 号。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/bili-programs.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/bili-programs.ps1 -Mids 385015308 -TopPerSeason 5 -OutFile out.json
#
# 说明：走 B站 空间页用的 polymer 接口（不需要 WBI 签名，风控比投稿列表松），
#      只用 Windows 自带 PowerShell，不依赖 Node / Python。
param(
  [int[]]$Mids = @(385015308, 11817627, 131365661),
  [int]$TopPerSeason = 3,
  [string]$OutFile = 'bili-programs.json'
)

$ErrorActionPreference = 'Stop'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

function Get-Api([string]$url, [string]$referer) {
  Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = $ua; 'Referer' = $referer } -WebSession $session -TimeoutSec 25
}

$epoch = [datetime]'1970-01-01T00:00:00Z'
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
    $sid = $s.meta.season_id
    $url = "https://api.bilibili.com/x/polymer/web-space/seasons_archives_list?mid=$mid&season_id=$sid&page_num=1&page_size=$TopPerSeason&sort_reverse=false"
    $d = Get-Api $url $ref
    $vids = @()
    if ($d.code -eq 0) {
      foreach ($a in $d.data.archives) {
        $vids += [ordered]@{
          bvid  = $a.bvid
          title = $a.title
          date  = $epoch.AddSeconds([double]$a.pubdate).ToLocalTime().ToString('yyyy-MM-dd')
          views = $a.stat.view
        }
      }
    }
    $entry.seasons += [ordered]@{ id = $sid; name = $s.meta.name; total = $s.meta.total; videos = $vids }
    Write-Host ("  合集 {0}（共 {1} 集）" -f $s.meta.name, $s.meta.total)
    Start-Sleep -Milliseconds 500
  }

  foreach ($s in $list.data.items_lists.series_list) {
    $rid = $s.meta.series_id
    $url = "https://api.bilibili.com/x/series/archives?mid=$mid&series_id=$rid&only_normal=true&sort=desc&pn=1&ps=$TopPerSeason"
    $d = Get-Api $url $ref
    $vids = @()
    if ($d.code -eq 0) {
      foreach ($a in $d.data.archives) {
        $vids += [ordered]@{
          bvid  = $a.bvid
          title = $a.title
          date  = $epoch.AddSeconds([double]$a.pubdate).ToLocalTime().ToString('yyyy-MM-dd')
          views = $a.stat.view
        }
      }
    }
    $entry.series += [ordered]@{ id = $rid; name = $s.meta.name; total = $s.meta.total; videos = $vids }
    Write-Host ("  系列 {0}（共 {1} 集）" -f $s.meta.name, $s.meta.total)
    Start-Sleep -Milliseconds 500
  }

  $result += $entry
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host ""
Write-Host "已保存：$OutFile" -ForegroundColor Green
