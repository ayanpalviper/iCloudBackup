Import-Module PSSQLite

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




Function copy-and-rename {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Path,
        [Parameter(Mandatory = $true, Position = 1)]
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
    }
    Else {
        New-Item -ItemType File -Path $dfp -Force
    }

    Copy-Item $FileInfo -Destination $dfp -Force

    return $dfp

}

Function get-date-custom {
    get-date -Format "MM-dd-yyyy-HH-mm"
}

Function write-log-custom {
    param (
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $logstring = 'null',
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $path
    )
    $filename = get-date-custom
    $Logfile = -join ($path, $filename, '.log')
    $identifier = get-date -Format FileDateTime
    $logstring = -join ($identifier, ' ', $logstring)

    Add-content $Logfile -value $logstring
}


$drives = Get-PnpDevice -FriendlyName 'Seagate Expansion Drive'
$destinationRoot = 'E:\iCloud\Media\Original'
$duplicate = 'E:\iCloud\Media\Duplicate'
$Database = "E:\iCloud\iCloud.SQLite"
$sourcePath = "C:\Users\ayan9\Pictures\iCloud Photos\Photos"
$sourceLogFilePath = "C:\Users\ayan9\Pictures\iCloud Photos\logs\"
$isInternetConnected = test-connection 8.8.8.8 -Count 1 -Quiet
$driveConnected = $false

if (!$isInternetConnected) {
    write-log-custom -path $sourceLogFilePath -logstring 'No Internet Connection'
}

foreach ($drive in ($drives)){
    if($drive.Status -eq 'OK'){
        $driveConnected = $true
        break
    }
}

if ($driveConnected) {

    write-log-custom -path $sourceLogFilePath -logstring 'Drive connected'

    $items = Get-ChildItem -Path $sourcePath -Recurse    
    

    foreach ($item in ($items)) {  
        
        $createFile = "INSERT INTO FILE (NAME, LOCATION, CREATION_TIME, UPDATE_TIME, SIZE, HASH_KEY, DUPLICATE_ID) VALUES (@n, @l, @ct, @ut, @s, @hk, @di)"

        $createHash = "INSERT INTO HASH (HASH, CALC_TIME, ALGO) VALUES (@h, @ts, @a)"

        $searchHash = "select h.id as HID, f.id as FID, f.LOCATION, f.SIZE, max(f.UPDATE_TIME) FROM
        hash h,
        file f
        where h.id = f.HASH_KEY
        and h.hash = '@h'
        order by f.UPDATE_TIME desc"

        write-log-custom -path $sourceLogFilePath -logstring "Processing file - $($item.FullName)" 
        
         = $item.Length
        $sizeOnDisk = [Disk.SizeInfo]::GetCompressedFlieSize($item.FullName)

        if ([int]$sizeOnDisk -lt [int]$size) {
            write-log-custom -path $sourceLogFilePath -logstring 'File not completely downloaded yet. Skipping'
            continue
        }
        
        $runtime = Measure-Command -Expression { $hash = Get-FileHash -Path $item.FullName }

        $searchHash = $searchHash -replace '@h', $hash.Hash

        $result = Invoke-SqliteQuery -DataSource $Database -Query $searchHash

        if ($null -ne $result.HID) {
            # same hash already exists so the same file exists
            # move to duplicate folders
            $newpath = "$($duplicate)\$($item.extension.trimstart('.'))"
            mkdir $newpath -force

            $destinationFullPath = copy-and-rename -Path $newpath -FileInfo $item

            if ($destinationFullPath.GetType().FullName -eq "System.Object[]") {
                $destinationFullPath = $destinationFullPath[0]
            }

            write-log-custom -path $sourceLogFilePath -logstring "Duplicate file destination - $($destinationFullPath)"

            Invoke-SqliteQuery -DataSource $Database -Query $createFile -SqlParameters @{
                n  = $item.Name
                l  = $destinationFullPath
                ct = $item.CreationTimeUtc
                ut = $item.LastWriteTimeUtc
                s  = $size
                hk = $result.HID
                di = $result.FID
            }

            write-log-custom -path $sourceLogFilePath -logstring "Duplicate file - $($item.FullName)" 

        }
        else {

            $newpath = "$($destinationRoot)\$($item.extension.trimstart('.'))"            
            mkdir $newpath -force

            $destinationFullPath = copy-and-rename -Path $newpath -FileInfo $item

            if ($destinationFullPath.GetType().FullName -eq "System.Object[]") {
                $destinationFullPath = $destinationFullPath[0]
            }

            write-log-custom -path $sourceLogFilePath -logstring "Moving file - $($destinationFullPath)" 

                    
            Invoke-SqliteQuery -DataSource $Database -Query $createHash -SqlParameters @{
                h  = $hash.Hash
                ts = $runtime.TotalMilliseconds
                a  = $hash.Algorithm
            }

            $query = "SELECT ID FROM HASH where HASH = '" + $hash.Hash + "'"
            $res = Invoke-SqliteQuery -DataSource $Database -Query $query

            Invoke-SqliteQuery -DataSource $Database -Query $createFile -SqlParameters @{
                n  = $item.Name
                l  = $destinationFullPath
                ct = $item.CreationTimeUtc
                ut = $item.LastWriteTimeUtc
                s  = $size
                hk = $res.id
                di = $null
            }
                    
        }

        Remove-Item -Path $item.FullName
        write-log-custom -path $sourceLogFilePath -logstring 'File removed'
    }

    # get all items in the dir
    # check for size on disk
    # if size on disk is > 0 the check for size, size on disk should be > size
    # leave file as is if condition does not match and continue to next iteration of the loop
    # move file to HDD if above codition matches
    # create all table entries while moving the file

}
else {
    write-log-custom -path $sourceLogFilePath -logstring 'Drive not connected'
}
write-log-custom -path $sourceLogFilePath -logstring 'Done'

<#

$folder = 'C:\Users\ayan9\Pictures\iCloud Photos\Photos'
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
}

#>

