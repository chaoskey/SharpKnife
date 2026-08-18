param(
    [string]$SrcPath, [int]$W, [int]$H, [string]$Out,
    [int]$AlphaPct = 100
)
# Resize via System.Drawing (no GDI+). Optional AlphaPct (0..100, default 100 = unchanged):
# when <100, bake opacity into the image alpha channel (ColorMatrix), output 32bpp ARGB PNG.
# NOTE: keep this file ASCII-only (no multibyte chars) so Windows PowerShell 5.1 parses it
# correctly without a BOM (a UTF-8 multibyte comment can otherwise swallow the next line).
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($SrcPath)
$srcW = $img.Width
$srcH = $img.Height
if ($W -le 0 -and $H -le 0) { $W = $srcW; $H = $srcH }
elseif ($W -le 0) { $W = [int][Math]::Round($H * $srcW / $srcH) }
elseif ($H -le 0) { $H = [int][Math]::Round($W * $srcH / $srcW) }
$b = [System.Drawing.Bitmap]::new($W, $H)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($img, 0, 0, $W, $H)

if ($AlphaPct -lt 100) {
    # Apply opacity: redraw onto 32bpp ARGB through a ColorMatrix that scales alpha.
    $a = $AlphaPct / 100.0
    $b2 = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($b2)
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = 1; $cm.Matrix11 = 1; $cm.Matrix22 = 1; $cm.Matrix33 = $a
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetColorMatrix($cm)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
    $g2.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g2.DrawImage($b, $rect, 0, 0, $W, $H, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g2.Dispose()
    $ia.Dispose()
    $b.Dispose()
    $b = $b2
}

$b.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$b.Dispose()
$img.Dispose()
Write-Host "SCALE_OK $W x $H alpha=$AlphaPct"