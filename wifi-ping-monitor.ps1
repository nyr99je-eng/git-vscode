$target = "google.com"
$historySize = 20
$wifiRefreshSeconds = 10
$samples = @()
$wifiInfo = @()
$lastWifiRefresh = [datetime]::MinValue

while ($true) {
    $now = Get-Date
    if (($now - $lastWifiRefresh).TotalSeconds -ge $wifiRefreshSeconds) {
        $wifiInfo = @(netsh wlan show interfaces)
        $lastWifiRefresh = $now
    }

    $reply = Test-Connection -ComputerName $target -Count 1 -ErrorAction SilentlyContinue |
             Select-Object -First 1

    $ms = $null
    if ($reply) {
        $ms = $reply.ResponseTime
        if ($null -eq $ms) {
            $ms = $reply.Latency
        }
    }

    $samples += [pscustomobject]@{ Time = Get-Date; Ms = $ms }
    $samples = @($samples | Select-Object -Last $historySize)

    Clear-Host
    Write-Host "Wi-Fi connection details (refreshes every $wifiRefreshSeconds seconds)" -ForegroundColor Cyan
    if ($wifiInfo.Count -gt 0) {
        $wifiInfo | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No Wi-Fi interface information was returned."
    }

    Write-Host ""
    Write-Host "Live ping to $target  (each # is about 5 ms)" -ForegroundColor Cyan
    Write-Host ""

    foreach ($sample in $samples) {
        if ($null -eq $sample.Ms) {
            Write-Host ("{0:HH:mm:ss}  timeout" -f $sample.Time) -ForegroundColor Red
        } else {
            $bars = [math]::Min([math]::Max([int][math]::Ceiling($sample.Ms / 5), 1), 40)
            $color = if ($sample.Ms -lt 80) {
                "Green"
            } elseif ($sample.Ms -lt 150) {
                "Yellow"
            } else {
                "Red"
            }
            Write-Host ("{0:HH:mm:ss}  {1,4} ms  {2}" -f $sample.Time, $sample.Ms, ("#" * $bars)) -ForegroundColor $color
        }
    }

    $good = @($samples | Where-Object { $null -ne $_.Ms })
    $lost = $samples.Count - $good.Count
    $loss = [math]::Round(($lost / $samples.Count) * 100)

    if ($good.Count -gt 0) {
        $stats = $good | Measure-Object -Property Ms -Minimum -Maximum -Average
        Write-Host ""
        Write-Host ("Min {0} ms | Avg {1:N1} ms | Max {2} ms | Loss {3}%" -f `
            $stats.Minimum, $stats.Average, $stats.Maximum, $loss) -ForegroundColor Cyan
    }

    Start-Sleep -Seconds 1
}
