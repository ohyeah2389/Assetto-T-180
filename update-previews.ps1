$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $repoRoot 'Build'
$sourceRoot = Join-Path $repoRoot 'Source'

if (-not (Test-Path -LiteralPath $buildRoot -PathType Container)) {
    throw "Build folder not found: $buildRoot"
}

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Source folder not found: $sourceRoot"
}

$copied = 0
$skipped = 0

Get-ChildItem -LiteralPath $buildRoot -Directory | ForEach-Object {
    $buildCar = $_.FullName
    $carName = $_.Name
    $buildSkins = Join-Path $buildCar 'skins'
    if (-not (Test-Path -LiteralPath $buildSkins -PathType Container)) { return }

    Get-ChildItem -LiteralPath $buildSkins -Directory | ForEach-Object {
        $skinName = $_.Name
        $sourceSkin = Join-Path (Join-Path (Join-Path $sourceRoot $carName) 'skins') $skinName
        if (-not (Test-Path -LiteralPath $sourceSkin -PathType Container)) {
            Write-Warning "Missing source skin folder: $sourceSkin"
            $skipped++
            return
        }

        Get-ChildItem -LiteralPath $_.FullName -File | Where-Object {
            $_.BaseName -ieq 'preview' -and @('.png', '.jpg') -contains $_.Extension.ToLowerInvariant()
        } | ForEach-Object {
            $dest = Join-Path $sourceSkin $_.Name
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            Write-Host "Copied $($_.FullName) -> $dest"
            $copied++
        }
    }
}

Write-Host "Done. Copied: $copied, skipped skin folders: $skipped"
