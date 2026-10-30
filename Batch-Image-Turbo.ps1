# Batch-Image-Turbo.ps1 - v2.0 (Pure CPU Edition)
# Ridimensiona immagini in parallelo (solo CPU) verso 1080p.
# Approccio pragmatico: niente CUDA, solo velocità pura e affidabilità.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:ffmpegPath = Join-Path $script:workDir "ffmpeg.exe"
$script:ffprobePath = Join-Path $script:workDir "ffprobe.exe"
$script:logFile = $null
$script:isWorking = $false
$script:queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:current = 0
$script:total = 0
$script:job = $null

# ============================================
# AUTO-FFMPEG
# ============================================
function Initialize-FFmpeg {
    if ((Test-Path $script:ffmpegPath) -and (Test-Path $script:ffprobePath)) { return $true }
    
    try {
        $sysPath = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
        if ($sysPath) { 
            $script:ffmpegPath = $sysPath
            $script:ffprobePath = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source
            return $true 
        }
    } catch {}

    $resp = [System.Windows.Forms.MessageBox]::Show("FFmpeg non trovato. Vuoi scaricarlo automaticamente?", "FFmpeg Missing", [System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($resp -eq "No") { return $false }

    $zipPath = Join-Path $env:TEMP "ffmpeg_dl.zip"
    $extractPath = Join-Path $env:TEMP "ffmpeg_temp"
    $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

    try {
        Write-Host "Download FFmpeg in corso..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Get-ChildItem -Path $extractPath -Include "ffmpeg.exe", "ffprobe.exe" -Recurse | ForEach-Object {
            Move-Item $_.FullName $script:workDir -Force
        }
        Remove-Item $zipPath -Force
        Remove-Item $extractPath -Recurse -Force
        return $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Errore download: $($_.Exception.Message)", "Errore")
        return $false
    }
}

# ============================================
# LOGGING
# ============================================
function Start-Log {
    param([string]$Folder)
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $Folder "ImgTurbo_$ts.log"
    "--- BATCH IMAGE TURBO LOG ---`r`n" | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    
    if ($txtLog) {
        $txtLog.AppendText("$line`r`n")
        $txtLog.SelectionStart = $txtLog.TextLength
        $txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($script:logFile) {
        [System.IO.File]::AppendAllText($script:logFile, "$line`r`n")
    }
}

# ============================================
# GUI MATRIX (semplificata)
# ============================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "BATCH IMAGE DOWNSIZER - MATRIX CORE"
$form.Size = New-Object System.Drawing.Size(600, 550)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::Black
$form.ForeColor = [System.Drawing.Color]::Lime
$form.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "IMAGE DOWNSIZER TO 1080P"
$lblTitle.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.Size = New-Object System.Drawing.Size(540, 30)
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Riporta a 1080p le immagini esportate ad alta risoluzione (es. da Topaz Photo AI)."
$lblSub.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Italic)
$lblSub.ForeColor = [System.Drawing.Color]::Gray
$lblSub.TextAlign = "MiddleCenter"
$lblSub.Location = New-Object System.Drawing.Point(20, 40)
$lblSub.Size = New-Object System.Drawing.Size(540, 20)
$form.Controls.Add($lblSub)

function New-MatrixLabel($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.AutoSize = $true; $l.ForeColor = [System.Drawing.Color]::Lime
    $form.Controls.Add($l)
    return $l
}
function New-MatrixTextBox($x, $y, $w) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 25)
    $t.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
    $t.ForeColor = [System.Drawing.Color]::Lime
    $t.BorderStyle = "FixedSingle"
    $form.Controls.Add($t)
    return $t
}

# Cartelle
New-MatrixLabel "Sorgente:" 20 80 | Out-Null
$txtIn = New-MatrixTextBox 20 100 410
$btnIn = New-Object System.Windows.Forms.Button
$btnIn.Text = "Sfoglia"; $btnIn.Location = New-Object System.Drawing.Point(440, 98)
$btnIn.Size = New-Object System.Drawing.Size(120, 25)
$btnIn.FlatStyle = "Flat"; $btnIn.FlatAppearance.BorderColor = "Lime"; $btnIn.BackColor = "Black"; $btnIn.ForeColor = "Lime"
$form.Controls.Add($btnIn)

