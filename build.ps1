# Compiles the core with Quartus and writes output/bitstream.rbf_r, the bitstream Pocket loads.
#
#   ./build.ps1
#   ./build.ps1 -QuartusBin "D:\altera_lite\25.1std\quartus\bin64"
#
# Pocket loads the Quartus .rbf with the bits of each byte reversed. The script stops when the
# compile fails, and leaves the timing and fit reports in src/fpga/output_files/.
param(
    [string]$QuartusBin = "C:\altera_lite\25.1std\quartus\bin64"
)

$ErrorActionPreference = "Stop"

$fpga = Join-Path -Path $PSScriptRoot -ChildPath "src/fpga"
$rbf = Join-Path -Path $fpga -ChildPath "output_files/ap_core.rbf"
$output = Join-Path -Path $PSScriptRoot -ChildPath "output/bitstream.rbf_r"
$quartusSh = Join-Path -Path $QuartusBin -ChildPath "quartus_sh.exe"

Push-Location -Path $fpga
try {
    & $quartusSh --flow compile ap_core
    if ($LASTEXITCODE -ne 0) {
        throw "quartus_sh exited with $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

# Each entry is its index with the bit order reversed.
$table = foreach ($value in 0..255) {
    $out = 0
    for ($bit = 0; $bit -lt 8; $bit++) {
        $out = ($out -shl 1) -bor (($value -shr $bit) -band 1)
    }
    [byte]$out
}

$bytes = [System.IO.File]::ReadAllBytes($rbf)
for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = $table[$bytes[$i]]
}
[System.IO.File]::WriteAllBytes($output, $bytes)

Write-Output -InputObject "Wrote $output"
