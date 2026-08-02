#------------------------------------------------------------
# Dependency Graph Utilities
#------------------------------------------------------------

function Find-ProjectByPackageId {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter(Mandatory = $true)]
        [array]$KnownProjects
    )

    foreach ($project in $KnownProjects) {

        if ($project.PackageId -eq $PackageId) {
            return $project
        }
    }

    return $null
}

#------------------------------------------------------------
# Discover Project
#------------------------------------------------------------

function Add-ProjectToGraph {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile,

        [Parameter(Mandatory = $true)]
        [hashtable]$ProjectMap,

        [Parameter(Mandatory = $true)]
        [bool]$UseProjectReference,

        [Parameter(Mandatory = $true)]
        [string]$RootSolutionDirectory,

        [Parameter(Mandatory = $true)]
        [ref]$ExternalPackages
    )

    $ProjectFile = [System.IO.Path]::GetFullPath($ProjectFile)

    # Already processed
    if ($ProjectMap.ContainsKey($ProjectFile)) {
        return $ProjectMap[$ProjectFile]
    }

    if (!(Test-Path $ProjectFile)) {
        throw "Project file not found: $ProjectFile"
    }

    $Name = [System.IO.Path]::GetFileNameWithoutExtension(
        $ProjectFile
    )

    $PackageId = Get-ProjectPackageId `
        -ProjectFile $ProjectFile

    $Version = Get-ProjectVersion `
        -ProjectFile $ProjectFile

    $project = [PSCustomObject]@{
        Name         = $Name
        File         = $ProjectFile
        PackageId    = $PackageId
        Version      = $Version
        Type         = "DependencyProject"
        Dependencies = @()
    }

    # Add immediately.
    # This also prevents circular dependency recursion.
    $ProjectMap[$ProjectFile] = $project

    #--------------------------------------------------------
    # ProjectReference mode
    #--------------------------------------------------------

    if ($UseProjectReference) {

        $references = Get-ProjectReferences `
            -ProjectFile $ProjectFile

        foreach ($reference in $references) {

            $dependencyPath = $reference.Path

            if (!(Test-Path $dependencyPath)) {

                throw @"
ProjectReference not found.

Project : $ProjectFile
Reference: $($reference.Include)
Resolved: $dependencyPath
"@
            }

            $dependency = Add-ProjectToGraph `
                -ProjectFile $dependencyPath `
                -ProjectMap $ProjectMap `
                -UseProjectReference $UseProjectReference `
                -RootSolutionDirectory $RootSolutionDirectory `
                -ExternalPackages $ExternalPackages

            $project.Dependencies += $dependency.PackageId
        }
    }

    #--------------------------------------------------------
    # PackageReference mode
    #--------------------------------------------------------

    else {

        $references = Get-PackageReferences `
            -ProjectFile $ProjectFile

        foreach ($reference in $references) {

            $packageId = $reference.PackageId
            $version = $reference.Version

            #------------------------------------------------
            # Internal DestinEye package
            #------------------------------------------------

            if ($packageId.StartsWith(
                    "DestinEye.",
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {

                $dependency = Find-InternalProject `
                    -PackageId $packageId `
                    -CurrentProject $ProjectFile `
                    -ProjectMap $ProjectMap `
                    -RootSolutionDirectory $RootSolutionDirectory

                if ($null -eq $dependency) {

                    throw @"
Internal package could not be resolved.

Project : $ProjectFile
Package : $packageId
Version : $version

Expected an internal project with:

PackageId = $packageId
"@
                }

                #------------------------------------------------
                # Validate version
                #------------------------------------------------

                if (![string]::IsNullOrWhiteSpace($version)) {

                    if ($dependency.Version -ne $version) {

                        throw @"
Internal package version mismatch.

Project       : $ProjectFile
Package       : $packageId
Requested     : $version
Project       : $($dependency.File)
ProjectVersion: $($dependency.Version)
"@
                    }
                }

                $project.Dependencies += $dependency.PackageId
            }

            #------------------------------------------------
            # External package
            #------------------------------------------------

            else {

                $existing = $ExternalPackages.Value |
                Where-Object {
                    $_.PackageId -eq $packageId
                }

                if ($null -eq $existing) {

                    $ExternalPackages.Value += [PSCustomObject]@{
                        Name      = $packageId
                        PackageId = $packageId
                        Version   = $version
                    }
                }
                else {

                    $existingVersions = @(
                        $ExternalPackages.Value |
                        Where-Object {
                            $_.PackageId -eq $packageId
                        } |
                        Select-Object -ExpandProperty Version -Unique
                    )

                    if (
                        $version -and
                        $existingVersions -notcontains $version
                    ) {

                        throw @"
External package version conflict.

Package : $packageId
Versions:
$($existingVersions -join "`n")
$version
"@
                    }
                }
            }
        }
    }

    return $project
}

