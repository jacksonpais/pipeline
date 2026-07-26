param(
    [Parameter(Mandatory = $true)]
    [Alias("path")]
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

#------------------------------------------------------------
# Helper
#------------------------------------------------------------

function Run-Step {

    param(
        [string]$Title,
        [scriptblock]$Action
    )

    $Prefix = "  {0,-35}" -f $Title

    # Show initial status
    Write-Host -NoNewline "$Prefix [....]"

    try {

        & $Action

        if ($LASTEXITCODE -ne 0) {
            throw "Command failed."
        }

        # Return to beginning of line
        Write-Host -NoNewline "`r"

        # Rewrite complete line
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

function Get-MSBuildProperty {

    param(
        [string]$Project,
        [string]$Property
    )

    $value = dotnet msbuild `
        $Project `
        "-getProperty:$Property" 2>$null

    # MSBuild command failed
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $value = $value.Trim()

    # Property not defined
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value
}

function Get-PropsProperty {

    param(
        [string]$PropsFile,
        [string]$PropertyName,
        [string]$DefaultValue = $null
    )

    # File not found
    if (!(Test-Path $PropsFile)) {
        return $DefaultValue
    }

    try {

        [xml]$xml = Get-Content $PropsFile

        foreach ($group in $xml.Project.PropertyGroup) {

            $node = $group.SelectSingleNode($PropertyName)

            if ($null -ne $node -and
                ![string]::IsNullOrWhiteSpace($node.InnerText)) {

                return $node.InnerText.Trim()
            }
        }

        return $DefaultValue
    }
    catch {

        return $DefaultValue
    }
}

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

$CreatedPackages = @()

$Configuration = $config.Build.Configuration
$DoClean = $config.Build.Clean
$DeleteBin = $config.Build.DeleteBin
$DeleteObj = $config.Build.DeleteObj
$DoPack = $config.Build.Pack

$NugetFeed = $config.NuGet.OutputFolder

foreach ($project in $config.Repository.Projects) {
    $RepositoryName = $project.Name
    $SolutionName = $project.Solution
    $ProjectFile = $project.ProjectFile
    $PackageId = $project.PackageId

    Write-Host ""
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "Repository : $RepositoryName"      
    Write-Host "Solution   : $SolutionName" 
    Write-Host "Package    : $PackageId"
    Write-Host "Project    : $(Split-Path $ProjectFile -Leaf)"
    Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

    #------------------------------------------------------------
    # Build Paths
    #------------------------------------------------------------

    $RepositoryPath = Join-Path $RepositoryRoot $RepositoryName
    $SolutionPath = Join-Path $RepositoryPath $SolutionName

    if (!(Test-Path $RepositoryPath)) {
        Write-Host ""
        Write-Host "Repository not found." -ForegroundColor Red
        Write-Host $RepositoryPath -ForegroundColor Yellow
        exit 1
    }

    $Solution = Get-ChildItem `
        -Path $RepositoryPath `
        -Filter *.sln `
        -Recurse |
    Select-Object -First 1

    if ($null -eq $Solution) {
        Write-Host ""
        Write-Host "Solution file not found." -ForegroundColor Red
        exit 1
    }

    $ProjectPath = Join-Path $SolutionPath $ProjectFile

    if (!(Test-Path $ProjectPath)) {
        Write-Host ""
        Write-Host "Project file not found." -ForegroundColor Red
        exit 1
    }

    $PropsFile = Join-Path $SolutionPath "Directory.Build.props"

    # $UseProjectReference = Get-PropsProperty `
    #     -PropsFile $PropsFile `
    #     -PropertyName "UseProjectReference" `
    #     -DefaultValue "Local"

    if (!(Test-Path $NugetFeed)) {
        New-Item `
            -ItemType Directory `
            -Path $NugetFeed | Out-Null
    }

    #------------------------------------------------------------
    # Decide Build Target
    #------------------------------------------------------------

    $BuildTarget = $ProjectPath

    #------------------------------------------------------------
    # Clean
    #------------------------------------------------------------

    if ($DoClean) {
        Run-Step "Clean" {

            $output = dotnet clean `
                $BuildTarget `
                -c $Configuration 2>&1

            if ($LASTEXITCODE -ne 0) {
                $output
                throw "Clean failed."
            }
        }
    }

    #------------------------------------------------------------
    # Delete bin
    #------------------------------------------------------------

    if ($DeleteBin) {

        Run-Step "Delete bin" {

            Get-ChildItem `
                -Path $RepositoryPath `
                -Directory `
                -Recurse `
                -Filter bin |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    #------------------------------------------------------------
    # Delete obj
    #------------------------------------------------------------

    if ($DeleteObj) {

        Run-Step "Delete obj" {

            Get-ChildItem `
                -Path $RepositoryPath `
                -Directory `
                -Recurse `
                -Filter obj |
            Remove-Item `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    #------------------------------------------------------------
    # Restore
    #------------------------------------------------------------

    Run-Step "Restore" {

        $output = dotnet restore `
            $BuildTarget

        if ($LASTEXITCODE -ne 0) {
            $output
            throw "Restore failed."
        }

    }

    #------------------------------------------------------------
    # Build
    #------------------------------------------------------------


    Run-Step "Build" {

        $output = dotnet build `
            $BuildTarget `
            -c $Configuration `
            --no-restore

        if ($LASTEXITCODE -ne 0) {
            $output
            throw "Build failed."
        }           
    }

    #------------------------------------------------------------
    # Pack
    #------------------------------------------------------------

    if ($DoPack) {

        Run-Step "Pack" {

            $output = dotnet pack `
                $ProjectPath `
                -c $Configuration `
                --no-build `
                -o $NugetFeed

            if ($LASTEXITCODE -ne 0) {
                $output
                throw "Pack failed."
            }               
        }
    }

    #------------------------------------------------------------
    # Verify Package
    #------------------------------------------------------------

    $package = Run-Step "Verify" {

        Get-ChildItem `
            -Path $NugetFeed `
            -Filter "$PackageId*.nupkg" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    }

    $CreatedPackages += $package
}

#------------------------------------------------------------
# Summary
#------------------------------------------------------------
Write-Host ""
Write-Host "Package(s) Created" -ForegroundColor Green
Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

foreach ($package in $CreatedPackages) {
    Write-Host ("  {0,-45}" -f $package.BaseName)
}

Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "NuGet Feed : $NugetFeed"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " PACKAGE CREATED SUCCESSFULLY " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green