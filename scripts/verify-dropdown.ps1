# 用 Edge 无头模式 + CDP 真实模拟鼠标操作，验证下拉菜单稳定性
$ErrorActionPreference = 'Stop'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$port = [int](9300 + (Get-Random -Maximum 90))
$page = 'http://localhost:4173/plugin.html'
$profile = "d:/AI项目/_edge-cdp-$port"

# 清理上次残留的无头实例（只杀带我们 profile 标记的，绝不动用户正在用的 Edge）
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
  Where-Object { $_.CommandLine -like '*_edge-cdp*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 800

$proc = Start-Process -FilePath $edge -PassThru -ArgumentList @(
  '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  '--remote-allow-origins=*', "--remote-debugging-port=$port",
  '--disable-sync', '--disable-extensions',
  "--user-data-dir=$profile", '--window-size=1280,900', 'about:blank'
)

# 轮询等待调试端口就绪
$targets = $null
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Milliseconds 700
  try {
    $targets = Invoke-RestMethod "http://localhost:$port/json" -TimeoutSec 3
    if ($targets) { break }
  } catch { }
}
if (-not $targets) { throw "Edge 调试端口未就绪（port=$port）" }

$t = $targets | Where-Object { $_.url -eq 'about:blank' } | Select-Object -First 1
if (-not $t) { $t = $targets | Where-Object { $_.type -eq 'page' } | Select-Object -First 1 }
$wsUrl = $t.webSocketDebuggerUrl
Write-Host "初始目标：$($t.url)" -ForegroundColor DarkGray

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync([Uri]$wsUrl, [Threading.CancellationToken]::None).Wait()
Write-Host "WebSocket：$($ws.State)"

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
  $seg = New-Object System.ArraySegment[byte] (,$bytes)
  $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()

  $deadline = (Get-Date).AddSeconds(25)
  while ((Get-Date) -lt $deadline) {
    $txt = Receive-Message
    if (-not $txt) { continue }
    try { $o = $txt | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ($o.id -eq $id) { return $o }
  }
  throw "CDP 超时：$method"
}

# 导航到待测页面
Invoke-Cdp 'Page.enable' $null | Out-Null
Invoke-Cdp 'Page.navigate' @{ url = $page } | Out-Null
Start-Sleep -Seconds 4

$r0 = Invoke-Cdp 'Runtime.evaluate' @{ expression = 'document.title + " | " + location.pathname'; returnByValue = $true }
Write-Host "0) 当前页面 = $($r0.result.result.value)" -ForegroundColor DarkGray

# 等元素就绪
for ($i = 0; $i -lt 12; $i++) {
  $chk = Invoke-Cdp 'Runtime.evaluate' @{ expression = "!!document.querySelector('.dropdown-toggle')"; returnByValue = $true }
  if ($chk.result.result.value -eq $true) { break }
  Start-Sleep -Milliseconds 600
}

$probeExpr = "JSON.stringify((()=>{const t=document.querySelector('.dropdown-toggle');const m=document.querySelector('.dropdown-menu');if(!t||!m)return{err:'missing'};const tr=t.getBoundingClientRect();const s=getComputedStyle(m);const a=m.querySelector('a');const ar=a.getBoundingClientRect();return{toggle:[tr.left+tr.width/2,tr.top+tr.height/2],vis:s.visibility,opacity:s.opacity,link:[ar.left+ar.width/2,ar.top+ar.height/2]}})())"

function Probe([string]$label) {
  $r = Invoke-Cdp 'Runtime.evaluate' @{ expression = $probeExpr; returnByValue = $true }
  $v = $r.result.result.value | ConvertFrom-Json
  Write-Host ("{0}  ->  visibility={1}  opacity={2}" -f $label, $v.vis, $v.opacity)
  return $v
}

$s1 = Probe '1) 初始（未操作）'
if ($s1.err) { throw "页面里找不到下拉菜单元素：$($s1.err)" }

$x = $s1.toggle[0]; $y = $s1.toggle[1]
Invoke-Cdp 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = $x; y = $y; button = 'left'; clickCount = 1 } | Out-Null
Invoke-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = $x; y = $y; button = 'left'; clickCount = 1 } | Out-Null
Start-Sleep -Milliseconds 800
$s2 = Probe '2) 点击箭头后'

$lx = $s2.link[0]; $ly = $s2.link[1]
Invoke-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $lx; y = $ly } | Out-Null
Start-Sleep -Milliseconds 900
$s3 = Probe '3) 指针移到菜单上'

foreach ($dx in @(-30, 30, -20, 20, -12, 12)) {
  Invoke-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = ($lx + $dx); y = $ly } | Out-Null
  Start-Sleep -Milliseconds 150
}
Start-Sleep -Milliseconds 600
$s4 = Probe '4) 在菜单里划动之后'

$shot = Invoke-Cdp 'Page.captureScreenshot' @{ format = 'png' }
[IO.File]::WriteAllBytes('d:/AI项目/dropdown-test.png', [Convert]::FromBase64String($shot.result.data))
Write-Host '5) 截图已保存：d:/AI项目/dropdown-test.png'

$ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).Wait()
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" |
  Where-Object { $_.CommandLine -like '*_edge-cdp*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host '验证结束' -ForegroundColor Green
