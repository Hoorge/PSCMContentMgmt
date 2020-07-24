param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$ModuleName = ([Regex]::Match((Get-Content -Path $BuildRoot\.git\config -ErrorAction Stop), "url = https://github\.com/codaamok/(.+)\.git")).Groups[1].Value
)

# Synopsis: Initiate the entire build process
task . clean, CreatePSM1, CopyFormatFiles, CreateScriptsToProcess, CreatePSD1

# Synopsis: Cleans the build directory
task clean {
    remove 'build'
}

# Synopsis: Creates a single .psm1 file of all private and public functions of the to-be-published module
task CreatePSM1 {
    $TargetFile = New-Item -Path $BuildRoot\build\$ModuleName\$ModuleName.psm1 -ItemType "File" -Force

    foreach ($FunctionType in "Private","Public") {
        '#region {0} functions' -f $FunctionType | Add-Content -Path $TargetFile
        $Files = @(Get-ChildItem $BuildRoot\$ModuleName\$FunctionType -Filter *.ps1)
        foreach ($File in $Files) {
            Get-Content -Path $File | Add-Content -Path $TargetFile
            if ($Files.IndexOf($File) -ne ($Files.Count - 1)) {
                Write-Output "" | Add-Content -Path $TargetFile
            }
        }
        '#endregion {0} functions' -f $FunctionType | Add-Content -Path $TargetFile
        Write-Output "" | Add-Content -Path $TargetFile
    }
}

# Synopsis: Create a single Process.ps1 file of all content within scripts files under ScriptsToProcess\*
task CreateScriptsToProcess {
    $TargetFile = New-Item -Path $BuildRoot\build\$ModuleName\Process.ps1 -ItemType "File" -Force

    $Files = @(Get-ChildItem $BuildRoot\$ModuleName\ScriptsToProcess -Filter *.ps1)
    foreach ($File in $Files) {
        Get-Content -Path $File | Add-Content -Path $TargetFile
        if ($Files.IndexOf($File) -ne ($Files.Count - 1)) {
            Write-Output "" | Add-Content -Path $TargetFile
        }
        Write-Output "" | Add-Content -Path $TargetFile
    }
}

# Synopsis: Copy format files (if any)
task CopyFormatFiles {
    Get-ChildItem $BuildRoot\$ModuleName -Filter "*format.ps1xml" | Copy-Item -Destination $BuildRoot\build\$ModuleName
}

# Synopsis: Copy and update the manifest
task CreatePSD1 {
    Copy-Item -Path $BuildRoot\$ModuleName\$ModuleName.psd1 -Destination $BuildRoot\build\$ModuleName
    
    # Understand that if module isn't currently in the gallery, Invoke-Build will produce a terminating error and the build will fail!
    $PSGallery = Find-Module $ModuleName

    $NewModuleManifestSplat = @{
        Path = '{0}\build\{1}\{2}.psd1' -f $BuildRoot, $ModuleName, $ModuleName
        Guid = $PSGallery.AdditonalMetaData.GUID
        Author = 'Adam Cook (@codaamok)'
        # not ideal to create new module manifest for each build in case of differences between built vs in main branch
    }

    # Only ever increments the minor, I wonder how I could handle major. Maybe just trigger workflow based on releases and use the version from that instead?
    if ($PSGallery) {
        $NewModuleManifestSplat["ModuleVersion"] = '{0}.{1}.{2}' -f ([System.Version]$PSGallery.Version).Major, (([System.Version]$PSGallery.Version).Minor + 1), (Get-Date -Format "yyyyMMdd")
    }

    $FormatFiles = Get-ChildItem $BuildRoot\build\$ModuleName -Filter "*format.ps1xml"
    if ($FormatFiles) {
        $NewModuleManifestSplat["FormatsToProcess"] = foreach ($File in $FormatFiles) {
            $File.Name
        }
    }

    $ScriptsToProcess = Get-ChildItem -Path $BuildRoot\build\$ModuleName\Process.ps1 -ErrorAction Stop
    if ($ScriptsToProcess) {
        $NewModuleManifestSplat["ScriptsToProcess"] = $ScriptsToProcess.Name
    }
    
    New-ModuleManifest @UpdateModuleManifestSplat
}