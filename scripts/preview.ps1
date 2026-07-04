param(
  [int]$Port = 4000,
  [switch]$NoBuild,
  [switch]$NoOpen
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Image = "ghcr.io/actions/jekyll-build-pages:latest"

Push-Location $Root
try {
  if (-not $NoBuild) {
    docker image inspect $Image *> $null
    if ($LASTEXITCODE -ne 0) {
      docker pull $Image
    }

    docker run --rm `
      -e JEKYLL_NO_BUNDLER_REQUIRE=true `
      -v "${Root}:/workspace" `
      -w /workspace `
      --entrypoint sh `
      $Image `
      -lc "/usr/local/bundle/bin/jekyll build --source /workspace --destination /workspace/_site --config /workspace/_config.yml,/workspace/_config_docker.yml"
  }

  $PythonCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Python\pythoncore-3.14-64\python.exe"),
    (Join-Path $env:LOCALAPPDATA "Python\bin\python.exe")
  )
  $Python = $PythonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

  if (-not $Python) {
    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($PythonCommand) {
      $Python = $PythonCommand.Source
    }
  }

  if (-not $Python) {
    throw "Python was not found. Build succeeded, but the preview server could not be started."
  }

  $Existing = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    Where-Object { $_.State -eq "Listen" } |
    Select-Object -First 1

  if (-not $Existing) {
    Start-Process `
      -FilePath $Python `
      -ArgumentList "-m http.server $Port --bind 127.0.0.1 --directory _site" `
      -WorkingDirectory $Root `
      -WindowStyle Hidden
    Start-Sleep -Seconds 1
  }

  $Url = "http://127.0.0.1:$Port/"
  Write-Host "Preview: $Url"

  if (-not $NoOpen) {
    Start-Process $Url
  }
}
finally {
  Pop-Location
}
