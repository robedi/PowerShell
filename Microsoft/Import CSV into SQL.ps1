#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
cls

# ----------------------------------------------------------------

function Log-Message {
    param([string]$message)
    $timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "$timestamp - $message"
    Write-Host   $fullMessage
    Add-Content -Path $logFile -Value $fullMessage
}

# ----------------------------------------------------------------
# CONFIGURATION
# Figure out which SQL instance to talk to: default or SQLEXPRESS
# Default instance service name: MSSQLSERVER
# Express service name: MSSQL$SQLEXPRESS

$machine      = $env:COMPUTERNAME
$defaultSvc   = Get-Service -Name 'MSSQLSERVER'    -ErrorAction SilentlyContinue
$expressSvc   = Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue

if ($defaultSvc -and $defaultSvc.Status -eq 'Running') {
    $server = "localhost" # use default instance
    Log-Message "Using default SQL instance on $machine"
}
elseif ($expressSvc -and $expressSvc.Status -eq 'Running') {
    $server = "localhost\SQLEXPRESS" # use Express instance
    Log-Message "Using SQL Express instance on $machine\SQLEXPRESS"
}
else {
    throw "No running SQL Server or SQLExpress instance found on $machine"
}

$csvFolder        = "C:\Scripts\CSV"
$database         = "BrianDatabase"
$logFile          = "C:\Scripts\import_log.txt"
$connectionString = "Server=$server;Database=$database;Trusted_Connection=True;"

# ----------------------------------------------------------------
# 0) Ensure database exists via SMO (SQL Server Management Objects)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
$srv = New-Object Microsoft.SqlServer.Management.Smo.Server $server
if (-not $srv.Databases.Contains($database)) {
    $newDb = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, $database)
    $newDb.Create()
    Log-Message "Created database [$database] via SQL Server Management Objects."
} else {
    Log-Message "Database [$database] already exists (SQL Server Management Objects)."
}

# ----------------------------------------------------------------
# 1) Ensure CsvImportLog exists
$ensureMeta = @"
IF OBJECT_ID(N'dbo.CsvImportLog','U') IS NULL
BEGIN
  CREATE TABLE dbo.CsvImportLog (
    FileName      NVARCHAR(260) PRIMARY KEY,
    LastWriteTime DATETIME2     NOT NULL
  );
END
"@
$metaConn = New-Object System.Data.SqlClient.SqlConnection $connectionString
$metaCmd  = $metaConn.CreateCommand(); $metaCmd.CommandText = $ensureMeta
$metaConn.Open(); [void]$metaCmd.ExecuteNonQuery(); $metaConn.Close()

# ----------------------------------------------------------------
# 2) Detect whether CsvImportLog is empty
$logConn = New-Object System.Data.SqlClient.SqlConnection $connectionString
$cntCmd  = $logConn.CreateCommand(); $cntCmd.CommandText = "SELECT COUNT(*) FROM dbo.CsvImportLog;"
$logConn.Open(); $logCount = $cntCmd.ExecuteScalar(); $logConn.Close()

$initialRun = ($logCount -eq 0)
if ($initialRun) {
    Log-Message "CsvImportLog is empty, initial run: tables will be dropped before import."
} else {
    Log-Message "CsvImportLog has entries, skipping table drops on import."
}

# ----------------------------------------------------------------
# 3) Gather and process each pivot-named CSV
$files = Get-ChildItem -Path $csvFolder -Filter *.csv |
         Where-Object { $_.Name -match '(?i)pivot' }

