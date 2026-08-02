param(
    [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

#------------------------------------------------------------
# Load Pipeline Utilities
#------------------------------------------------------------

$ScriptRoot = Split-Path $PSScriptRoot -Parent

. "$ScriptRoot\utils\Common.ps1"
. "$ScriptRoot\utils\Utils.ps1"
. "$ScriptRoot\utils\MSBuild.ps1"
. "$ScriptRoot\utils\Graph.ps1"

#------------------------------------------------------------
# Resolve Root
#------------------------------------------------------------

$RootPath = (Resolve-Path $Path).Path

Write-Step "Scanning Repository"

Write-Info "Root: $RootPath"

#------------------------------------------------------------
# Find Solution
#------------------------------------------------------------

$Solution = Find-Solution -RootPath $RootPath

if ($null -eq $Solution) {

    Write-ErrorMessage "No solution found."

    exit 1
}

$SolutionPath = $Solution.FullName
$SolutionDirectory = $Solution.DirectoryName

$SolutionName = [System.IO.Path]::GetFileNameWithoutExtension(
    $Solution.Name
)

Write-Info "Solution: $SolutionName"
Write-Info "File: $SolutionPath"

#------------------------------------------------------------
# Find Directory.Build.props
#------------------------------------------------------------

$PropsFile = Join-Path `
    $SolutionDirectory `
    "Directory.Build.props"

$UseProjectReferenceValue = Get-PropsProperty `
    -PropsFile $PropsFile `
    -PropertyName "UseProjectReference" `
    -DefaultValue "false"

$UseProjectReference =
$UseProjectReferenceValue.ToString().Trim().ToLower() -eq "true"

Write-Info "UseProjectReference: $UseProjectReference"

#------------------------------------------------------------
# Get Configuration
#------------------------------------------------------------

$Configuration = Get-PropsProperty `
    -PropsFile $PropsFile `
    -PropertyName "Configuration" `
    -DefaultValue "Release"

Write-Info "Configuration: $Configuration"

#------------------------------------------------------------
# Read Solution Projects
#------------------------------------------------------------

$ProjectFiles = Get-SolutionProjects `
    -SolutionFile $SolutionPath

if ($ProjectFiles.Count -eq 0) {

    Write-ErrorMessage "No projects found in solution."

    exit 1
}

Write-Info "Projects found: $($ProjectFiles.Count)"

#------------------------------------------------------------
# Create Initial Project Metadata
#------------------------------------------------------------

$Projects = @()

foreach ($projectFile in $ProjectFiles) {

    $projectName =
    [System.IO.Path]::GetFileNameWithoutExtension(
        $projectFile
    )

    $packageId = Get-ProjectPackageId `
        -ProjectFile $projectFile

    $version = Get-ProjectVersion `
        -ProjectFile $projectFile

    $Projects += [PSCustomObject]@{
        Name         = $projectName
        File         = [System.IO.Path]::GetFullPath($projectFile)
        PackageId    = $packageId
        Version      = $version
        Type         = "SolutionProject"
        Dependencies = @()
    }
}

#------------------------------------------------------------
# External Packages
#------------------------------------------------------------

$ExternalPackages = @()

#------------------------------------------------------------
# Build Complete Dependency Graph
#------------------------------------------------------------

$Projects = Build-DependencyGraph `
    -Projects $Projects `
    -UseProjectReference $UseProjectReference `
    -RootSolutionDirectory $SolutionDirectory `
    -ExternalPackages ([ref]$ExternalPackages)

#------------------------------------------------------------
# Sort Projects
#------------------------------------------------------------

$Projects = @(
    $Projects |
    Sort-Object Name
)

#------------------------------------------------------------
# BuildConfig.json
#------------------------------------------------------------

$BuildConfig = [ordered]@{

    GeneratedAt = (Get-Date).ToString("o")

    Solution    = [ordered]@{
        Name      = $SolutionName
        File      = $SolutionPath
        Directory = $SolutionDirectory
    }

    Build       = [ordered]@{
        UseProjectReference = $UseProjectReference
        Configuration       = $Configuration
    }

    Source      = [ordered]@{
        DirectoryBuildProps = $PropsFile
    }

    Projects    = @($Projects)
}

#------------------------------------------------------------
# Determine Repository Root
#------------------------------------------------------------

$RepositoryRoot = Split-Path `
    $SolutionDirectory `
    -Parent

#------------------------------------------------------------
# BuildConfig Location
#------------------------------------------------------------

$PipelineDirectory = Join-Path `
    $RepositoryRoot `
    "pipeline"

if (!(Test-Path $PipelineDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $PipelineDirectory |
    Out-Null
}

$BuildConfigPath = Join-Path `
    $PipelineDirectory `
    "BuildConfig.json"

$BuildConfig |
ConvertTo-Json -Depth 30 |
Set-Content `
    -Path $BuildConfigPath `
    -Encoding UTF8

#------------------------------------------------------------
# Package.json
#------------------------------------------------------------

$PackageProjects = @()

foreach ($project in $Projects) {

    $PackageProjects += [PSCustomObject]@{

        Name         = $project.Name
        PackageId    = $project.PackageId
        ProjectFile  = $project.File
        Dependencies = @($project.Dependencies)
    }
}

$PackageConfig = [ordered]@{

    GeneratedAt         = (Get-Date).ToString("o")
    Solution            = $SolutionName
    UseProjectReference = $UseProjectReference

    Packages            = @(
        $PackageProjects
    )

    ExternalPackages    = @(
        $ExternalPackages |
        Sort-Object PackageId
    )
}

$PackageConfigPath = Join-Path `
    $RepositoryRoot `
    "Package.json"

$PackageConfig |
ConvertTo-Json -Depth 30 |
Set-Content `
    -Path $PackageConfigPath `
    -Encoding UTF8

#------------------------------------------------------------
# Summary
#------------------------------------------------------------

Write-Step "Scan Complete"

Write-Success "BuildConfig : $BuildConfigPath"
Write-Success "Package     : $PackageConfigPath"

Write-Host ""
Write-Host "Projects discovered : $($Projects.Count)" `
    -ForegroundColor Green

Write-Host "External packages    : $($ExternalPackages.Count)" `
    -ForegroundColor Green