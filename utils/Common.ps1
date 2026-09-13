function Write-Step {

    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Write-Success {

    param(
        [string]$Message
    )

    Write-Success "  $Message" -ForegroundColor Green
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

function Run-Step {

    param(
        [string]$Title,
        [scriptblock]$Action
    )

    $Prefix = "  {0,-35}" -f $Title

    Write-Host -NoNewline "$Prefix [....]"

    try {

        & $Action

        Write-Host -NoNewline "`r"
        Write-Host "$Prefix [ OK ]" -ForegroundColor Green
    }
    catch {

        Write-Host -NoNewline "`r"
        Write-Host "$Prefix [FAIL]" -ForegroundColor Red

        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red

        exit 1
    }
}

function Success-Summary {

    param(
        [string]$Message
    )
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " $Message " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}