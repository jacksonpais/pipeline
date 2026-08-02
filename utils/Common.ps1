function Write-Step {

    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Write-Info {

    param(
        [string]$Message
    )

    Write-Host "  $Message" -ForegroundColor Gray
}

function Write-Success {

    param(
        [string]$Message
    )

    Write-Host "  $Message" -ForegroundColor Green
}

function Write-WarningMessage {

    param(
        [string]$Message
    )

    Write-Host "  $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {

    param(
        [string]$Message
    )

    Write-Host "  $Message" -ForegroundColor Red
}