New-MatrixLabel "Destinazione:" 20 140 | Out-Null
$txtOut = New-MatrixTextBox 20 160 410
$btnOut = New-Object System.Windows.Forms.Button
$btnOut.Text = "Sfoglia"; $btnOut.Location = New-Object System.Drawing.Point(440, 158)
$btnOut.Size = New-Object System.Drawing.Size(120, 25)
$btnOut.FlatStyle = "Flat"; $btnOut.FlatAppearance.BorderColor = "Lime"; $btnOut.BackColor = "Black"; $btnOut.ForeColor = "Lime"
$form.Controls.Add($btnOut)

# Status & Progress
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto."
$lblStatus.Location = New-Object System.Drawing.Point(20, 210)
$lblStatus.Size = New-Object System.Drawing.Size(540, 20)
$lblStatus.ForeColor = [System.Drawing.Color]::Yellow
$form.Controls.Add($lblStatus)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 235)
$progress.Size = New-Object System.Drawing.Size(540, 20)
$form.Controls.Add($progress)

# Log
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.ReadOnly = $true
$txtLog.Location = New-Object System.Drawing.Point(20, 270)
$txtLog.Size = New-Object System.Drawing.Size(540, 160)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
$txtLog.ForeColor = [System.Drawing.Color]::Lime
$txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($txtLog)

# Pulsanti
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = ">> AVVIA TURBO <<"
$btnStart.Location = New-Object System.Drawing.Point(20, 450)
$btnStart.Size = New-Object System.Drawing.Size(300, 45)
$btnStart.FlatStyle = "Flat"; $btnStart.FlatAppearance.BorderColor = "Lime"; $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 40, 0); $btnStart.ForeColor = "Lime"
$btnStart.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "TERMINATE"
$btnCancel.Location = New-Object System.Drawing.Point(340, 450)
$btnCancel.Size = New-Object System.Drawing.Size(220, 45)
$btnCancel.FlatStyle = "Flat"; $btnCancel.FlatAppearance.BorderColor = "Red"; $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(40, 0, 0); $btnCancel.ForeColor = "Red"
$btnCancel.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$btnCancel.Visible = $false
$form.Controls.Add($btnCancel)

# ============================================
# TIMER PER GUI
# ============================================
$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 200
$script:timer.Add_Tick({
    $msg = $null
    while ($script:queue.TryDequeue([ref]$msg)) {
        if ($msg -ne $null) {
            $script:current++
            $progress.Value = $script:current
            $lblStatus.Text = "Elaborazione $($script:current) di $($script:total)"
            
            if ($msg -match "^OK:") { Write-Log $msg "OK" }
            elseif ($msg -match "^SKIP:") { Write-Log $msg "WARN" }
            else { Write-Log $msg "ERROR" }
        }
    }
    
    if ($script:job -and $script:job.State -ne "Running" -and $script:queue.IsEmpty) {
        $script:timer.Stop()
        $script:isWorking = $false
        $btnStart.Enabled = $true
        $btnCancel.Visible = $false
        $lblStatus.Text = "Operazione conclusa."
        [System.Windows.Forms.MessageBox]::Show("TURBO completato!", "Fatto")
    }
})

# ============================================
# EVENTI
# ============================================
$btnIn.Add_Click({ 
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if($f.ShowDialog() -eq "OK"){ $txtIn.Text = $f.SelectedPath }
})

$btnOut.Add_Click({ 
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if($f.ShowDialog() -eq "OK"){ $txtOut.Text = $f.SelectedPath }
})

$btnCancel.Add_Click({
    $script:isWorking = $false
    if ($script:job) { Stop-Job $script:job }
    Write-Log "Richiesta annullamento. I processi in corso verranno fermati." "WARNING"
    $lblStatus.Text = "Annullamento in corso..."
    $btnCancel.Enabled = $false
})

