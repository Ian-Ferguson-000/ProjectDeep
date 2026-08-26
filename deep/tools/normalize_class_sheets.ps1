param([string]$AssetRoot = "assets/classes")
Add-Type -AssemblyName System.Drawing
$cellSource = 256
$cellWidth = 96
$cellHeight = 80
$drawSize = 80
Get-ChildItem -LiteralPath $AssetRoot -Directory | ForEach-Object {
    $sourcePath = Join-Path $_.FullName "source.png"
    if (-not (Test-Path -LiteralPath $sourcePath)) { return }
    $source = [System.Drawing.Bitmap]::new($sourcePath)
    $output = [System.Drawing.Bitmap]::new($cellWidth * 6, $cellHeight * 4, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($output)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    for ($row = 0; $row -lt 4; $row++) {
        for ($column = 0; $column -lt 6; $column++) {
            $sourceRect = [System.Drawing.Rectangle]::new($column * $cellSource, $row * $cellSource, $cellSource, $cellSource)
            $destRect = [System.Drawing.Rectangle]::new($column * $cellWidth + 8, $row * $cellHeight, $drawSize, $drawSize)
            $graphics.DrawImage($source, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
        }
    }
    $destination = Join-Path $_.FullName "sheet.png"
    $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $output.Dispose()
    $source.Dispose()
    Write-Output $destination
}
