# verify-dropdown.ps1 —— 用 Edge 无头模式 + CDP 真实复现下拉菜单交互
#
# 验证内容：
#   1. 鼠标悬停到按钮上，菜单是否展开（CSS :hover）
#   2. 鼠标移到菜单项上、在菜单里划动时，菜单是否保持
#   3. 用 elementFromPoint 检查「鼠标坐标是否真的落在链接上」——
#      这是判断“看得到却点不到”的关键指标（命中区域错位）
#
# 用法：
#   1) 先起本地预览服务器：powershell -File scripts/serve.ps1
#   2) powershell -ExecutionPolicy Bypass -File scripts/verify-dropdown.ps1
param(
  [string]$PageUrl = 'http://localhost:4173/plugin.html',
  [string]$EdgePath = ''
)

$ErrorActionPreference = 'Stop'
if (-not $EdgePath) {
  foreach ($c in @(
      "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
      "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
      "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe")) {
    if (Test-Path $c) { $EdgePath = $c; break }
  }
}
if (-not $EdgePath) { throw '找不到 msedge.exe，请用 -EdgePath 指定' }

$port = [int](9300 + (Get-Random -Maximum 90))
$profile = Join-Path $env:TEMP "edge-cdp-dropdown-$port"

Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
  Where-Object { $_.CommandLine -like '*edge-cdp-dropdown*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 800

$proc = Start-Process -FilePath $EdgePath -PassThru -ArgumentList @(
  '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  '--remote-allow-origins=*', "--remote-debugging-port=$port",
  '--disable-sync', '--disable-extensions',
  "--user-data-dir=$profile", '--window-size=1280,900', 'about:blank'
)

$targets = $null
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Milliseconds 700
  try { $targets = Invoke-RestMethod "http://localhost:$port/json" -TimeoutSec 3; if ($targets) { break } } catch { }
}
if (-not $targets) { throw "Edge 调试端口未就绪（port=$port）" }

$t = $targets | Where-Object { $_.url -eq 'about:blank' } | Select-Object -First 1
if (-not $t) { $t = $targets | Where-Object { $_.type -eq 'page' } | Select-Object -First 1 }

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$t.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait()
$script:msgId = 0

function Receive-Message {
  $ms = New-Object System.IO.MemoryStream
  $buf = New-Object byte[] 65536
  do {
    $seg = New-Object System.ArraySegment[byte] (,$buf)
    $res = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).Result
    if ($res.Count -gt 0) { $ms.Write($buf, 0, $res.Count) }
  } while (-not $res.EndOfMessage)
  $bytes = $ms.ToArray(); $ms.Dispose()
  return [Text.Encoding]::UTF8.GetString($bytes)
}