$btnStart.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtIn.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona una cartella sorgente!", "Errore")
        return
    }

    $src = $txtIn.Text
    $dst = if ([string]::IsNullOrWhiteSpace($txtOut.Text)) { $src } else { $txtOut.Text }

    if (-not (Test-Path -LiteralPath $src)) { 
        [System.Windows.Forms.MessageBox]::Show("La cartella sorgente non esiste!", "Errore")
        return 
    }
    if (-not (Test-Path -LiteralPath $dst)) { 
        New-Item -ItemType Directory -Path $dst -Force | Out-Null 
    }

    $script:isWorking = $true
    $btnStart.Enabled = $false
    $btnCancel.Visible = $true
    $btnCancel.Enabled = $true
    $txtLog.Clear()
    Start-Log -Folder $dst
    
    Write-Log "Avvio TURBO (solo CPU)" "INFO"
    $lblStatus.Text = "Ricerca immagini in corso..."

    # Ricerca file
    $validExts = @(".jpg", ".jpeg", ".png")
    $files = Get-ChildItem -LiteralPath $src -File -Recurse | Where-Object { 
        $validExts -contains $_.Extension.ToLower() 
    }
    
    $script:total = $files.Count
    if ($script:total -eq 0) { 
        [System.Windows.Forms.MessageBox]::Show("Nessuna immagine trovata!", "Info")
        $btnStart.Enabled = $true; $btnCancel.Visible = $false; $script:isWorking = $false
        return 
    }

    Write-Log "Trovate $($script:total) immagini." "INFO"
    $script:current = 0
    $progress.Maximum = $script:total
    $progress.Value = 0

    # Fissiamo il limite a 14 (ottimo per Alder Lake e simili)
    $limit = 14
    Write-Log "ThrottleLimit: $limit processi paralleli." "INFO"

    $filePaths = @($files.FullName)

    # Avviamo il job (solo CPU)
    $script:job = Start-ThreadJob -ScriptBlock {
        param($paths, $probe, $ffmpeg, $outDir, $limit, $q)
        
        $paths | ForEach-Object -Parallel {
            # Estraiamo le variabili
            $fPath = $_
            $probeExe = $using:probe
            $ffmpegExe = $using:ffmpeg
            $outFolder = $using:outDir
            $queueRef = $using:q
            
            # Nome file
            $fName = [System.IO.Path]::GetFileName($fPath)
            $outFile = [System.IO.Path]::Combine($outFolder, $fName)
            
            # Controllo risoluzione
            $resRaw = & $probeExe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$fPath"
            
            if ($resRaw -match '(\d+)x(\d+)') {
                $w = [int]$matches[1]
                $h = [int]$matches[2]
                
                if ($h -gt 1080) {
                    $cpuFilter = "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
                    try {
                        & $ffmpegExe -y -i "$fPath" -vf $cpuFilter -q:v 1 "$outFile" 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            $queueRef.Enqueue("OK: $fName (${w}x${h} -> 1920x1080)")
                        } else {
                            $queueRef.Enqueue("ERROR: $fName (ExitCode $LASTEXITCODE)")
                        }
                    } catch {
                        $queueRef.Enqueue("ERROR: $fName (Eccezione)")
                    }
                } else {
                    $queueRef.Enqueue("SKIP: $fName (${w}x${h} <= 1080p)")
                }
            } else {
                $queueRef.Enqueue("ERROR: $fName (Dimensioni non lette)")
            }
        } -ThrottleLimit $using:limit
    } -ArgumentList $filePaths, $script:ffprobePath, $script:ffmpegPath, $dst, $limit, $script:queue

    # Avvia il timer
    $script:timer.Start()
})

# ============================================
# AVVIO
# ============================================
if (-not (Initialize-FFmpeg)) { exit }
$form.ShowDialog() | Out-Null