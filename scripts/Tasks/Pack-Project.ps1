$ScriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

. "$ScriptRoot\utils\Common.ps1"

function Pack-Project {
    param(
        [PSCustomObject]$project,
        [string]$configuration
    )

    Run-Step "Pack" {

        $output = dotnet pack `
            $project.ProjectFile `
            -c $configuration `
            --no-build `
            -o $NugetFeed

        if ($LASTEXITCODE -ne 0) {
            $output
            throw "Pack failed."
        }        
    }
}

function Pack-Summary{
    param(
        [array]$CreatedPackages, 
        [bool]$verify
    )

    if ($verify) {

        Write-Host ""
        Write-Host "Package(s) Created" -ForegroundColor Green
        Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

        foreach ($package in $CreatedPackages) {
            Write-Host ("  {0,-45}" -f $package.BaseName)
        }

        Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

        Write-Host ""
        Write-Host "NuGet Feed : $NugetFeed"
    }   

    Success-Summary `
        -Message "PACKAGE CREATED SUCCESSFULLY"
    
}