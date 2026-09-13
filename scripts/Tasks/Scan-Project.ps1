#------------------------------------------------------------
# Load Pipeline Utilities
#------------------------------------------------------------

$ScriptRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

. "$ScriptRoot\utils\Common.ps1"
. "$ScriptRoot\utils\Utils.ps1"
. "$ScriptRoot\utils\MSBuild.ps1"

function Scan-Project {
    param(
        [string]$Path = (Get-Location).Path
    )

    $ErrorActionPreference = "Stop"

    #------------------------------------------------------------
    # Resolve Root
    #------------------------------------------------------------

    $RootPath = (Resolve-Path $Path).Path

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

    # ============================================================
    # Directory.Build.props
    # ============================================================

    $directoryBuildProps = Join-Path `
        $solutionDirectory `
        "Directory.Build.props"

    if (-not (Test-Path $directoryBuildProps)) {
        $directoryBuildProps = $null
    }

    $directoryBuildPropsXml = Read-DirectoryBuildProps `
        -File $directoryBuildProps

    $version = Get-BuildVersion `
        -DirectoryBuildProps $directoryBuildPropsXml

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

    $UseProjectReference = $UseProjectReferenceValue.ToString().Trim().ToLower() -eq "true"    

    #------------------------------------------------------------
    # Get Configuration
    #------------------------------------------------------------

    $Configuration = Get-PropsProperty `
        -PropsFile $PropsFile `
        -PropertyName "Configuration" `
        -DefaultValue "Release"

    $mainProject = Get-MainProject `
        -SolutionFile $solutionPath

    $visited = @{}

    $project = Get-ProjectTree `
        -ProjectFile $mainProject `
        -Version $version `
        -Visited $visited

    $uniqueProjects = @{}

    Add-UniqueProjects `
        -Project $project `
        -UniqueProjects $uniqueProjects

    Write-Host "Unique projects     : $($uniqueProjects.Count)"

    #------------------------------------------------------------
    # Console Output
    #------------------------------------------------------------

    Write-Host "Root                : $RootPath"
    Write-Host "Solution            : $solutionName"
    Write-Host "File                : $solutionPath"
    Write-Host "UseProjectReference : $UseProjectReference"
    Write-Host "Configuration       : $Configuration"

    if ($mainProject) {

        $mainProjectName = [System.IO.Path]::GetFileNameWithoutExtension(
            $mainProject
        )

        Write-Host "Main project        : $mainProjectName"
    }
    else {
        Write-Host "Main project        : None"
    }

    #------------------------------------------------------------
    # Build Configuration
    #------------------------------------------------------------

    $BuildConfig = [ordered]@{
        GeneratedAt    = (Get-Date).ToString("o")

        Solution       = [ordered]@{
            Name                = $SolutionName
            File                = $SolutionPath
            Directory           = $SolutionDirectory
            DirectoryBuildProps = $PropsFile
        }

        Build          = [ordered]@{
            UseProjectReference = $UseProjectReference
            Configuration       = $Configuration
        }

        ProjectCount   = $uniqueProjects.Count

        Projects       = @(
            $project
        )

        UniqueProjects = @(
            $uniqueProjects.Values
        )
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

    if (-not (Test-Path $PipelineDirectory)) {

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

}