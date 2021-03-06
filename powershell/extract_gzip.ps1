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
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>
<#
.DESCRIPTION
 Decompress a file with gzip.
#>
﻿Param(
    [String]$inFile = $(throw "Extract-Gzip: No filename specified"),
    [String]$outFile = $($inFile -ireplace ".gz$", ""),
    [switch]$delete
);

Trap{
    Write-Host "Received an exception: $_. Exiting.";
    break;
}

if (!(Test-Path $inFile)){
    "Input file $inFile does not exist.";
    exit 1;
}

Write-Host "Extracting $inFile to $outFile.";

$input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read);
$output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
$gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)

try{
    $gzipStream.CopyTo($output)
}finally{
    $gzipStream.Close();
    $output.Close();
    $input.Close();
}

if ($delete){
    Remove-Item $inFile
}
