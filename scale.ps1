param(
    [string]$SrcPath, [int]$W, [int]$H, [string]$Out
)
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
$g.DrawImage($img, 0, 0, $W, $H)
$b.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$b.Dispose()
$img.Dispose()
Write-Host "SCALE_OK $W x $H"