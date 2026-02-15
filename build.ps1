<#
.SYNOPSIS
    Build script for Windows Maintenance Framework using Invoke-Build (v4.2.0).
#>

task . Clean, Init, Analyze, Test, Document, Site, Pack

task Clean {
    Write-Output "Cleaning up artifacts..."
    $Artifacts = "CodeCoverage.xml", "out/", "docs/reference/*.md", "site/"
    Remove-Item $Artifacts -Recurse -Force -ErrorAction SilentlyContinue
}

task Init {
    Write-Output "Initializing build environment..."
    $Modules = @('Pester', 'PSScriptAnalyzer', 'platyPS', 'Invoke-Build')
    foreach ($Module in $Modules) {
        if (-not (Get-Module -ListAvailable $Module)) {
            Write-Output "Installing missing module: $Module"
            Install-Module $Module -Force -Scope CurrentUser -SkipPublisherCheck
        }
    }
}

task Analyze {
    Write-Output "Running PSScriptAnalyzer..."
    $Results = Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse -Severity Error, Warning |
               Where-Object { $_.ScriptPath -notmatch 'Legacy' }
    if ($Results) {
        $Results | Format-Table
        throw "PSScriptAnalyzer found issues."
    }
}

task Test {
    Write-Output "Running verified cross-version tests..."
    ./Tests/Invoke-Tests.ps1 -CI
}

task Document {
    Write-Output "Generating cmdlet reference with platyPS..."
    $ReferencePath = "docs/reference"
    if (!(Test-Path $ReferencePath)) { New-Item -ItemType Directory -Path $ReferencePath | Out-Null }

    # Import module and generate Markdown
    try {
        $ManifestPath = Resolve-Path "./WindowsMaintenance.psd1"
        Import-Module $ManifestPath -Force
        # Suppression attribute might prevent help generation in some versions, using quiet param if needed
        New-MarkdownHelp -Module WindowsMaintenance -OutputFolder $ReferencePath -Force -ErrorAction SilentlyContinue
        Write-Output "Documentation generated in $ReferencePath"
    } catch {
        Write-Warning "Failed to generate documentation: $($_.Exception.Message)"
    }
}

task Site {
    Write-Output "Building MkDocs website..."
    if (Get-Command mkdocs -ErrorAction SilentlyContinue) {
        mkdocs build
        Write-Output "Site built in ./site folder"
    } else {
        Write-Warning "MkDocs command not found. Website build skipped."
    }
}

task Pack {
    Write-Output "Packaging module for distribution..."
    $BuildOut = "out/WindowsMaintenance"
    if (!(Test-Path $BuildOut)) { New-Item -ItemType Directory -Path $BuildOut -Force | Out-Null }

    # Copy necessary files
    Copy-Item "Modules", "Config", "Tools", "GUI", "Lib", "*.psm1", "*.psd1", "*.md", "LICENSE" -Destination $BuildOut -Recurse -Force -ErrorAction SilentlyContinue

    # Create distribution ZIP
    Compress-Archive -Path "$BuildOut\*" -DestinationPath "out/WindowsMaintenance-v4.2.0.zip" -Force
    Write-Output "Created: out/WindowsMaintenance-v4.2.0.zip"
}

task Publish {
    Write-Output "NuGet Publishing placeholder..."
    # Publish-Module -Path "out/WindowsMaintenance" -NuGetApiKey $env:NUGET_KEY
}
