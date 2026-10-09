Clear-Host

$Models = @(
    "opencode/space-bunny-free"
    "opencode/longcat-2.5-preview-free"
    "opencode/fledge-alpha-free"
    "opencode/mimo-v2.6-flash-free"
    "opencode/mimo-v2.5-free"
    "opencode/ling-3.1-flash-free"
    "opencode/ling-3.0-flash-fin-free"
    "opencode/nemotron-3-ultra-free"
    "opencode/nemotron-3.5-lightning-free"
    "opencode/muse-spark-1.3-contributor-free"
)

$Results = foreach ($Model in $Models) {

    $Output = & opencode run --model $Model "Respond only with OK" 2>&1 | Out-String

    if ($LASTEXITCODE -eq 0) {
        $Estado = "OK"
    }
    elseif ($Output -match "Rate limit") {
        $Estado = "RATE LIMIT"
    }
    elseif ($Output -match "Model unavailable") {
        $Estado = "UNAVAILABLE"
    }
    else {
        $Estado = "ERROR"
    }

    [pscustomobject]@{ Modelo = $Model; Estado = $Estado }
}

$Results | Format-Table -AutoSize