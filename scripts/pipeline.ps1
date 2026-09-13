param(
    [string]$Action,
    [string]$Path = (Get-Location).Path
)

$ScriptRoot = Split-Path $PSScriptRoot -Parent

. "$ScriptRoot\scripts\Run-Action.ps1"
. "$ScriptRoot\utils\Common.ps1"

switch -CaseSensitive ($Action) {

    "scan" {

        Run-Action `
            -ActionName $Action `
            -Path $Path
    }

    "clean" {

        Run-Action `
            -ActionName $Action `
            -Path $Path
    }

    "restore" {

        Run-Action `
            -ActionName $Action `
            -Path $Path
    }

    "build" {

        Run-Action `
            -ActionName $Action `
            -Path $Path
    }

    "pack" {

        Run-Action `
            -ActionName $Action `
            -Path $Path
    }

    default {

        Write-ErrorMessage "Unknown action: $Action"
        Write-Host ""
        Write-Host "Available actions:"
        Write-Host "  scan"
        Write-Host "  clean"
        Write-Host "  restore"
        Write-Host "  build"
        Write-Host "  pack"

        exit 1
    }
}