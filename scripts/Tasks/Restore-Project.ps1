$ScriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

. "$ScriptRoot\utils\Common.ps1"

function Restore-Project {
    param(
        [PSCustomObject]$project
    )

    Run-Step "Restore" {

        $output = dotnet restore `
            $project.ProjectFile

        if ($LASTEXITCODE -ne 0) {
            $output
            throw "Restore failed."
        }
    }
}