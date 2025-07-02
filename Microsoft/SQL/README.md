![Static Badge](https://img.shields.io/badge/license-MIT-blue) ![Static Badge](https://img.shields.io/badge/build-passing-brightgreen)
# Pivot CSV Importer

A PowerShell utility to incrementally import “pivot” CSV files into SQL Server (default or SQLEXPRESS) tables.  
Tracks processed files in a metadata table (`CsvImportLog`) and only re‐imports new or changed CSVs, preventing duplicate data.

## Features

- **Auto-detect SQL Instance**  
  Chooses between default `MSSQLSERVER` and `SQLEXPRESS` based on running Windows services.

- **Database & Metadata Table Bootstrap**  
  Uses SMO to create the target database if missing, and T-SQL to create a `CsvImportLog` tracking table.

- **Incremental Imports**  
  - On first run: drops any existing pivot tables, then imports all CSVs.  
  - On subsequent runs: skips unchanged files, deletes only the affected year’s rows for updated CSVs, and re-inserts.

- **Schema Discovery**  
  Infers data types from column names:  
  - `amount_EUR`, `ICBO_EUR`, `Cost_EUR` → `NUMERIC(18,2)`  
  - `Billed_hours`, `All_hours` → `NUMERIC(18,2)`  
  - Columns containing “date” → `DATE`  
  - Others → `NVARCHAR(MAX)`

- **Progress & Logging**  
  - Displays a `Write-Progress` bar in the console.  
  - Writes timestamped messages to both console and a log file.

- **Automatic Year/Month Columns**  
  Ensures each pivot table has `Year` and `Month` columns populated from the `[Date]` field.

---

## Prerequisites

- **PowerShell 5.1+** or PowerShell Core on Windows  
- **SQL Server** (default or SQLEXPRESS) installed and running on the local machine  
- **.NET** and **SMO libraries** (included with SQL Server Management Tools)  

---

## Installation

1. Clone or download this repository:  
```bash
git clone https://github.com/your-org/pivot-csv-importer.git
cd pivot-csv-importer
````

2. (Optional) Adjust your execution policy if needed:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

---

## Configuration

Edit the top of the script to set your environment:

```powershell
# Where your pivot CSVs live
$csvFolder        = "C:\Scripts\CSV"

# Target SQL Server instance will be auto-detected.
# Optionally override:
# $server         = "localhost\SQLEXPRESS"

# Target database name (will be created if missing)
$database         = "BrianDatabase"

# Path to your import log
$logFile          = "C:\Scripts\import_log.txt"

# Connection string built from $server and $database
$connectionString = "Server=$server;Database=$database;Trusted_Connection=True;"
```

---

## Usage

Run the script from PowerShell:

```powershell
.\Import-PivotCSVs.ps1
```

* **First run**: Drops and recreates any existing pivot tables, then imports all CSV files named `*pivot*.csv`.
* **Subsequent runs**:

  * Skips files whose timestamp hasn’t changed.
  * For changed CSVs, deletes only the old rows for that file’s year and re-inserts the updated data.

---

## Examples

```powershell
# Run with default settings
.\Import-PivotCSVs.ps1

# If you want verbose console output:
.\Import-PivotCSVs.ps1 -Verbose

# If you want to run this from a PowerShell Command Line:
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Import-PivotCSVs.ps1"
```

---

## Log File

All operations are logged with timestamps to the file specified by `$logFile`, for example:

```
2025-06-29 10:00:00 - Using SQL Express instance on MYMACHINE\SQLEXPRESS
2025-06-29 10:00:01 - CsvImportLog is empty → initial run: tables will be dropped before import.
2025-06-29 10:00:01 - Checking DK_Sales_pivot.csv → table: Sales_pivot
2025-06-29 10:00:02 - Created database [BrianDatabase] via SMO.
...
2025-06-29 10:05:30 - Imported DK_Sales_pivot.csv: inserted 1200, skipped 0.
```

---

## License

[MIT License](LICENSE)
