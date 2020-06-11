Function get-date-custom
{
    get-date -Format "MM-dd-yyyy-HH-mm"
}


Function write-log-custom {
    Param (
            [string]$logstring='null'
    )
    $filename = get-date-custom
    $Logfile = -join('E:\iCloud\logs\', $filename,'.log')
    $identifier = get-date -Format FileDateTime
    $logstring = -join($identifier, ' ', $logstring)

    Add-content $Logfile -value $logstring
    }


Import-Module PSSQLite

$items = Get-ChildItem -Path 'E:\iCloud\Media' -Recurse

$query_hash = "INSERT INTO HASH (HASH, CALC_TIME, ALGO) VALUES (@h, @ts, @a)"
$query_file = "INSERT INTO FILE (NAME, LOCATION, CREATION_TIME, UPDATE_TIME, SIZE, HASH_KEY) VALUES (@n, @l, @ct, @ut, @s, @hk)"
$Database = "E:\iCloud\iCloud.SQLite"

foreach ($item in ($items)){
    $log = 'Processing File : ' + $item.FullName
    write-log-custom $log
    $runtime = Measure-Command -Expression { $hash = Get-FileHash -Path $item.FullName }
    if($hash){

        $searchQuery = "SELECT ID FROM HASH where HASH = '" + $hash.Hash + "'"
        $result = Invoke-SqliteQuery -DataSource $Database -Query $searchQuery

        if($result.Count -gt 0){
            $log = 'Same hash already exits : ' + $hash.Hash
            write-log-custom $log
        }else{

            Invoke-SqliteQuery -DataSource $Database -Query $query_hash -SqlParameters @{
                h = $hash.Hash
                ts = $runtime.TotalMilliseconds
                a = $hash.Algorithm
            }
            $log = 'New hash added : ' + $hash.Hash
            write-log-custom $log

        }

        $sq = "SELECT ID, NAME, LOCATION FROM FILE where HASH_KEY = '" + $result.ID + "'"
        $result = Invoke-SqliteQuery -DataSource $Database -Query $sq

        if($item.FullName -eq $result.LOCATION){
            if($item.Name -eq $result.NAME){
                write-log-custom 'Same file found at same location'
            continue
            }
        }

        $name = $item.Name
        $location = $item.FullName
        $ct = $item.CreationTimeUtc
        $ut = $item.LastWriteTimeUtc
        $size = $item.Length
        $hk = Invoke-SqliteQuery -DataSource $Database -Query $searchQuery

        Invoke-SqliteQuery -DataSource $Database -Query $query_file -SqlParameters @{
            n = $name
            l = $location
            ct = $ct
            ut = $ut
            s = $size
            hk = $hk.ID
        }

        write-log-custom 'File data added'

        # Check to see if we inserted the data:
        <#
        $query = "SELECT * FROM HASH where HASH = '" + $hash.Hash + "'"
        Invoke-SqliteQuery -DataSource $Database -Query $query
        $query = "SELECT * FROM FILE where HASH_KEY = '" + $hk.ID  + "'"
        Invoke-SqliteQuery -DataSource $Database -Query $query
        #>
            #Write-Output 'Hash written' + $hash
    }else{
        write-log-custom 'No Hash'
    }
}