function Invoke-Cdp([string]$method, $params) {
  $script:msgId++
  $id = $script:msgId
  $obj = @{ id = $id; method = $method }
  if ($params) { $obj.params = $params }
  $json = $obj | ConvertTo-Json -Depth 10 -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $ws.SendAsync((New-Object System.ArraySegment[byte] (,$bytes)), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
  $deadline = (Get-Date).AddSeconds(25)
  while ((Get-Date) -lt $deadline) {
    $txt = Receive-Message
    if (-not $txt) { continue }
    try { $o = $txt | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ($o.id -eq $id) { return $o }
  }
  throw "CDP 超时：$method"
}

function Eval([string]$expr) {
  $r = Invoke-Cdp 'Runtime.evaluate' @{ expression = $expr; returnByValue = $true }
  return $r.result.result.value
}

function Send-MouseMove([double]$x, [double]$y) {
  Invoke-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $x; y = $y } | Out-Null
}

$stateExpr = @'
JSON.stringify((()=>{
  const m=document.querySelector('.dropdown-menu');
  const s=getComputedStyle(m);
  const links=[...m.querySelectorAll('a')].map(a=>{
    const r=a.getBoundingClientRect();
    const cx=r.left+r.width/2, cy=r.top+r.height/2;
    const el=document.elementFromPoint(cx,cy);
    let desc='null';
    if(el){
      let cls='';
      try{ cls=(''+el.className).split(' ')[0]; }catch(e){}
      desc=el.tagName.toLowerCase()+(cls?('.'+cls):'')+' > '+(el.closest('a')?'A':'noA');
    }
    return {text:a.textContent.trim().replace(/\s+/g,' ').slice(0,10),
            href:(a.getAttribute('href')||'').slice(0,46),
            inside: !!(el && a.contains(el)),
            hit: desc,
            rect:[Math.round(r.left),Math.round(r.top),Math.round(r.width),Math.round(r.height)],
            cx:Math.round(cx), cy:Math.round(cy)};
  });
  const t=document.querySelector('.dropdown-toggle').getBoundingClientRect();
  return {vis:s.visibility, opacity:s.opacity,
          toggle:[Math.round(t.left+t.width/2), Math.round(t.top+t.height/2)], links:links};
})())
'@

Invoke-Cdp 'Page.enable' $null | Out-Null
Invoke-Cdp 'Page.navigate' @{ url = $PageUrl } | Out-Null
Start-Sleep -Seconds 4
for ($i = 0; $i -lt 12; $i++) {
  if ((Eval "!!document.querySelector('.dropdown-menu')") -eq $true) { break }
  Start-Sleep -Milliseconds 600
}

# 把下拉按钮滚到视口中间：否则鼠标坐标落到视口外，测不到
Invoke-Cdp 'Runtime.evaluate' @{ expression = "document.querySelector('.dropdown').scrollIntoView({block:'center'}); 'ok'" } | Out-Null
Start-Sleep -Seconds 2

$s1 = (Eval $stateExpr) | ConvertFrom-Json
Write-Host ("1) 初始（鼠标不在按钮上）    菜单 visibility={0}" -f $s1.vis)

# 悬停到按钮（不点击）
Send-MouseMove $s1.toggle[0] $s1.toggle[1]
Start-Sleep -Milliseconds 900
$s2 = (Eval $stateExpr) | ConvertFrom-Json
Write-Host ("2) 鼠标悬停在按钮上          菜单 visibility={0}" -f $s2.vis)

# 关键：趁菜单还可见，先记录各菜单项的「几何位置」与「谁挡在上面」
Write-Host ''
Write-Host '菜单可见时的命中检查：' -ForegroundColor Cyan
foreach ($l in $s2.links) {
  $flag = if ($l.inside) { 'OK  ' } else { 'FAIL' }
  Write-Host ("   [{0}] {1,-12} rect={2}  命中元素={3}" -f $flag, $l.text, ($l.rect -join ','), $l.hit)
}
Write-Host ''

# 诊断：从菜单往上找，看哪一层会影响层叠顺序
$stackExpr = @'
JSON.stringify((()=>{
  const out=[];
  let el=document.querySelector('.dropdown-menu');
  while(el && out.length<9){
    const cs=getComputedStyle(el);
    out.push({
      el: el.tagName.toLowerCase()+(el.id?('#'+el.id):'')+((''+ (el.className||'')).split(' ')[0]?('.'+(''+(el.className||'')).split(' ')[0]):''),
      position: cs.position,
      zIndex: cs.zIndex,
      opacity: cs.opacity,
      transform: cs.transform==='none'?'none':'SET',
      filter: cs.filter==='none'?'none':'SET',
      backdropFilter: (cs.backdropFilter||cs.webkitBackdropFilter||'none')==='none'?'none':'SET',
      isolation: cs.isolation,
      contain: cs.contain,
      willChange: cs.willChange,
      overflow: cs.overflow
    });
    el=el.parentElement;
  }
  return out;
})())
'@
Write-Host '层叠诊断（从菜单元素往上的祖先链）：' -ForegroundColor Cyan
$chain = (Eval $stackExpr) | ConvertFrom-Json
foreach ($n in $chain) {
  $marks = @()
  if ($n.transform -ne 'none') { $marks += 'transform' }
  if ($n.filter -ne 'none') { $marks += 'filter' }
  if ($n.backdropFilter -ne 'none') { $marks += 'backdrop-filter' }
  if ($n.opacity -ne '1') { $marks += "opacity=$($n.opacity)" }
  if ($n.isolation -eq 'isolate') { $marks += 'isolation' }
  if ($n.contain -ne 'none') { $marks += "contain=$($n.contain)" }
  if ($n.willChange -ne 'auto') { $marks += "will-change=$($n.willChange)" }
  $note = if ($marks.Count) { '  <-- 会创建层叠上下文: ' + ($marks -join ', ') } else { '' }
  Write-Host ("   {0,-28} position={1,-8} z={2,-6}{3}" -f $n.el, $n.position, $n.zIndex, $note)
}
Write-Host ''

# 移到「快速下载」那一项
$link = $s2.links[1]
Send-MouseMove $link.cx $link.cy
Start-Sleep -Milliseconds 900
$s3 = (Eval $stateExpr) | ConvertFrom-Json
Write-Host ("3) 鼠标移到「{0}」           菜单 visibility={1}" -f $link.text, $s3.vis)

Write-Host ''
Write-Host '命中检查（elementFromPoint 是否真的落在链接上）:' -ForegroundColor Cyan
foreach ($l in $s3.links) {
  $flag = if ($l.inside) { 'OK  ' } else { 'FAIL' }
  Write-Host ("   [{0}] {1,-14} href={2}" -f $flag, $l.text, $l.href)
}

# 在菜单里划动
foreach ($dx in @(-30, 30, -20, 20, -12, 12)) {
  Send-MouseMove ($link.cx + $dx) $link.cy
  Start-Sleep -Milliseconds 140
}
Start-Sleep -Milliseconds 600
$s4 = (Eval $stateExpr) | ConvertFrom-Json
Write-Host ("4) 在菜单里划动之后          菜单 visibility={0}" -f $s4.vis)

$shot = Invoke-Cdp 'Page.captureScreenshot' @{ format = 'png' }
$png = Join-Path $env:TEMP 'dropdown-test.png'
[IO.File]::WriteAllBytes($png, [Convert]::FromBase64String($shot.result.data))
Write-Host "5) 截图：$png"

$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).Wait()
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
  Where-Object { $_.CommandLine -like '*edge-cdp-dropdown*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '验证结束' -ForegroundColor Green
