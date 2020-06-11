$path = "E:\iCloud\initial backup"
foreach ($file in (get-childitem -file $path))
{
    $newpath = "$($path)\$($file.extension.trimstart('.'))"
    Write-Output $newpath
    md $newpath -force
    move-item $file $newpath
}