#------------------------------------------------------------
# Find Internal Project
#------------------------------------------------------------

function Find-InternalProject {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter(Mandatory = $true)]
        [string]$CurrentProject,

        [Parameter(Mandatory = $true)]
        [hashtable]$ProjectMap,

        [Parameter(Mandatory = $true)]
        [string]$RootSolutionDirectory
    )

    #--------------------------------------------------------
    # First search projects already discovered
    #--------------------------------------------------------

    foreach ($project in $ProjectMap.Values) {

        if ($project.PackageId -eq $PackageId) {
            return $project
        }
    }

    #--------------------------------------------------------
    # Convert:
    #
    # DestinEye.UserVault.Applications
    #
    # to:
    #
    # UserVault.Applications
    #--------------------------------------------------------

    if (!$PackageId.StartsWith("DestinEye.")) {
        return $null
    }

    $projectName = $PackageId.Substring(
        "DestinEye.".Length
    )

    #--------------------------------------------------------
    # Search repository root
    #
    # We intentionally search from the common git root.
    #--------------------------------------------------------

    $searchRoot = $RootSolutionDirectory

    while (
        $searchRoot -and
        (Split-Path $searchRoot -Parent) -ne $searchRoot
    ) {

        $candidate = Get-ChildItem `
            -Path $searchRoot `
            -Filter "$projectName.csproj" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
        Select-Object -First 1

        if ($candidate) {

            $candidatePath = $candidate.FullName

            $candidatePackageId = Get-ProjectPackageId `
                -ProjectFile $candidatePath

            if ($candidatePackageId -eq $PackageId) {

                $candidateVersion = Get-ProjectVersion `
                    -ProjectFile $candidatePath

                $project = [PSCustomObject]@{
                    Name         = [System.IO.Path]::GetFileNameWithoutExtension(
                        $candidatePath
                    )
                    File         = $candidatePath
                    PackageId    = $candidatePackageId
                    Version      = $candidateVersion
                    Type         = "DependencyProject"
                    Dependencies = @()
                }

                $ProjectMap[$candidatePath] = $project

                return Add-ProjectToGraph `
                    -ProjectFile $candidatePath `
                    -ProjectMap $ProjectMap `
                    -UseProjectReference $false `
                    -RootSolutionDirectory $RootSolutionDirectory `
                    -ExternalPackages ([ref]$script:ExternalPackages)
            }
        }

        $parent = Split-Path $searchRoot -Parent

        if ($parent -eq $searchRoot) {
            break
        }

        $searchRoot = $parent
    }

    return $null
}

#------------------------------------------------------------
# Build Dependency Graph
#------------------------------------------------------------

function Build-DependencyGraph {

    param(
        [Parameter(Mandatory = $true)]
        [array]$Projects,

        [Parameter(Mandatory = $true)]
        [bool]$UseProjectReference,

        [Parameter(Mandatory = $true)]
        [string]$RootSolutionDirectory,

        [Parameter(Mandatory = $true)]
        [ref]$ExternalPackages
    )

    $ProjectMap = @{}

    #--------------------------------------------------------
    # First add solution projects
    #--------------------------------------------------------

    foreach ($project in $Projects) {

        $ProjectMap[$project.File] = $project
    }

    #--------------------------------------------------------
    # Recursively process every solution project
    #--------------------------------------------------------

    foreach ($project in @($Projects)) {

        Add-ProjectToGraph `
            -ProjectFile $project.File `
            -ProjectMap $ProjectMap `
            -UseProjectReference $UseProjectReference `
            -RootSolutionDirectory $RootSolutionDirectory `
            -ExternalPackages $ExternalPackages | Out-Null
    }

    return @($ProjectMap.Values)
}