#------------------------------------------------------------
# MSBuild Utilities
#------------------------------------------------------------

function Get-PropsProperty {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PropsFile,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [string]$DefaultValue = $null
    )

    if (!(Test-Path $PropsFile)) {
        return $DefaultValue
    }

    try {
        [xml]$xml = Get-Content $PropsFile -Raw
    }
    catch {
        throw "Unable to read props file: $PropsFile"
    }

    foreach ($group in $xml.Project.PropertyGroup) {

        $property = $group.SelectSingleNode(
            "*[local-name()='$PropertyName']"
        )

        if ($null -ne $property) {

            $value = $property.InnerText

            if (![string]::IsNullOrWhiteSpace($value)) {
                return $value.Trim()
            }
        }
    }

    return $DefaultValue
}

#------------------------------------------------------------
# Read XML Project
#------------------------------------------------------------

function Get-ProjectXml {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile
    )

    if (!(Test-Path $ProjectFile)) {
        throw "Project file not found: $ProjectFile"
    }

    try {
        return [xml](Get-Content $ProjectFile -Raw)
    }
    catch {
        throw "Unable to read project file: $ProjectFile"
    }
}

#------------------------------------------------------------
# Get Project Property
#------------------------------------------------------------

function Get-ProjectProperty {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [string]$DefaultValue = $null
    )

    $xml = Get-ProjectXml -ProjectFile $ProjectFile

    foreach ($group in $xml.Project.PropertyGroup) {

        $property = $group.SelectSingleNode(
            "*[local-name()='$PropertyName']"
        )

        if ($null -ne $property) {

            $value = $property.InnerText

            if (![string]::IsNullOrWhiteSpace($value)) {
                return $value.Trim()
            }
        }
    }

    return $DefaultValue
}

#------------------------------------------------------------
# Get PackageId
#------------------------------------------------------------

function Get-ProjectPackageId {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile
    )

    $projectName = [System.IO.Path]::GetFileNameWithoutExtension(
        $ProjectFile
    )

    return Get-ProjectProperty `
        -ProjectFile $ProjectFile `
        -PropertyName "PackageId" `
        -DefaultValue $projectName
}

#------------------------------------------------------------
# Get Project Version
#------------------------------------------------------------

function Get-ProjectVersion {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile
    )

    return Get-ProjectProperty `
        -ProjectFile $ProjectFile `
        -PropertyName "Version" `
        -DefaultValue "0.0.1"
}

#------------------------------------------------------------
# Get Project References
#------------------------------------------------------------

function Get-ProjectReferences {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile
    )

    $xml = Get-ProjectXml -ProjectFile $ProjectFile

    $references = @()

    foreach ($itemGroup in $xml.Project.ItemGroup) {

        foreach ($reference in $itemGroup.ProjectReference) {

            $include = $reference.Include

            if ([string]::IsNullOrWhiteSpace($include)) {
                continue
            }

            $projectDirectory = Split-Path $ProjectFile -Parent

            $fullPath = [System.IO.Path]::GetFullPath(
                (Join-Path $projectDirectory $include)
            )

            $references += [PSCustomObject]@{
                Include = $include
                Path    = $fullPath
            }
        }
    }

    return @($references)
}

#------------------------------------------------------------
# Get Package References
#------------------------------------------------------------

function Get-PackageReferences {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile
    )

    $xml = Get-ProjectXml -ProjectFile $ProjectFile

    $references = @()

    foreach ($itemGroup in $xml.Project.ItemGroup) {

        foreach ($reference in $itemGroup.PackageReference) {

            $packageId = $reference.Include

            if ([string]::IsNullOrWhiteSpace($packageId)) {
                continue
            }

            $version = $reference.Version

            if ([string]::IsNullOrWhiteSpace($version)) {
                $version = $reference.VersionOverride
            }

            if ([string]::IsNullOrWhiteSpace($version)) {
                $version = ""
            }

            $references += [PSCustomObject]@{
                PackageId = $packageId.Trim()
                Version   = $version.Trim()
            }
        }
    }

    return @($references)
}