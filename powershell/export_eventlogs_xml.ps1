Param (
    $hosts = @("ICOAD1", "ICOAD2", "ICOFS", "ICOACSRV", "ICOGRN", "ICOSD", "ICOSKY"),
    $logNames = @("Security", "Application", "System"),
    $dateStart = $null,
    $dateEnd = [System.DateTime]::UtcNow.AddMinutes(-5)
)

$settingfile = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) ($MyInvocation.MyCommand.Name -replace ".ps1", ".json")
if(Test-Path $settingfile){
    $setting = (Get-Content $settingfile -Raw) | ConvertFrom-Json
}else{
    $setting = @{
        lastdateEnd = [System.DateTime]::Parse("2000/1/1 0:0:0")
    }
}

if($dateStart -eq $null){
    $dateStart = $setting.lastdateEnd
    $setting.lastdateEnd = $dateEnd
}else{
    $dateStart = [System.DateTime]::Parse($dateStart)
}

Out-File -InputObject (ConvertTo-Json $setting) -FilePath $settingfile -Force

Write-Host "start: $dateStart"
Write-Host "end:   $dateEnd"


$dirbase = "\\172.16.20.126\e$\logs\"

$dateStartutc = [System.TimeZoneInfo]::ConvertTimeToUtc($dateStart).ToString("yyyy-MM-ddTHH:mm:ssZ")
$dateEndutc = [System.TimeZoneInfo]::ConvertTimeToUtc($dateEnd).ToString("yyyy-MM-ddTHH:mm:ssZ")

$query = "*[System[TimeCreated[@SystemTime>='$dateStartutc' and @SystemTime<'$dateEndutc']]]"


$dir = $dirbase + $dateStart.ToString("yyyyMMdd") + "\" + $dateStart.ToString("yyyyMMdd_HHmmss") + "\"
New-Item $dir -ItemType Directory -Force | Out-Null

foreach($h in $hosts){
    #Write-Host "$h"
    Start-Job -ScriptBlock {
        Param($h, $logNames, $query, $dir, $fluentps)
        foreach($l in $logNames){
            # XML
            $xmlFile = $dir + $h + "_" + $l + ".xml"
            if( Test-Path $xmlFile ){
            }else{
                $xml = wevtutil.exe qe "$l" """/q:$query""" """/r:$h""" "/uni:true" "/f:RenderedXml"
                $xml = $xml -replace " xmlns='.+?'", "" # 名前空間削除
                Out-File -InputObject $xml -FilePath $xmlFile -Encoding utf8 -Force
            }

            Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-Command `"$fluentps $xmlFile`"" -WindowStyle Hidden
        }
    } -ArgumentList @($h, $logNames, $query, $dir, "$PSScriptRoot\send_fluentd_xml.ps1") -Name $h
}

Get-Job | Wait-Job