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

function Get-SolutionProjects {

    param(
        [string]$SolutionFile
    )

    $solutionDirectory = Split-Path $SolutionFile -Parent

    $lines = Get-Content $SolutionFile

    $projects = @()

    foreach ($line in $lines) {

        if ($line -match 'Project\(".*"\)\s*=\s*"[^"]+",\s*"([^"]+\.csproj)"') {

            $relativePath = $matches[1]

            $projectPath = Join-Path `
                $solutionDirectory `
                $relativePath

            $projectPath = [System.IO.Path]::GetFullPath($projectPath)

            if (Test-Path $projectPath) {

                $projects += $projectPath
            }
        }
    }

    return $projects
}

function Get-ProjectPackageId {

    param(
        [string]$ProjectFile
    )

    [xml]$xml = Get-Content $ProjectFile -Raw

    foreach ($group in $xml.Project.PropertyGroup) {

        $node = $group.SelectSingleNode("PackageId")

        if ($null -ne $node) {

            if (![string]::IsNullOrWhiteSpace($node.InnerText)) {
                return $node.InnerText.Trim()
            }
        }
    }

    # Default PackageId = project filename
    return [System.IO.Path]::GetFileNameWithoutExtension($ProjectFile)
}

function Get-PackageReferences {

    param(
        [string]$ProjectFile
    )

    [xml]$xml = Get-Content $ProjectFile -Raw

    $references = @()

    foreach ($itemGroup in $xml.Project.ItemGroup) {

        $condition = $itemGroup.Condition

        if ($condition -and
            $condition -notmatch "UseProjectReference.*!=.*'true'") {

            continue
        }

        foreach ($reference in $itemGroup.PackageReference) {

            $include = $reference.Include

            if ([string]::IsNullOrWhiteSpace($include)) {
                continue
            }

            $version = $reference.Version

            $references += [PSCustomObject]@{
                PackageId = $include
                Version   = if ($version) { $version } else { $null }
            }
        }
    }

    return $references
}

function Resolve-PathSafe {

    param(
        [string]$BasePath,
        [string]$RelativePath
    )

    $path = Join-Path $BasePath $RelativePath

    return [System.IO.Path]::GetFullPath($path)
}