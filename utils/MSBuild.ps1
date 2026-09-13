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