foreach ($fi in $files) {
    $csvName   = $fi.Name
    $filePath  = $fi.FullName
    $lastWrite = $fi.LastWriteTimeUtc

    # normalize table name
    $tableName = $fi.BaseName `
      -replace '^(?:DK|SE)_','' `
      -replace '[_\-]?(19|20)\d{2}','' `
      -replace '[\[\]\(\)\s\-]+','_' `
      -replace '__+','_' `
      -replace '^_+|_+$',''

    Log-Message "Checking $csvName in target table: [$tableName]"

    # fetch prior import timestamp
    $metaConn.Open()
    $checkCmd   = $metaConn.CreateCommand()
    $checkCmd.CommandText = "SELECT LastWriteTime FROM dbo.CsvImportLog WHERE FileName = N'$csvName';"
    $prevImport = $checkCmd.ExecuteScalar()
    $metaConn.Close()

    # skip if unchanged
    if ($prevImport) {
        $delta = [math]::Abs((New-TimeSpan -Start $prevImport -End $lastWrite).TotalSeconds)
        if ($delta -lt 1) {
            Log-Message "Unchanged ($($delta.ToString('N3'))s). Skipping $csvName."
            continue
        }
    }

    Log-Message "Importing $csvName …"

    # ----------------------------------------------------------------
    # New/updated file: if previously imported, delete that year's rows
    if ($prevImport) {
        if ($fi.BaseName -match '(19|20)\d{2}') {
            $fileYear = $Matches[0]
            $delSql   = "DELETE FROM dbo.$tableName WHERE YEAR([Date]) = $fileYear;"
            $delConn  = New-Object System.Data.SqlClient.SqlConnection $connectionString
            $delCmd   = $delConn.CreateCommand(); $delCmd.CommandText = $delSql
            $delConn.Open(); $rowsDeleted = $delCmd.ExecuteNonQuery(); $delConn.Close()
            Log-Message "Deleted $rowsDeleted existing rows for year $fileYear from [$tableName]."
        } else {
            Log-Message "WARNING: Could not extract year from filename $csvName; skipping delete."
        }
    }

    # ----------------------------------------------------------------
    # Read header & detect delimiter
    $header = Get-Content -Path $filePath -TotalCount 1
    if (-not $header) {
        Log-Message "WARNING: $csvName is empty. Skipping."
        continue
    }
    $tabs  = ([regex]::Matches($header,"`t")).Count
    $sims  = ([regex]::Matches($header,";")).Count
    $delim = if ($sims -gt $tabs) { ";" } else { "`t" }

    # split columns & clean
    $columns    = $header -split ([regex]::Escape($delim))
    $cleanNames = $columns | ForEach-Object {
        ($_ -replace ' ?[-&]','' -replace '[\[\]\(\)]','' -replace ' ','_').Trim()
    }
    $columnList = ($cleanNames | ForEach-Object { "[$_]" }) -join ", "

    # build schema defs & type map
    $colDefs  = New-Object System.Collections.Generic.List[string]
    $colTypes = @{}
    foreach ($col in $columns) {
        $c = $col -replace ' ?[-&]','' -replace '[\[\]\(\)]','' -replace ' ','_'
        if ($c -match '(?i)amount_EUR|ICBO_EUR|Cost_EUR') { $colDefs.Add("[$c] NUMERIC(18,2)"); $colTypes[$c]="NUMERIC" }
        elseif($c -match '(?i)Billed_hours|All_hours') { $colDefs.Add("[$c] NUMERIC(18,2)"); $colTypes[$c]="NUMERIC" }
        elseif($c -match '(?i)date') { $colDefs.Add("[$c] DATE"); $colTypes[$c]="DATE" }
        else { $colDefs.Add("[$c] NVARCHAR(MAX)");  $colTypes[$c]="STRING" }
    }

    # ----------------------------------------------------------------
    # Drop table once on initial run
    if ($initialRun) {
        Log-Message "Initial run: dropping table if exists [$tableName]."
        $dropSql  = "IF OBJECT_ID(N'dbo.$tableName','U') IS NOT NULL DROP TABLE dbo.$tableName;"
        $dropConn = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $dropCmd  = $dropConn.CreateCommand(); $dropCmd.CommandText = $dropSql
        $dropConn.Open(); [void]$dropCmd.ExecuteNonQuery(); $dropConn.Close()
        $initialRun = $false
    }

    # ----------------------------------------------------------------
    # Ensure table exists
    $createSql = @"
IF OBJECT_ID(N'dbo.$tableName','U') IS NULL
BEGIN
    CREATE TABLE dbo.$tableName (
        $(($colDefs -join ",`n        "))
    )
END
"@
    $tc   = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $tcmd = $tc.CreateCommand(); $tcmd.CommandText = $createSql
    $tc.Open(); [void]$tcmd.ExecuteNonQuery(); $tc.Close()
    Log-Message "Table [$tableName] ready."

    # ----------------------------------------------------------------
    # Bulk insert this CSV
    $rows     = Get-Content -Path $filePath | Select-Object -Skip 1
    $total    = $rows.Count
    $inserted = 0; $skipped = 0; $i = 0

    $dc = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $dc.Open()
    foreach ($r in $rows) {
        $i++
        Write-Progress -Activity "Importing $csvName" `
                       -Status "Row $i/$total" `
                       -PercentComplete (($i/$total)*100)
        if (-not $r.Trim()) { continue }

        $vals    = $r -split ([regex]::Escape($delim))
        $sqlVals = @()
        for ($j = 0; $j -lt $columns.Length; $j++) {
            $orig = $columns[$j].Trim()
            $c    = $orig -replace ' ?[-&]','' -replace '[\[\]\(\)]','' -replace ' ','_'
            $raw  = if ($j -lt $vals.Length) { $vals[$j].Trim().Trim('"') } else { "" }
            if ($raw -match '^\*+$') { $raw = '0' }
            $raw = $raw.Trim()

            switch ($colTypes[$c]) {
                "DATE" {
                    try { 
                        $dt = [datetime]::ParseExact($raw,@(
                            'yyyy-MM-dd','dd-MM-yyyy','dd-MM-yy',
                            'yyyy/MM/dd','dd/MM/yyyy','M/d/yyyy','d-MMM-yy'
                        ), $null) 
                    } catch { 
                        try { $dt = [datetime]::Parse($raw) } catch { $sqlVals += "NULL"; continue } 
                    }
                    $sqlVals += "'$($dt.ToString('yyyy-MM-dd'))'"
                }
                "NUMERIC" {
                    $n   = $raw -replace '[^\d\.\-]', ''
                    $dec = if ($n) { [math]::Round([decimal]$n,2) } else { 0 }
                    $sqlVals += $dec.ToString("F2",[Globalization.CultureInfo]::InvariantCulture)
                }
                default {
                    $s = $raw -replace "'","''"
                    $sqlVals += "'$s'"
                }
            }
        }
        $insSql = "INSERT INTO dbo.$tableName ($columnList) VALUES (" + ($sqlVals -join ", ") + ")"
        $icmd   = $dc.CreateCommand(); $icmd.CommandText = $insSql
        try {
            [void]$icmd.ExecuteNonQuery(); $inserted++
        } catch {
            if ($_.Exception.Message -match 'duplicate') { $skipped++ }
            else { Log-Message "ERROR inserting row ${i}: $_" }
        }
    }
    $dc.Close()
    Log-Message "Imported ${csvName}: inserted $inserted, skipped $skipped."

    # ----------------------------------------------------------------
    # Ensure Year/Month columns & populate
    $alter = @"
IF NOT EXISTS (
  SELECT 1 FROM sys.columns
   WHERE object_id = OBJECT_ID(N'dbo.$tableName')
     AND name = 'Year'
)
BEGIN
  ALTER TABLE dbo.$tableName ADD Year INT NULL, Month INT NULL;
END
"@
    $ac   = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $acmd = $ac.CreateCommand(); $acmd.CommandText = $alter
    $ac.Open(); [void]$acmd.ExecuteNonQuery()
    $acmd.CommandText = "UPDATE dbo.$tableName SET Year = YEAR([Date]), Month = MONTH([Date]);"
    [void]$acmd.ExecuteNonQuery(); $ac.Close()
    Log-Message "Year/Month ensured & populated."

    # ----------------------------------------------------------------
    # Record this import’s timestamp
    $merge = @"
MERGE dbo.CsvImportLog AS T
USING (SELECT N'$csvName' AS FileName, '$lastWrite' AS LastWriteTime) AS S
  ON T.FileName = S.FileName
WHEN MATCHED THEN
  UPDATE SET LastWriteTime = S.LastWriteTime
WHEN NOT MATCHED THEN
  INSERT (FileName,LastWriteTime) VALUES (S.FileName,S.LastWriteTime);
"@
    $lc   = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $lcmd = $lc.CreateCommand(); $lcmd.CommandText = $merge
    $lc.Open(); [void]$lcmd.ExecuteNonQuery(); $lc.Close()
    Log-Message "Logged timestamp for $csvName."
}