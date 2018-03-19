<#PSScriptInfo
.VERSION 1.0
.AUTHOR 330k
.COPYRIGHT 330k
.TAGS EventLog
.LICENSEURI https://github.com/330k/windows-eventlog/blob/master/LICENSE
.PROJECTURI https://github.com/330k/windows-eventlog
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES "send_fluentd_xml.ps1"
.RELEASENOTES
#>
<#
.DESCRIPTION
 Export Windows Event Log with wevtutil.exe.
 Output XML contains rendered information is Unicode encoded.

 $hosts : Target Machines
 $logNames : Target Log Names (Default: "Security", "Application", "System")
 $datestart : Start date of event logs to retrieve
 $dateend : End date of event logs to retrive
#>
﻿Param (
    $hosts = @("SERVER1", "SERVER2", "SERVER3"),
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

# Set the folder to save XML
$dirbase = "D:\logs\"

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
                # Delete Namespace in XML
                $xml = $xml -replace " xmlns='.+?'", ""
                Out-File -InputObject $xml -FilePath $xmlFile -Encoding utf8 -Force
            }

            Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-Command `"$fluentps $xmlFile`"" -WindowStyle Hidden
        }
    } -ArgumentList @($h, $logNames, $query, $dir, "$PSScriptRoot\send_fluentd_xml.ps1") -Name $h
}

Get-Job | Wait-Job
