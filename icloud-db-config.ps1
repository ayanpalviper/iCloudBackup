Import-Module PSSQLite

    $Database = "E:\iCloud\iCloud.SQLite"

    $Query = "DROP TABLE FILE"

    #SQLite will create Names.SQLite for us
    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################

    $Query = "DROP TABLE HASH"

    #SQLite will create Names.SQLite for us
    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################

    $Query = "CREATE TABLE HASH (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        HASH Varchar(256),
        CALC_TIME NUMBER,
        ALGO VARCHAR(10)
    )"

    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################

    $Query = "CREATE UNIQUE INDEX idx_hash ON hash(hash)"

    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################

    $Query = "CREATE TABLE FILE (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        NAME Varchar(255),
        LOCATION Varchar(32000),
        CREATION_TIME DATETIME,
        UPDATE_TIME DATETIME,
        SIZE NUMBER,
        HASH_KEY NUMBER,
        FOREIGN KEY(HASH_KEY) REFERENCES HASH(ID)
    )"

    #SQLite will create Names.SQLite for us
    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################


    $Query = "CREATE UNIQUE INDEX idx_loc ON file(location)"

    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################

    $Query = "PRAGMA foreign_keys = ON"

    Invoke-SqliteQuery -Query $Query -DataSource $Database

    ##################################################################################################################
