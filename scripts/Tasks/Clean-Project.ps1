# $ScriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
# . "$ScriptRoot\utils\Common.ps1"

function Clean-Project {
    param(
        [PSCustomObject]$project,
        [bool]$deleteBin,
        [bool]$deleteObj,
        [string]$configuration
    )

    $ProjectDirectory = Split-Path $project.ProjectFile -Parent
    Write-Host $ProjectDirectory
    if (-not (Test-Path $ProjectDirectory)) {
        throw "Project directory not found: $ProjectDirectory"
    }

    if ($deleteBin) {

        Run-Step "Delete bin" {

            Get-ChildItem `
                -Path $ProjectDirectory `
                -Directory `
                -Recurse `
                -Filter bin |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction Stop
        }
    }

    if ($deleteObj) {

        Run-Step "Delete obj" {

            Get-ChildItem `
                -Path $ProjectDirectory `
                -Directory `
                -Recurse `
                -Filter obj |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction Stop
        }
    }

    Run-Step "Clean" {

        $output = dotnet clean `
            $project.ProjectFile `
            -c $configuration 2>&1

        if ($LASTEXITCODE -ne 0) {
            $output
            throw "Clean failed."
        }
    }
}