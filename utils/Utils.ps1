function Find-Solution {

    param(
        [string]$RootPath
    )

    $solution = Get-ChildItem `
        -Path $RootPath `
        -Filter "*.sln" `
        -File `
        -Recurse |
    Select-Object -First 1

    return $solution
}

function Get-MainProject {

    param(
        [string]$SolutionFile
    )

    $solutionDirectory = Split-Path $SolutionFile -Parent

    $lines = Get-Content $SolutionFile

    foreach ($line in $lines) {

        if ($line -match 'Project\(".*"\)\s*=\s*"[^"]+",\s*"([^"]+\.csproj)"') {

            $relativePath = $matches[1]

            $projectPath = Join-Path `
                $solutionDirectory `
                $relativePath

            $projectPath = [System.IO.Path]::GetFullPath($projectPath)

            if (-not (Test-Path $projectPath)) {
                continue
            }

            [xml]$xml = Get-Content $projectPath

            $sdk = $xml.Project.Sdk

            if ($sdk -eq "Microsoft.NET.Sdk.Web") {
                return $projectPath
            }
        }
    }

    return $null
}

function Get-ProjectInfo {
    param(
        [string]$ProjectFile,
        [string]$Version
    )

    [xml]$xml = Get-Content $ProjectFile
    $projectNode = $xml.Project

    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectFile)

    $packageId = $null

    $packageIdNode = $projectNode.PropertyGroup.PackageId |
    Select-Object -First 1

    if ($packageIdNode) {
        $packageId = $packageIdNode.ToString().Trim()
    }

    if ([string]::IsNullOrWhiteSpace($packageId)) {
        $packageId = $projectName
    }

    return [ordered]@{
        Name         = $projectName
        File         = [System.IO.Path]::GetFullPath($ProjectFile)
        PackageId    = $packageId
        Version      = $Version
        Dependencies = @()
    }
}

function Read-DirectoryBuildProps { 
    param( [string]$File ) 
    if (-not (Test-Path $File)) { 
        return $null 
    } 
    [xml]$xml = Get-Content $File 
    return $xml 
} 

function Get-BuildVersion {
    param( [xml]$DirectoryBuildProps ) 
    if ($null -eq $DirectoryBuildProps) { 
        return $null 
    } 
    $versionNode = $DirectoryBuildProps.Project.PropertyGroup.Version | Select-Object -First 1 
    if ($versionNode) { 
        $version = $versionNode.ToString().Trim() 
        if (-not [string]::IsNullOrWhiteSpace($version)) { 
            return $version 
        } 
    } 
    return $null 
}

function Get-ProjectReferences {

    param(
        [string]$ProjectFile
    )

    [xml]$xml = Get-Content $ProjectFile

    $projectDirectory = Split-Path $ProjectFile -Parent

    $dependencies = @()

    foreach ($projectReference in $xml.Project.ItemGroup.ProjectReference) {

        $referencePath = $projectReference.Include

        if ([string]::IsNullOrWhiteSpace($referencePath)) {
            continue
        }

        $dependencyFile = Join-Path `
            $projectDirectory `
            $referencePath

        $dependencyFile = [System.IO.Path]::GetFullPath(
            $dependencyFile
        )

        if (Test-Path $dependencyFile) {
            $dependencies += $dependencyFile
        }
    }

    return $dependencies
}

function Get-ProjectTree {
    param(
        [string]$ProjectFile,
        [string]$Version,
        [hashtable]$Visited
    )

    $ProjectFile = [System.IO.Path]::GetFullPath($ProjectFile)

    # Prevent circular references in the current dependency path
    if ($Visited.ContainsKey($ProjectFile)) {
        return $null
    }

    $Visited[$ProjectFile] = $true

    # Create project object
    $project = Get-ProjectInfo `
        -ProjectFile $ProjectFile `
        -Version $Version

    # Get direct project references
    $references = Get-ProjectReferences `
        -ProjectFile $ProjectFile

    # Recursively build dependency tree
    foreach ($reference in $references) {

        $dependency = Get-ProjectTree `
            -ProjectFile $reference `
            -Version $Version `
            -Visited $Visited

        if ($null -ne $dependency) {
            $project.Dependencies += $dependency
        }
    }

    # Remove from visited after this branch is complete.
    # This allows the same project to appear under different branches.
    $Visited.Remove($ProjectFile)

    return $project
}

function Add-UniqueProjects {
    param(
        [object]$Project,
        [hashtable]$UniqueProjects
    )

    if ($null -eq $Project) {
        return
    }

    $projectFile = [System.IO.Path]::GetFullPath($Project.File)

    # Add only if we haven't seen this project before
    if (-not $UniqueProjects.ContainsKey($projectFile)) {

        $projectDirectory = Split-Path $projectFile -Parent

        # Project folder name
        $projectName = Split-Path $projectDirectory -Leaf

        $UniqueProjects[$projectFile] = [ordered]@{
            Name        = $projectName
            Solution    = $Project.Name
            ProjectFile = $Project.File
            PackageId   = $Project.PackageId
        }
    }

    # Process dependencies recursively
    foreach ($dependency in @($Project.Dependencies)) {

        Add-UniqueProjects `
            -Project $dependency `
            -UniqueProjects $UniqueProjects
    }
}