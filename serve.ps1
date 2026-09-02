# =============================================================================
#  MCQ Mastery - minimal local file server
#
#  Serves the folder this script sits in, on http://localhost, so the browser
#  will allow IndexedDB (the app's database). Nothing is exposed to the
#  network: it binds to the loopback address only, so no other machine can
#  reach it and Windows Firewall should not prompt.
#
#  No installation, no Node, no Python. Uses only what ships with Windows.
#  Double-click "Start MCQ Mastery.bat" instead of running this directly.
# =============================================================================

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$rootFull = [System.IO.Path]::GetFullPath($root)
if (-not $rootFull.EndsWith('\')) { $rootFull = $rootFull + '\' }

if (-not (Test-Path -LiteralPath (Join-Path $rootFull 'index.html'))) {
    Write-Host ''
    Write-Host '  Could not find index.html next to this script.' -ForegroundColor Red
    Write-Host "  This script is looking in: $rootFull"
    Write-Host '  Move both files into the folder that contains index.html.'
    Write-Host ''
    Read-Host '  Press Enter to close'
    exit 1
}

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.js'   = 'text/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.csv'  = 'text/csv; charset=utf-8'
    '.md'   = 'text/markdown; charset=utf-8'
    '.txt'  = 'text/plain; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.webp' = 'image/webp'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.woff2'= 'font/woff2'
    # The vendored OCR engine, for anyone who has set up local Tesseract.
    # A .wasm served as octet-stream is refused by the browser's streaming
    # compiler, and the language data has to arrive as bytes, not as text.
    '.wasm' = 'application/wasm'
    '.gz'   = 'application/gzip'
    '.traineddata' = 'application/octet-stream'
    '.data' = 'application/octet-stream'
    '.zip'  = 'application/zip'
}

# Find a free port. 8080 first, then upwards, in case something already has it.
$listener = $null
$port = 0
foreach ($p in 8080..8095) {
    try {
        $candidate = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $p)
        $candidate.Start()
        $listener = $candidate
        $port = $p
        break
    } catch {
        # port in use, try the next one
    }
}

if (-not $listener) {
    Write-Host ''
    Write-Host '  Could not open a free port between 8080 and 8095.' -ForegroundColor Red
    Write-Host '  Close whatever is using them and try again.'
    Write-Host ''
    Read-Host '  Press Enter to close'
    exit 1
}

$url = "http://localhost:$port/index.html"

Write-Host ''
Write-Host '  MCQ Mastery' -ForegroundColor Cyan
Write-Host '  ==========='
Write-Host ''
Write-Host "  Running at   $url"
Write-Host "  Serving      $rootFull"
Write-Host ''
Write-Host '  Keep this window open while you use the app.' -ForegroundColor Yellow
Write-Host '  Close it, or press Ctrl+C, when you are finished.'
Write-Host ''

try { Start-Process $url } catch {
    Write-Host "  Could not open the browser automatically. Paste this in yourself: $url"
}

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()

        # Browsers pre-open connections and then sometimes send nothing at all.
        # Without a timeout, one of those would block the loop forever.
        $stream.ReadTimeout = 5000

        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) {
            $client.Close()
            continue
        }

        $parts = $requestLine.Split(' ')
        # The app asks HEAD before running OCR, to find out which of the
        # engine's files are actually in the folder. Answering with a body
        # would work but wastes a multi-megabyte read on every check.
        $method = if ($parts.Length -ge 1) { $parts[0].ToUpperInvariant() } else { 'GET' }
        $target = if ($parts.Length -ge 2) { $parts[1] } else { '/' }
        $target = $target.Split('?')[0]
        $target = [System.Uri]::UnescapeDataString($target)
        if ($target -eq '/' -or $target -eq '') { $target = '/index.html' }

        $rel = $target.TrimStart('/').Replace('/', '\')

        # Resolve, then confirm the result is still inside the served folder.
        $full = $null
        try {
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $rootFull $rel))
            if ($resolved.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -and
                (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                $full = $resolved
            }
        } catch { }

        if ($full) {
            # A HEAD only needs the length, and the language data behind one of
            # these is 15 MB — reading it to answer "is it there?" is waste.
            if ($method -eq 'HEAD') {
                $bytes = [byte[]]@()
                $len = (Get-Item -LiteralPath $full).Length
            } else {
                $bytes = [System.IO.File]::ReadAllBytes($full)
                $len = $bytes.Length
            }
            $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
            $ct = $mime[$ext]
            if (-not $ct) { $ct = 'application/octet-stream' }
            $head = "HTTP/1.1 200 OK`r`n" +
                    "Content-Type: $ct`r`n" +
                    "Content-Length: $len`r`n" +
                    "Cache-Control: no-store`r`n" +
                    "Connection: close`r`n`r`n"
            Write-Host ("  200  " + $target) -ForegroundColor DarkGray
        } else {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 - not found: $target")
            $head = "HTTP/1.1 404 Not Found`r`n" +
                    "Content-Type: text/plain; charset=utf-8`r`n" +
                    "Content-Length: $($bytes.Length)`r`n" +
                    "Connection: close`r`n`r`n"
            Write-Host ("  404  " + $target) -ForegroundColor DarkYellow
        }

        $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
        $stream.Write($headBytes, 0, $headBytes.Length)
        if ($method -ne 'HEAD') { $stream.Write($bytes, 0, $bytes.Length) }
        $stream.Flush()
    } catch {
        # A dropped or timed-out connection must never take the server down.
    } finally {
        if ($client) { try { $client.Close() } catch { } }
    }
}
