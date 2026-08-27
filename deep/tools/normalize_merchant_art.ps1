param(
    [Parameter(Mandatory = $true)][string]$MaraSource,
    [Parameter(Mandatory = $true)][string]$ThistleSource,
    [Parameter(Mandatory = $true)][string]$CaldrisSource
)

Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$merchantRoot = Join-Path $projectRoot "assets\merchants"
$sourceRoot = Join-Path $merchantRoot "sources"
New-Item -ItemType Directory -Force -Path $merchantRoot, $sourceRoot | Out-Null

$assets = @(
    @{ Input = $MaraSource; SourceName = "tavern_mara_source.png"; RuntimeName = "tavern_mara.png" },
    @{ Input = $ThistleSource; SourceName = "forest_thistle_source.png"; RuntimeName = "forest_thistle.png" },
    @{ Input = $CaldrisSource; SourceName = "crypt_caldris_source.png"; RuntimeName = "crypt_caldris.png" }
)

foreach ($asset in $assets) {
    $sourcePath = Join-Path $sourceRoot $asset.SourceName
    Copy-Item -LiteralPath $asset.Input -Destination $sourcePath -Force
    $inputBitmap = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        $runtimeBitmap = New-Object System.Drawing.Bitmap 384, 576, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($runtimeBitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($inputBitmap, 0, 0, 384, 576)
            }
            finally { $graphics.Dispose() }
            $runtimePath = Join-Path $merchantRoot $asset.RuntimeName
            $runtimeBitmap.Save($runtimePath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $runtimeBitmap.Dispose() }
    }
    finally { $inputBitmap.Dispose() }
}
