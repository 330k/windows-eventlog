Param(
    [String]$inFile = $(throw "Compress-Gzip: No filename specified"),
    [String]$outFile = $($inFile + ".gz"),
    [switch]$delete,
    [int]$bufsize = 1048576
);

Trap{
    Write-Host "Received an exception: $_. Exiting.";
    break;
}

if (!(Test-Path $inFile)){
    "Input file $inFile does not exist.";
    exit 1;
}

Write-Host "Compressing $inFile to $outFile.";

$input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read);
$output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
$gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)

try{
    $buffer = New-Object byte[]($bufsize);

    while($true){
        $read = $input.Read($buffer, 0, $bufsize)
        if ($read -le 0){
            break;
        }

        $gzipStream.Write($buffer, 0, $read)
    }
}finally{
    $gzipStream.Close();
    $output.Close();
    $input.Close();
}

if ($delete){
    Remove-Item $inFile
}