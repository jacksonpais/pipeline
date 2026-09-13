function Run-Action {

    param(
        [string]$ActionName,
        [string]$Path = (Get-Location).Path
    )

    Write-Host " "

    $PackageConfigFile = "$Path\package.json"
    $BuildConfigFile = "$Path\pipeline\BuildConfig.json"

    Write-Host "Build Config File   :  $BuildConfigFile"
    Write-Host "Package Config File :  $PackageConfigFile"
    Write-Host " "

    $ScriptRoot = Split-Path $PSScriptRoot -Parent

    . "$ScriptRoot\scripts\Tasks\Scan-Project.ps1"
    . "$ScriptRoot\scripts\Tasks\Build-Project.ps1"
    . "$ScriptRoot\scripts\Tasks\Clean-Project.ps1"
    . "$ScriptRoot\scripts\Tasks\Restore-Project.ps1"
    . "$ScriptRoot\scripts\Tasks\Pack-Project.ps1"
   

    # ------------------------------------------------------------
    # Load Build Configuration
    # ------------------------------------------------------------
    
    if (-not (Test-Path $BuildConfigFile)) {
        throw "Build configuration file not found: $BuildConfigFile"
    }

    if (-not (Test-Path $PackageConfigFile)) {
        throw "Package configuration file not found: $PackageConfigFile"
    }

    $BuildConfig = Get-Content `
        -Path $BuildConfigFile `
        -Raw |
    ConvertFrom-Json

    $PackageConfig = Get-Content `
        -Path $PackageConfigFile `
        -Raw |
    ConvertFrom-Json

    # ------------------------------------------------------------
    # Validate Projects
    # ------------------------------------------------------------

    $projects = @($BuildConfig.UniqueProjects)

    $config = @($PackageConfig.Config)

    if ($projects.Count -eq 0) {
        throw "No Projects found in $BuildConfigFile"
    }

    $CreatedPackages = @()

    $Configuration = $config.Configuration
    $DeleteBin = $config.Clean.DeleteBin
    $DeleteObj = $config.Clean.DeleteObj
    $DoVerify = $config.Pack.Verify
    $NugetFeed = $config.NuGet.OutputFolder

    $DoClean = $false
    $DoRestore = $false
    $DoBuild = $false
    $DoScan = $false
    $DoPack = $false

    if ($Action -eq "scan") {
        $DoScan = $true
        Write-Step "Scan Project"
    }

    if ($Action -eq "clean") {
        $DoClean = $true
        Write-Step "Clean Project"
    }

    if ($Action -eq "restore") {
        $DoRestore = $true
        Write-Step "Restore Project"
    }

    if ($Action -eq "build") {
        $DoBuild = $true
        Write-Step "Build Project"
    }

    if ($Action -eq "pack") {
        $DoPack = $true
        Write-Step "Pack Project"
    }   

    if ($DoScan) {
        Scan-Project `
            -path $Path
    }

    if ($Action -ne "scan") {
        
        
        foreach ($project in $projects) {

            $Name = $project.Name
            $Solution = $project.Solution
            $ProjectFile = $project.ProjectFile
            $PackageId = $project.PackageId

            Write-Host ""
            Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host "Name            : $Name" 
            Write-Host "Solution        : $Solution" 
            Write-Host "Project         : $(Split-Path $ProjectFile -Leaf)" 
            Write-Host "Package ID      : $PackageId"          
            Write-Host "-------------------------------------------------------------" -ForegroundColor DarkCyan

            if ($DoClean) {
                Clean-Project `
                    -project $project `
                    -deleteBin $DeleteBin `
                    -deleteObj $DeleteObj `
                    -configuration $Configuration
            }

            if ($DoRestore) {
                Restore-Project `
                    -project $project
            }

            if ($DoBuild) {
                Build-Project `
                    -project $project
            }

            if ($DoPack) {

                Clean-Project `
                    -project $project `
                    -deleteBin $DeleteBin `
                    -deleteObj $DeleteObj `
                    -configuration $Configuration

                Restore-Project `
                    -project $project

                Build-Project `
                    -project $project

                Pack-Project `
                    -project $project `
                    -configuration $Configuration
                    
                if ($DoVerify) {

                    $package = Run-Step "Verify" {

                        Get-ChildItem `
                            -Path $NugetFeed `
                            -Filter "$PackageId*.nupkg" |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1
                    }

                    $CreatedPackages += $package
                }
            }

        }
    
    }

    if ($Action -eq "scan") {
        
        Success-Summary `
            -Message "SCAN COMPLETED SUCCESSFULLY"

    }

    if ($Action -eq "clean") {
        
        Success-Summary `
            -Message "CLEAN COMPLETED SUCCESSFULLY"
    }

    if ($Action -eq "restore") {
        
        Success-Summary `
            -Message "RESTORE COMPLETED SUCCESSFULLY"

    }

    if ($Action -eq "build") {

        Success-Summary `
            -Message "BUILD COMPLETED SUCCESSFULLY"
        
    }

    if ($Action -eq "pack") {
        
        Pack-Summary `
            -CreatedPackages $CreatedPackages `
            -verify $DoVerify
    
    }
}