$ErrorActionPreference = 'Stop'
$qaRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $qaRoot
try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter is not on PATH. Use your existing Flutter SDK; this runner does not install tools.'
    }
    if (-not (Test-Path -LiteralPath '.dart_tool/package_config.json')) {
        throw 'Existing dependencies are required (.dart_tool/package_config.json missing). No dependencies were installed.'
    }
    $qaResults = Join-Path $PSScriptRoot 'results'
    New-Item -ItemType Directory -Path $qaResults -Force | Out-Null
    # Clear only known generated result files so an interrupted run cannot
    # accidentally present an older suite's PASS as a current result.
    foreach ($qaName in @('campaign.json', 'campaign.md', 'screen_fit.json',
            'endless_validity.json', 'endless_solver.json', 'run.json', 'run.log')) {
        $qaPath = Join-Path $qaResults $qaName
        if (Test-Path -LiteralPath $qaPath) { Remove-Item -LiteralPath $qaPath }
    }
    $qaStarted = [DateTime]::UtcNow.ToString('o')
    $qaInputs = @(Get-ChildItem -LiteralPath 'assets/levels', 'lib', 'test/qa' -File -Recurse)
    $qaInputs += Get-Item -LiteralPath 'pubspec.yaml', 'pubspec.lock', 'tool/generate_mixed_level_layouts.dart'
    $qaHashes = @($qaInputs | Sort-Object FullName | ForEach-Object {
        @{ path = $_.FullName.Substring($qaRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    # Host unit/widget tests only. No APK, emulator, ADB, pub get or installation.
    try {
        # Windows PowerShell treats redirected native stderr as ErrorRecords.
        # Test failures must still reach the manifest and return their exit code.
        $ErrorActionPreference = 'Continue'
        & flutter test --no-pub --concurrency=1 --reporter=expanded test/qa 2>&1 |
            Tee-Object -FilePath (Join-Path $qaResults 'run.log') -ErrorAction Stop
        $qaExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = 'Stop'
    }
    @{ startedUtc = $qaStarted; finishedUtc = [DateTime]::UtcNow.ToString('o');
       exitCode = $qaExit; command = 'flutter test --no-pub --concurrency=1 --reporter=expanded test/qa';
       inputs = $qaHashes } | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $qaResults 'run.json') -Encoding UTF8
    Write-Host "QA exit code: $qaExit. Details: qa/results/run.log and suite JSON reports."
    Write-Host 'UNKNOWN solver results remain inconclusive even if the process exits successfully.'
    exit $qaExit
} finally {
    Pop-Location
}
