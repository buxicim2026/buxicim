# bili-videos.ps1 —— 汇总某个 UP 主的全部投稿（BV 号 + 标题 + 发布日期 + 播放量）
#
# 背景：B站 的「投稿列表」接口对非登录请求返回 412 风控，且新版 Edge/Chrome 的 cookie
#      用 App-Bound 加密，yt-dlp 读不了。所以采用「浏览器自己取 + 接口补信息」的组合：
#
#   第 1 步（浏览器，不用登录）：打开 space.bilibili.com/<uid>/video，
#           F12 → 控制台粘贴下面这段单行脚本，会把 BV 号存成 bvids-<uid>.txt：
#           (async()=>{const s=new Set();for(let i=0;i<50;i++){const m=document.documentElement.innerHTML.match(/BV[0-9A-Za-z]{10}/g)||[];m.forEach(x=>s.add(x));window.scrollTo(0,document.body.scrollHeight);await new Promise(r=>setTimeout(r,1200))}const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([[...s].join('\n')],{type:'text/plain'}));a.download='bvids.txt';a.click();console.log('共'+s.size+'条')})()
#
#   第 2 步（可选，更全）：跑 scripts/bili-programs.ps1 -All，拿到各合集/系列的全部集数
#
#   第 3 步（本脚本）：把上面的结果合并，用 view 接口补标题，输出完整清单
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/bili-videos.ps1 -BvFiles D:\bvids-385015308.txt -ProgramsJson D:\bili-all.json -OutFile bili-videos.json
param(
  [string[]]$BvFiles = @(),                 # 浏览器导出的 BV 列表 txt（可多个）
  [string]$ProgramsJson = '',               # bili-programs.ps1 -All 的输出，用来带上节目归属
  [string]$OutFile = 'bili-videos.json',
  [string]$CsvFile = '',
  [switch]$NoTitle                          # 已有标题时不重复请求
)

$ErrorActionPreference = 'Stop'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$epoch = [datetime]'1970-01-01T00:00:00Z'
$rows = @()

# ---- 来源一：合集/系列（带节目归属与标题） ----
if ($ProgramsJson) {
  if (-not (Test-Path $ProgramsJson)) { throw "找不到 $ProgramsJson" }
  $data = Get-Content $ProgramsJson -Raw | ConvertFrom-Json
  foreach ($entry in $data) {
    foreach ($p in ($entry.seasons + $entry.series)) {
      foreach ($v in $p.videos) {
        $rows += [pscustomobject]@{
          mid = $entry.mid; program = $p.name; bvid = $v.bvid
          title = $v.title; date = $v.date; views = $v.views
        }
      }
    }
  }
  Write-Host "从合集/系列读入 $($rows.Count) 条" -ForegroundColor DarkGray
}

# ---- 来源二：浏览器导出的投稿列表 ----
$fromFiles = @()
foreach ($f in $BvFiles) {
  if (-not (Test-Path $f)) { Write-Warning "跳过不存在的文件：$f"; continue }
  $fromFiles += (Get-Content $f -Encoding UTF8 | Where-Object { $_ -match '^BV[0-9A-Za-z]{10}$' })
  Write-Host "从 $f 读入 $((Get-Content $f -Encoding UTF8 | Where-Object { $_ -match '^BV[0-9A-Za-z]{10}$' }).Count) 条" -ForegroundColor DarkGray
}
$fromFiles = $fromFiles | Sort-Object -Unique

# 已知 BV（合集里已带的）就不用再查了
$known = @{}
foreach ($r in $rows) { $known[$r.bvid] = $true }
$todo = @($fromFiles | Where-Object { -not $known[$_] })

Write-Host "==> 需要补标题的 BV：$($todo.Count) 条" -ForegroundColor Cyan
$headers = @{ 'User-Agent' = $ua; 'Referer' = 'https://www.bilibili.com' }
$i = 0
foreach ($bv in $todo) {
  $i++
  try {
    $v = Invoke-RestMethod -Uri "https://api.bilibili.com/x/web-interface/view?bvid=$bv" -Headers $headers -TimeoutSec 25
    if ($v.code -eq 0) {
      $rows += [pscustomobject]@{
        mid = $v.data.owner.mid; program = '（未归入合集）'; bvid = $bv
        title = $v.data.title
        date = $epoch.AddSeconds([double]$v.data.pubdate).ToLocalTime().ToString('yyyy-MM-dd')
        views = $v.data.stat.view
      }
    } else {
      Write-Warning "$bv 取不到信息：$($v.message)"
    }
  } catch {
    Write-Warning "$bv 请求失败：$($_.Exception.Message)"
  }
  if ($i % 25 -eq 0) { Write-Host "    ... $i/$($todo.Count)" }
  Start-Sleep -Milliseconds 250
}

# ---- 输出 ----
$final = @($rows | Sort-Object bvid -Unique | Sort-Object mid, date -Descending)
[IO.File]::WriteAllText($OutFile, ($final | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
if ($CsvFile) { $final | Export-Csv $CsvFile -NoTypeInformation -Encoding UTF8 }

Write-Host ""
Write-Host "已保存：$OutFile（共 $($final.Count) 条）" -ForegroundColor Green
foreach ($g in ($final | Group-Object mid)) {
  Write-Host ("    UID {0}：{1} 条" -f $g.Name, $g.Count)
}
