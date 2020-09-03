function Start-DPContentDistribution {
    <#
    .SYNOPSIS
        Distributes objects to a given distribution point.
    .DESCRIPTION
        Distributes objects to a given distribution point.
        
        Start-DPContentDistribution can accept input object from Get-DPContent or Get-DPDistributionStatus, by manually specifying -ObjectID and -ObjectType or by using -Folder where it will distribute all objects for .pkgx files found in said folder.

        For more information on why you might use the -Folder parameter, please read the CONTENT LIBRARY MIRATION section in the About help topic about_PSCMContentMgmt_ExportImport.
    .PARAMETER InputObject
        A PSObject type "PSCMContentMgmt" generated by Get-DPContent
    .PARAMETER DistributionPoint
        Name of distribution point (as it appears in Configuration Manager, usually FQDN) you want to distribute objects to.
    .PARAMETER ObjectID
        Unique ID of the content object you want to distribute.

        For Applications the ID must be the CI_ID value whereas for all other content objects the ID is PackageID.

        When using this parameter you must also use ObjectType.
    .PARAMETER ObjectType
        Object type of the content object you want to distribute.

        Can be one of the following values: "Package", "DriverPackage", "DeploymentPackage", "OperatingSystemImage", "OperatingSystemInstaller", "BootImage", "Application".

        When using this parameter you must also use ObjectID.
    .PARAMETER Folder
        For all .pkgx files in this folder that use the following naming convention "<ObjectType>_<ObjectID>.pkgx", distribute the <ObjectID> of type <ObjectType> to -DistributionPoint.

        This can be useful if you have a folder filled with .pkgx files, generated by Export-DPContent, and want to distribute those objects to a distribution point.
    .PARAMETER SiteServer
        It is not usually necessary to specify this parameter as importing the PSCMContentMgr module sets the $CMSiteServer variable which is the default value for this parameter.
        
        Specify this to query an alternative server, or if the module import process was unable to auto-detect and set $CMSiteServer.
    .PARAMETER SiteCode
        Site code of which the server specified by -SiteServer belongs to.
        
        It is not usually necessary to specify this parameter as importing the PSCMContentMgr module sets the $CMSiteCode variable which is the default value for this parameter.
        
        Specify this to query an alternative site, or if the module import process was unable to auto-detect and set $CMSiteCode.
    .INPUTS
        System.Management.Automation.PSObject
    .OUTPUTS
        System.Management.Automation.PSObject
    .EXAMPLE
        PS C:\> Compare-DPContent -Source "dp1.contoso.com" -Target "dp2.contoso.com" | Start-DPContentDistribution -DistributionPoint "dp2.contoso.com" -WhatIf

        Compares the missing content objects on dp2.contoso.com compared to dp1.contoso.com, and distributes them to dp2.contoso.com.
    .EXAMPLE
        PS C:\> Start-DPContentDistribution -Folder "E:\exported" -DistributionPoint "dp2.contoso.com" -WhatIf

        For all .pkgx files in folder E:\exported that use the following naming convention <ObjectType>_<ObjectID>.pkgx, distributes them to dp2.contoso.com.

        For more information on why you might use the -Folder parameter, please read the CONTENT LIBRARY MIRATION section in the About help topic about_PSCMContentMgmt_ExportImport.
    .EXAMPLE
        PS C:\> Start-DPContentDistribution -ObjectID ACC00007 -ObjectType Package -DistributionPoint "dp2.contoso.com" -WhatIf
        
        Nothing more than a wrapper for Start-CMContentDistribution. Distributes package ACC00007 to dp2.contoso.com.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="InputObject")]
        [PSTypeName('PSCMContentMgmt')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName="Properties")]
        [ValidateNotNullOrEmpty()]
        [String]$ObjectID,

        [Parameter(Mandatory, ParameterSetName="Properties")]
        [ValidateSet("Package","DriverPackage","DeploymentPackage","OperatingSystemImage","OperatingSystemInstaller","BootImage","Application")]
        [SMS_DPContentInfo]$ObjectType,

        [Parameter(Mandatory, ParameterSetName="Folder")]
        [ValidateScript({
            if (!([System.IO.Directory]::Exists($_))) {
                throw "Invalid path or access denied"
            } elseif (!($_ | Test-Path -PathType Container)) {
                throw "Value must be a directory, not a file"
            } else {
                return $true
            }
        })]
        [String]$Folder,

        [Parameter(ParameterSetName="InputObject")]
        [Parameter(Mandatory, ParameterSetName="Properties")]
        [Parameter(Mandatory, ParameterSetName="Folder")]
        [ValidateNotNullOrEmpty()]
        [String]$DistributionPoint,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteServer = $CMSiteServer,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteCode = $CMSiteCode
    )
    begin {
        switch ($null) {
            $SiteCode {
                Write-Error -Message "Please supply a site code using the -SiteCode parameter" -Category "InvalidArgument" -ErrorAction "Stop"
            }
            $SiteServer {
                Write-Error -Message "Please supply a site server FQDN address using the -SiteServer parameter" -Category "InvalidArgument" -ErrorAction "Stop"
            }
        }

        $TargetDP = $DistributionPoint

        if ($PSCmdlet.ParameterSetName -ne "InputObject") {
            $InputObject = [PSCustomObject]@{
                ObjectID          = $ObjectID
                ObjectType        = $ObjectType
                Distributionpoint = $TargetDP
            }
        }

        if ($PSCmdlet.ParameterSetName -eq "Folder") {
            $Files = Get-ChildItem -Path $Folder -Filter "*.pkgx"

            try {
                Resolve-DP -Name $TargetDP -SiteServer $SiteServer -SiteCode $SiteCode
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        $OriginalLocation = (Get-Location).Path

        if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider "CMSite" -ErrorAction "SilentlyContinue")) {
            $null = New-PSDrive -Name $SiteCode -PSProvider "CMSite" -Root $SiteServer -ErrorAction "Stop"
        }

        Set-Location ("{0}:\" -f $SiteCode) -ErrorAction "Stop"
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                "Folder" {
                    foreach ($File in $Files) {
                        if ($File.Name -match "^(?<ObjectType>0|3|5|257|258|259|512)_(?<ObjectID>[A-Za-z0-9]+)\.pkgx$") {
                            $InputObject = [PSCustomObject]@{
                                ObjectID   = $Matches.ObjectID
                                ObjectType = $Matches.ObjectType
                            }
        
                            $result = @{
                                PSTypeName = "PSCMContentMgmtDistribute" 
                                ObjectID   = $InputObject.ObjectID
                                ObjectType = ([SMS_DPContentInfo]$InputObject.ObjectType).ToString()
                                Message    = $null
                            }

                            $Command = 'Start-CMContentDistribution -{0} "{1}" -DistributionPointName "{2}" -ErrorAction "Stop"' -f [SMS_DPContentInfo_CMParameters][SMS_DPContentInfo]$InputObject.ObjectType, $InputObject.ObjectID, $TargetDP
                            $ScriptBlock = [ScriptBlock]::Create($Command)
                            try {
                                if ($PSCmdlet.ShouldProcess(
                                    ("Would distribute '{0}' ({1}) to '{2}'" -f $InputObject.ObjectID, [SMS_DPContentInfo]$InputObject.ObjectType, $TargetDP),
                                    "Are you sure you want to continue?",
                                    ("Distributing '{0}' ({1}) to '{2}'" -f $InputObject.ObjectID, [SMS_DPContentInfo]$InputObject.ObjectType, $TargetDP))) {
                                        Invoke-Command -ScriptBlock $ScriptBlock -ErrorAction "Stop"
                                        $result["Result"] = "Success"
                                }
                                else {
                                    $result["Result"] = "No change"
                                }
                            }
                            catch {
                                Write-Error -ErrorRecord $_
                                $result["Result"] = "Failed"
                                $result["Message"] = $_.Exception.Message
                            }
                            
                            if (-not $WhatIfPreference) { [PSCustomObject]$result }
                        }
                        else {
                            Write-Warning ("Skipping '{0}'" -f $File.Name)
                        }
                    }
                }
                default {
                    foreach ($Object in $InputObject) {
                        switch ($true) {
                            ($LastDP -ne $Object.DistributionPoint -And -not $PSBoundParameters.ContainsKey("DistributionPoint")) {
                                $TargetDP = $Object.DistributionPoint
                            }
                            ($LastDP -ne $TargetDP) {
                                try {
                                    Resolve-DP -Name $TargetDP -SiteServer $SiteServer -SiteCode $SiteCode
                                }
                                catch {
                                    Write-Error -ErrorRecord $_
                                    return
                                }
                                
                                $LastDP = $TargetDP
                            }
                            default {
                                $LastDP = $TargetDP
                            }
                        }

                        $result = @{
                            PSTypeName = "PSCMContentMgmtDistribute" 
                            ObjectID   = $Object.ObjectID
                            ObjectType = $Object.ObjectType
                            Message    = $null
                        }
        
                        $Command = 'Start-CMContentDistribution -{0} "{1}" -DistributionPointName "{2}" -ErrorAction "Stop"' -f [SMS_DPContentInfo_CMParameters][SMS_DPContentInfo]$Object.ObjectType, $Object.ObjectID, $TargetDP
                        $ScriptBlock = [ScriptBlock]::Create($Command)
                        try {
                            if ($PSCmdlet.ShouldProcess(
                                ("Would distribute '{0}' ({1}) to '{2}'" -f $Object.ObjectID, $Object.ObjectType, $TargetDP),
                                "Are you sure you want to continue?",
                                ("Distributing '{0}' ({1}) to '{2}'" -f $Object.ObjectID, $Object.ObjectType, $TargetDP))) {
                                    Invoke-Command -ScriptBlock $ScriptBlock -ErrorAction "Stop"
                                    $result["Result"] = "Success"
                            }
                            else {
                                $result["Result"] = "No change"
                            }
                        }
                        catch {
                            Write-Error -ErrorRecord $_
                            $result["Result"] = "Failed"
                            $result["Message"] = $_.Exception.Message
                        }
                        
                        if (-not $WhatIfPreference) { [PSCustomObject]$result }
                    }
                }
            }
        }
        catch {
            Set-Location $OriginalLocation 
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        Set-Location $OriginalLocation
    }
}
