param(
  [Parameter(Mandatory = $true)]
  [string]$DeviceId,

  [int]$Runs = 30,

  [string]$RunIdPrefix = '',

  [string]$ExportDir = 'testing/perf_exports',

  [string]$CsvOut = 'testing/perf_runs.csv'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ExportDir)) {
  New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null
}

$pythonExe = 'c:/Users/sherl/Desktop/Comp/Apps/MakeUp/.venv/Scripts/python.exe'

for ($i = 1; $i -le $Runs; $i++) {
  if ($RunIdPrefix) {
    $runLabel = '{0}_{1:D3}' -f $RunIdPrefix, $i
  } else {
    $runLabel = ('{0:D3}' -f $i)
  }
  $env:PERF_RUN_ID = $runLabel
  $env:PERF_OUT_DIR = $ExportDir

  Write-Host "===== Run $runLabel / $Runs ====="

  flutter drive `
    --driver=test_driver/perf_driver.dart `
    --target=integration_test/perf_flow_test.dart `
    --no-dds `
    --profile `
    -d $DeviceId `
    --dart-define=PERF_RUN_ID=$runLabel

  $jsonPath = Join-Path $ExportDir "perf_run_$runLabel.json"
  if (-not (Test-Path $jsonPath)) {
    throw "Expected export not found: $jsonPath"
  }

  & $pythonExe testing/testreading.py $jsonPath --csv $CsvOut --label "run_$runLabel"
}

Write-Host "Done. Exports: $ExportDir"
Write-Host "CSV: $CsvOut"
