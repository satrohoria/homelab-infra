$BasePath = "C:\Homelab\Speedtest"
$CsvPath  = Join-Path $BasePath "speedtest-history.csv"

$Raw = speedtest --server-id=16322 --format=json | ConvertFrom-Json

$Invariant = [System.Globalization.CultureInfo]::InvariantCulture

$DownloadMbps = ([double]$Raw.download.bandwidth * 8.0 / 1000000.0).ToString("0.00", $Invariant)
$UploadMbps   = ([double]$Raw.upload.bandwidth * 8.0 / 1000000.0).ToString("0.00", $Invariant)

$PingMs = ([double]$Raw.ping.latency).ToString("0.00", $Invariant)
$JitterMs = ([double]$Raw.ping.jitter).ToString("0.00", $Invariant)

if ($null -eq $Raw.packetLoss) {
    $PacketLoss = "0.00"
}
else {
    $PacketLoss = ([double]$Raw.packetLoss).ToString("0.00", $Invariant)
}

$Result = [PSCustomObject]@{
    Timestamp     = $Raw.timestamp
    DownloadMbps  = $DownloadMbps
    UploadMbps    = $UploadMbps
    PingMs        = $PingMs
    JitterMs      = $JitterMs
    PacketLoss    = $PacketLoss
    ISP           = $Raw.isp
    Server        = $Raw.server.name
    ServerHost    = $Raw.server.host
    ResultURL     = $Raw.result.url
}

if (Test-Path $CsvPath) {
    $Result | Export-Csv -Path $CsvPath -NoTypeInformation -Append -Encoding UTF8
}
else {
    $Result | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
}

$Result

$JsonPath = Join-Path $BasePath "speedtest-latest.json"

$Result |
    ConvertTo-Json |
    Set-Content -Path $JsonPath -Encoding UTF8

$RemoteCsv  = "lenilson@192.168.0.2:/opt/speedpc/speedtest-history.csv"
$RemoteJson = "lenilson@192.168.0.2:/opt/speedpc/speedtest-latest.json"

scp -o BatchMode=yes -o ConnectTimeout=10 $CsvPath $RemoteCsv
scp -o BatchMode=yes -o ConnectTimeout=10 $JsonPath $RemoteJson