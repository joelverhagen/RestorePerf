Param(
    [int] $iterationCount = 20,
    [string] $variantName,
    [string] $solutionName
)

. "$PSScriptRoot\scripts\perftests\PerformanceTestUtilities.ps1"

if ($variantName -and !$solutionName) {
    throw "The -solutionName parameter is required when using the -variantName parameter."
}

if ($solutionName) {
    if ($variantName) {
        $restoreLogPattern = "restoreLog-$variantName-$solutionName-*.txt"
    } else {
        $restoreLogPattern = "restoreLog-$solutionName-*.txt"
    }
} else {
    $restoreLogPattern = "restoreLog-*-*.txt"
}

$restoreLogPattern = Join-Path $PSScriptRoot "out\all-logs\$restoreLogPattern"
$allLogs = Get-ChildItem $restoreLogPattern `
    | Sort-Object -Property Name

if (!$allLogs) {
    throw "No restore logs were found with pattern: $restoreLogPattern"
}

Log "$($allLogs.Count) restore logs were found:"
foreach ($log in $allLogs) {
    Log "- $($log.FullName)"
}

$logsDir = Join-Path $PSScriptRoot "out\logs"
if (Test-Path $logsDir) {
    Remove-Item $logsDir -Force -Recurse -Confirm
}

$requestGraphsDir = Join-Path $PSScriptRoot "out\request-graphs"
if (Test-Path $requestGraphsDir) {
    Remove-Item $requestGraphsDir -Force -Recurse -Confirm
}

for ($logCount = 1; $logCount -le $allLogs.Count; $logCount++) {
    Log "Starting the test with $logCount log(s), $iterationCount iteration(s)" "Cyan"

    if (Test-Path $logsDir) {
        Remove-Item $logsDir -Force -Recurse
    }
    
    New-Item $logsDir -Type Directory | Out-Null

    $allLogs `
        | Select-Object -First $logCount `
        | ForEach-Object { Copy-Item $_ (Join-Path $logsDir $_.Name) }
    
    Log "Parsing the restore log(s)." "Green"
    dotnet run parse-restore-logs `
        --project (Join-Path $PSScriptRoot "src\PackageHelper\PackageHelper.csproj")
    
    if ($solutionName) {
        if ($variantName) {
            $requestGraphPath = Join-Path $requestGraphsDir "requestGraph-$variantName-$solutionName.json.gz"
        } else {
            $requestGraphPath = Join-Path $requestGraphsDir "requestGraph-$solutionName.json.gz"
        }
    } else {
        $requestGraphPath = Get-ChildItem (Join-Path $requestGraphsDir "requestGraph-*.json.gz") `
            | Sort-Object -Property Name `
            | Select-Object -First 1 -Property FullName
    }

    Log "Replaying the request graph." "Green"
    dotnet run replay-request-graph `
        $requestGraphPath.FullName $iterationCount `
        --project (Join-Path $PSScriptRoot "src\PackageHelper\PackageHelper.csproj")

    Log "Finished the test with $logCount log(s), $iterationCount iteration(s)" "Cyan"
}
