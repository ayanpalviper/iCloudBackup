add-type -type  @'
using System;
using System.Runtime.InteropServices;
using System.ComponentModel;

namespace Disk
{
    public class SizeInfo
    {
        [DllImport("kernel32.dll", SetLastError=true, EntryPoint="GetCompressedFileSize")]
        static extern uint GetCompressedFileSizeAPI(string lpFileName, out uint lpFileSizeHigh);

        public static ulong GetCompressedFlieSize(string FileName)
        {
            uint HighOrder;
            uint LowOrder;
            LowOrder = GetCompressedFileSizeAPI(FileName, out HighOrder);
            int error = Marshal.GetLastWin32Error();
            if (HighOrder == 0 && LowOrder == 0xFFFFFFFF && error != 0)
                throw new Win32Exception(error);
            else
                return ((ulong)HighOrder << 32) + LowOrder;
        }
    }
}
'@


Function copy-and-rename{
   param (
       [Parameter(Mandatory=$true, Position=0)]
       [string]
       $Path,
       [Parameter(Mandatory=$true, Position=1)]
       [System.IO.FileSystemInfo]
       $FileInfo
   )


       $dfp = "$($Path)\$($FileInfo.Name)"
       $onlyFileName = $FileInfo.Name.Replace($FileInfo.Extension, "")
       If (Test-Path $dfp) {
           $i = 0
           While (Test-Path $dfp) {
               $i += 1
               $dfp = "$($($Path))\$(($onlyFileName)+" - "+($i)+($FileInfo.Extension))"
           }
       } Else {
           New-Item -ItemType File -Path $dfp -Force
       }

       Copy-Item $FileInfo -Destination $dfp -Force

       return $dfp

}


$drive = Get-PnpDevice -FriendlyName 'Seagate Expansion Drive'
$destinationRoot = 'E:\iCloud\Media\Original\test'
$duplicate = 'E:\iCloud\Media\Duplicate\test'
Import-Module PSSQLite
$Database = "D:\Work\VSCode\powershell\iCloud.SQLite"
$sourcePath = "C:\Users\ayan9\Pictures\iCloud Photos\test"


if ($drive) {
    Write-Output 'drive found'

    $items = Get-ChildItem -Path $sourcePath -Recurse

    $searchHash = "select h.id as HID, f.id as FID, f.LOCATION, f.SIZE FROM
            hash h,
            file f
            where h.id = f.HASH_KEY
            and h.hash = '@h'"

    $createFile = "INSERT INTO FILE (NAME, LOCATION, CREATION_TIME, UPDATE_TIME, SIZE, HASH_KEY, DUPLICATE_ID) VALUES (@n, @l, @ct, @ut, @s, @hk, @di)"

    $createHash = "INSERT INTO HASH (HASH, CALC_TIME, ALGO) VALUES (@h, @ts, @a)"

    foreach ($item in ($items)) {
        $sizeOnDisk = [Disk.SizeInfo]::GetCompressedFlieSize($item.FullName)
        if ([int]$sizeOnDisk -gt 0) {
            $size = $item.Length
            if ([int]$sizeOnDisk -ge $size) {
                $runtime = Measure-Command -Expression { $hash = Get-FileHash -Path $item.FullName }

                $searchHash = $searchHash -replace '@h', $hash.Hash

                $result = Invoke-SqliteQuery -DataSource $Database -Query $searchHash

                if ($result) {
                    # same hash already exists so the same file exists
                    # move to duplicate folders
                    $newpath = "$($duplicate)\$($item.extension.trimstart('.'))"
                    mkdir $newpath -force

                    $destinationFullPath = copy-and-rename -Path $newpath -FileInfo $item

                    Invoke-SqliteQuery -DataSource $Database -Query $createFile -SqlParameters @{
                        n = $item.Name
                        l = $destinationFullPath
                        ct = $item.CreationTimeUtc
                        ut = $item.LastWriteTimeUtc
                        s = $size
                        hk =  $result.HID
                        di = $result.FID
                    }

                }else{

                    $newpath = "$($destinationRoot)\$($item.extension.trimstart('.'))"
                    Write-Output $newpath
                    mkdir $newpath -force

                    $destinationFullPath = copy-and-rename -Path $newpath -FileInfo $item

                    Write-Output $destinationFullPath

                    <#
                    Invoke-SqliteQuery -DataSource $Database -Query $createHash -SqlParameters @{
                        h = $hash.Hash
                        ts = $runtime.TotalMilliseconds
                        a = $hash.Algorithm
                    }

                    $query = "SELECT ID FROM HASH where HASH = '" + $hash.Hash + "'"
                    $res = Invoke-SqliteQuery -DataSource $Database -Query $query

                    Invoke-SqliteQuery -DataSource $Database -Query $createFile -SqlParameters @{
                        n = $item.Name
                        l = $destinationFullPath
                        ct = $item.CreationTimeUtc
                        ut = $item.LastWriteTimeUtc
                        s = $size
                        hk =  $res.id
                        di = $null
                    }
                    #>
                }

                Remove-Item -Path $item.FullName
            }
            else {
                continue
            }
        }
        else {
            continue
        }


    }

    # get all items in the dir
    # check for size on disk
    # if size on disk is > 0 the check for size, size on disk should be > size
    # leave file as is if condition does not match and continue to next iteration of the loop
    # move file to HDD if above codition matches
    # create all table entries while moving the file

}
else {
    Write-Output 'Drive not connected'
}

Write-Output 'Done'
<#$folder = 'C:\Users\ayan9\Pictures\iCloud Photos\Photos'
$filter = '*.*'                             # <-- set this according to your requirements
$destination = ''
$fsw = New-Object IO.FileSystemWatcher $folder, $filter -Property @{
 IncludeSubdirectories = $true              # <-- set this according to your requirements
 NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
}
$path
Register-ObjectEvent $fsw Created -SourceIdentifier FileCreated -Action {
 $path = $Event.SourceEventArgs.FullPath
 $name = $Event.SourceEventArgs.Name
 $changeType = $Event.SourceEventArgs.ChangeType
 $timeStamp = $Event.TimeGenerated
 Write-Host "The file '$name' was $changeType at $timeStamp"
 Move-Item $path -Destination $destination -Force -Verbose # Force will overwrite files with same name
}#>

