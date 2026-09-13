$ScriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

. "$ScriptRoot\utils\Common.ps1"

function Build-Project {
    param(
        [PSCustomObject]$project
    )

    Run-Step "Build" {

        $output = dotnet build `
            $project.ProjectFile `
            -c $Configuration `
            --no-restore

        if ($LASTEXITCODE -ne 0) {
            $output
            throw "Build failed."
        }
    }
}