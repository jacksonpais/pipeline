param(
    [Parameter(Mandatory = $true)]
    [Alias("path")]
    [string]$ConfigPath
)

#------------------------------------------------------------
# Validate Config
#------------------------------------------------------------

if (!(Test-Path $ConfigPath)) {
    Write-Host ""
    Write-Host "Configuration file not found." -ForegroundColor Red
    Write-Host $ConfigPath -ForegroundColor Yellow
    exit 1
}

#------------------------------------------------------------
# Read Configuration
#------------------------------------------------------------

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$RepositoryRoot = $config.Repository.Root
$RepositoryName = $config.Repository.Name
$PackageId      = $config.Repository.PackageId

$Configuration = $config.Build.Configuration
$CleanBinObj   = $config.Build.CleanBinObj
$DoRestore     = $config.Build.Restore
$DoBuild       = $config.Build.Build
$DoPack        = $config.Build.Pack

$NugetFeed = $config.NuGet.OutputFolder

#------------------------------------------------------------
# Build Paths
#------------------------------------------------------------

$RepositoryPath = Join-Path $RepositoryRoot $RepositoryName

if (!(Test-Path $RepositoryPath)) {
    Write-Host ""
    Write-Host "Repository not found." -ForegroundColor Red
    Write-Host $RepositoryPath -ForegroundColor Yellow
    exit 1
}

#------------------------------------------------------------
# Locate Solution Automatically
#------------------------------------------------------------

$Solution = Get-ChildItem `
    -Path $RepositoryPath `
    -Filter *.sln `
    -Recurse |
    Select-Object -First 1

if ($null -eq $Solution) {
    Write-Host ""
    Write-Host "No solution (.sln) found." -ForegroundColor Red
    exit 1
}

$SolutionFolder = $Solution.Directory.FullName

Set-Location $SolutionFolder

#------------------------------------------------------------
# Ensure NuGet Feed Exists
#------------------------------------------------------------

if (!(Test-Path $NugetFeed)) {
    New-Item `
        -ItemType Directory `
        -Path $NugetFeed | Out-Null
}

#------------------------------------------------------------
# Helper
#------------------------------------------------------------

function Run-Step {

    param(
        [string]$Title,
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    & $Action

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "$Title FAILED" -ForegroundColor Red
        exit 1
    }

    Write-Host "SUCCESS" -ForegroundColor Green
}

#------------------------------------------------------------
# Clean
#------------------------------------------------------------

Run-Step "Cleaning Solution" {

    dotnet clean
}

#------------------------------------------------------------
# Delete bin / obj
#------------------------------------------------------------

if ($CleanBinObj) {

    Run-Step "Deleting bin / obj folders" {

        Get-ChildItem `
            -Path $RepositoryPath `
            -Directory `
            -Recurse `
            -Include bin,obj |
            Remove-Item `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

#------------------------------------------------------------
# Restore
#------------------------------------------------------------

if ($DoRestore) {

    Run-Step "Restoring Packages" {

        dotnet restore
    }
}

#------------------------------------------------------------
# Build
#------------------------------------------------------------

if ($DoBuild) {

    Run-Step "Building Solution" {

        dotnet build `
            -c $Configuration `
            --no-restore
    }
}

#------------------------------------------------------------
# Pack
#------------------------------------------------------------

if ($DoPack) {

    Run-Step "Packing NuGet Packages" {

        dotnet pack `
            -c $Configuration `
            --no-build `
            -o $NugetFeed
    }
}

#------------------------------------------------------------
# Verify Package
#------------------------------------------------------------

Run-Step "Verifying Package" {

    $Packages = Get-ChildItem `
        -Path $NugetFeed `
        -Filter "$PackageId*.nupkg"

    if ($Packages.Count -eq 0) {
        throw "Package not created."
    }

    Write-Host ""
    Write-Host "Package(s) Created:" -ForegroundColor Green

    foreach ($Package in $Packages) {
        Write-Host "  $($Package.Name)"
    }
}

#------------------------------------------------------------
# Completed
#------------------------------------------------------------

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " BUILD COMPLETED SUCCESSFULLY " -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green