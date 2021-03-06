#
# Module manifest for module 'PSCMContentMgmt'
#
# Generated by: Adam Cook (@codaamok)
#
# Generated on: 09/08/2020
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSCMContentMgmt.psm1'

# Version number of this module.
ModuleVersion = '1.6.20200908.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = 'c49a17e2-210f-409c-aefa-4a4b45427896'

# Author of this module
Author = 'Adam Cook (@codaamok)'

# Company or vendor of this module
CompanyName = ''

# Copyright statement for this module
Copyright = '(c) 2020 - Adam Cook (@codaamok). All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell module used for managing Microsoft Endpoint Manager Configuration Manager distribution point content.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = 'Process.ps1'

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = 'PSCMContentMgmt.Format.ps1xml'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Compare-DPContent', 'Compare-DPGroupContent', 'Export-DPContent', 
               'Find-CMOBject', 'Get-DP', 'Get-DPContent', 'Get-DPDistributionStatus', 
               'Get-DPGroup', 'Get-DPGroupContent', 'Import-DPContent', 
               'Invoke-DPContentLibraryCleanup', 'Remove-DPContent', 
               'Remove-DPGroupContent', 'Set-DPAllowPrestagedContent', 
               'Start-DPContentDistribution', 'Start-DPContentRedistribution', 
               'Start-DPGroupContentDistribution'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'SCCM','MEMCM','MECM','ConfigMgr'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/codaamok/PSCMContentMgmt/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/codaamok/PSCMContentMgmt'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '# Added
- More properties added to the module manifest
# Changed
- Updated various help content to better describe -ObjectID parameter and ObjectID property
# Fixed
- Corrected CIM query in `Start-DPContentRedistribution` so it actually works. Added error handling to in the event an object is not found to be already distributed to a distribution point.
- More accurate error ID to reflect a win32 error code for access denied in `Import-DPContent`'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

