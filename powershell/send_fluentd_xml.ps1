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
.EXTERNALSCRIPTDEPENDENCIES "compress_gzip.ps1"
.RELEASENOTES
#>
<#
.DESCRIPTION
 Send eventlog XML to fluentd.

 $fluentd : Set the fluentd IP address and port
#>
﻿Param(
    [string]$xmlFile = $(throw "Send-Eventlog: No filename specified"),
    [string]$fluentd = "http://127.0.0.1:9880/windows.eventlog",
    [int]$bulkSize = 200,
    [bool]$compress = $true
)

Add-Type -Assembly System.Web

function send-Fluentd([String]$xml) {
    $tmp1 = [System.IO.Path]::GetTempFileName()
    $tmp2 = [System.IO.Path]::GetTempFileName()

    "<root>" + $xml + "</root>" | Out-File $tmp1

    try{
        $xslt.Transform($tmp1, $tmp2)

        $json = (Get-Content $tmp2) -replace "%", "\u0025" -replace "\+","\u002b"
        $body = [System.Text.Encoding]::UTF8.GetBytes("json=" + [System.Web.HttpUtility]::UrlEncode($json))
        $null = Invoke-WebRequest $fluentd -Method Post -Body $body
    }catch{
        Write-Host $Error[0].ToString() -ForegroundColor Red
    }finally{
        Remove-Item $tmp1 -Force
        Remove-Item $tmp2 -Force
    }
}

$c = 0
$sr = New-Object System.IO.StreamReader $xmlFile
$doc = New-Object System.Xml.XmlDocument
$lineList = New-Object 'System.Collections.Generic.List[System.String]'
$xslt = New-Object System.Xml.Xsl.XslCompiledTransform

$xslt.Load("$PSScriptRoot\eventlog.xslt")

try{
    while($sr.Peek() -ge 0){
        $line = $sr.ReadLine()
        $lineList.Add($line)
        if($line.EndsWith("</Event>")){
            $c++

            if(($c % $bulkSize) -eq 0){
                Write-Progress -Activity $xmlFile -Status "Sending to fluentd..." -CurrentOperation $c
                send-Fluentd($lineList.ToArray() -join "`n")
                Write-Progress -Activity $xmlFile -Status "Sent" -CurrentOperation $c
                $lineList.Clear()
            }
        
        }
    }
    Write-Progress -Activity $xmlFile -Status "Sending to fluentd..." -CurrentOperation $c
    send-Fluentd($lineList.ToArray() -join "`n")
    Write-Progress -Activity $xmlFile -Status "Sent" -CurrentOperation $c
}finally{
    $sr.Close()
    Write-Progress -Activity $xmlFile -Completed
}

if($compress){
    & "$PSScriptRoot\compress_gzip.ps1" $xmlFile -delete
}
