Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Dell\.gemini\antigravity\brain\078c22bb-a2ab-41fb-b91a-b9e7f243df24\.user_uploaded\media__1785095810786.jpg"

if (-not (Test-Path $srcPath)) {
    Write-Host "Source image not found at $srcPath"
    exit 1
}

$origBmp = New-Object System.Drawing.Bitmap($srcPath)

$sizes = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($dir in $sizes.Keys) {
    $size = $sizes[$dir]
    $targetDir = "C:\Users\Dell\Desktop\offpay_app_update\android\app\src\main\res\$dir"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $targetPath = "$targetDir\ic_launcher.png"
    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Force
    }
    
    $resized = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($resized)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($origBmp, 0, 0, $size, $size)
    $g.Dispose()
    
    $resized.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $resized.Dispose()
    Write-Host "Converted and saved ${size}x${size} PNG to $targetPath"
}

$logoPath = "C:\Users\Dell\Desktop\offpay_app_update\assets\images\logo.png"
if (Test-Path $logoPath) {
    Remove-Item -Path $logoPath -Force
}
$origBmp.Save($logoPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Converted and saved true PNG to $logoPath"

$origBmp.Dispose()
Write-Host "All Android icons and app logo successfully converted to official PNG format!"
