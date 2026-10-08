$Models = @(
    "opencode/jev-1.13-free"
    "opencode/space-bunny-free"
    "opencode/longcat-2.5-preview-free"
    "opencode/exo-free"
    "opencode/fledge-alpha-free"
    "opencode/mimo-v2.6-flash-free"
    "opencode/mimo-v2.5-free"
    "opencode/ling-3.1-flash-free"
    "opencode/ling-3.0-flash-fin-free"
    "opencode/nemotron-3-ultra-free"
    "opencode/nemotron-3.5-lightning-free"
    "opencode/muse-spark-1.3-contributor-free"
)

foreach ($Model in $Models) {

    $Output = & opencode run --model $Model "Respond only with OK" 2>&1 | Out-String

    if ($LASTEXITCODE -eq 0) {
        Write-Host "$Model : OK" -ForegroundColor Green

        # Abrir OpenCode con el modelo que funcionó
        & opencode run --model $Model

        exit 0
    }

    if ($Output -match "Rate limit") {
        Write-Host "$Model : RATE LIMIT" -ForegroundColor Yellow
    }
    elseif ($Output -match "Model unavailable") {
        Write-Host "$Model : UNAVAILABLE" -ForegroundColor Red
    }
    else {
        Write-Host "$Model : ERROR" -ForegroundColor Red
    }
}

Write-Host "No hay modelos Free disponibles." -ForegroundColor Red