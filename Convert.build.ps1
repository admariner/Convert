<#
    .SYNOPSIS
    Holds the primary build tasks for Invoke-Build
#>

# Default
task . InstallDependencies, Clean, Analyze, Test, Build, IncrementVersion, Archive

# Pre-build variables to configure
Enter-Build {
    $script:ModuleName = (Split-Path -Path $BuildFile -Leaf).Split('.')[0]
    $script:ModuleSourcePath = Join-Path -Path $BuildRoot -ChildPath $script:ModuleName
    $script:ModuleFiles = Join-Path -Path $script:ModuleSourcePath -ChildPath '*'

    $script:ModuleManifestFile = Join-Path -Path $script:ModuleSourcePath -ChildPath "$($script:ModuleName).psd1"
    $script:Version = (Test-ModuleManifest -Path $script:ModuleManifestFile).Version

    $script:TestsPath = Join-Path -Path $BuildRoot -ChildPath 'Tests'
    $script:UnitTestsPath = Join-Path -Path $script:TestsPath -ChildPath 'Unit'
    
    $script:ArtifactsPath = Join-Path -Path $BuildRoot -ChildPath 'Artifact'
    $script:ArchivePath = Join-Path -Path $BuildRoot -ChildPath 'Archive'
    $script:PesterTestResultsFile = Join-Path -Path $script:ArchivePath -ChildPath 'TestsResults.xml'
}

# Synopsis: Installs Invoke-Build Dependencies
task InstallDependencies {
    Invoke-PSDepend -Install -Import -Force
}

# Synopsis: Clean Artifacts Directory
task Clean {
    # Clean folders from disk
    foreach ($path in $script:ArtifactsPath,$script:ArchivePath)
    {
        if (Test-Path -Path $path)
        {
            $null = Remove-Item -Path $path -Recurse -Force
        }

        $null = New-Item -ItemType Directory -Path $path -Force
    }

    # Clean test results
    if (Test-Path -Path $script:PesterTestResultsFile)
    {
        $null = Remove-Item -Path $script:PesterTestResultsFile -Force
    }
}

# Synopsis: Invokes Script Analyzer against the Module source path
task Analyze {
    $scriptAnalyzerParams = @{
        Path = $script:ModuleSourcePath
        Severity = @('Error', 'Warning')
        Recurse = $true
        Verbose = $false
    }

    $scriptAnalyzerResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

    if ($scriptAnalyzerResults) {
        $scriptAnalyzerResults | Format-Table
        throw 'One or more PSScriptAnalyzer errors/warnings where found.'
    }
}

# Synopsis: Invokes Script Analyzer against the Tests path if it exists
task AnalyzeTests -After Analyze {
    if (Test-Path -Path $script:TestsPath)
    {
        $scriptAnalyzerParams = @{
            Path = $script:TestsPath
            Severity = @('Error', 'Warning')
            Recurse = $true
            Verbose = $false
        }

        $scriptAnalyzerResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

        if ($scriptAnalyzerResults) {
            $scriptAnalyzerResults | Format-Table
            throw 'One or more PSScriptAnalyzer errors/warnings where found.'
        }
    }
}

# Synopsis: Invokes all Pester Unit Tests in the Tests\Unit folder (if it exists)
task Test {
    if (Test-Path -Path $script:UnitTestsPath)
    {
        $invokePesterParams = @{
            Path = $script:UnitTestsPath
            OutputFormat = 'NUnitXml'
            OutputFile = $script:PesterTestResultsFile
            Strict = $true
            PassThru = $true
            Verbose = $false
            EnableExit = $false
        }

        # Publish Test Results as NUnitXml
        $testResults = Invoke-Pester @invokePesterParams

        # Output results for AppVeyor
        if ($env:APPVEYOR_JOB_ID) {
            $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
            $wc = New-Object -TypeName System.Net.WebClient
            $wc.UploadFile($url, (Resolve-Path -Path $script:PesterTestResultsFile))
        }
        
        # Output results as json for CodeBuild and CloudWatch
        if ($env:CODEBUILD_BUILD_ARN) {
            $testResults.TestResult | ForEach-Object {
                ConvertTo-Json -InputObject $_ -Compress
            }
        }
        
        # Trying to fail the build
        if ($testResults.FailedCount -gt 0) {
            throw "$($testResults.FailedCount) tests failed."
        }
    }
}

# Synopsis: Builds the Module to the Artifacts folder
task Build {
    Copy-Item -Path $script:ModuleFiles -Destination $script:ArtifactsPath -Recurse -ErrorAction Stop
}

# Synopsis: Increments the Module Manifest version
task IncrementVersion {
    # Environmental Variables Guide: https://www.appveyor.com/docs/environment-variables/
    if ($env:APPVEYOR_REPO_BRANCH -ne 'master') 
    {
        $script:NewVersion = $script:Version
        Write-Warning -Message "Skipping version increment and publish for branch $env:APPVEYOR_REPO_BRANCH"
    }
    elseif ($env:APPVEYOR_PULL_REQUEST_NUMBER -gt 0)
    {
        $script:NewVersion = $script:Version
        Write-Warning -Message "Skipping version increment and publish for pull request #$env:APPVEYOR_PULL_REQUEST_NUMBER"
    }
    elseif ([string]::IsNullOrWhiteSpace($env:APPVEYOR_BUILD_VERSION)) {
        $script:NewVersion = $script:Version
        Write-Warning -Message 'Skipping version increment and publish as no APPVEYOR_BUILD_VERSION environment variable found'
    }
    else
    {
        $artifactManifest = Join-Path -Path $script:ArtifactsPath -ChildPath ('{0}.psd1' -f $script:ModuleName)
        if (-not (Test-Path -Path $artifactManifest)) { break }

        # The AppVeyor version from appveyor.yml provides the Module Version
        $script:NewVersion = $env:APPVEYOR_BUILD_VERSION

        "Current Version $($script:Version)"
        "New Version $($script:NewVersion)"

        Update-ModuleManifest -Path $artifactManifest -ModuleVersion $script:NewVersion
    }
}

# Synopsis: Creates an archive of the built Module
task Archive {
    $archivePath = Join-Path -Path $BuildRoot -ChildPath 'Archive'
    if (Test-Path -Path $archivePath)
    {
        $null = Remove-Item -Path $archivePath -Recurse -Force
    }

    $null = New-Item -Path $archivePath -ItemType Directory -Force
    
    $childPath = '{0}_{1}_{2}.{3}.zip' -f $script:ModuleName, $script:NewVersion.ToString(), ([DateTime]::UtcNow.ToString("yyyyMMdd")), ([DateTime]::UtcNow.ToString("hhmmss"))
    $zipFile = Join-Path -Path $archivePath -ChildPath $childPath

    $filesToArchive = Join-Path -Path $script:ArtifactsPath -ChildPath '*'
    
    Compress-Archive -Path $filesToArchive -DestinationPath $zipFile
}
