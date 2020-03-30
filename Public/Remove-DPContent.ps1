function Remove-DPContent {
    <#
    .SYNOPSIS
        Remove objects from a distribution point
    .PARAMETER InputObject
        A PSObject type "PSCMContentMgmt" generated by Get-DPContent
    .PARAMETER DistributionPoint
        Name of distribution point (as it appears in ConfigMgr, usually FQDN) you want to remove content from.
    .PARAMETER ObjectID
        Unique ID of the content object you want to remove.

        For Applications the ID must be the CI_ID value whereas for all other content objects the ID is PackageID.

        When using this parameter you must also use ObjectType.
    .PARAMETER ObjectType
        Object type of the content object you want to remove.

        Can be one of the following values: "Package", "DriverPackage", "DeploymentPackage", "OperatingSystemImage", "OperatingSystemInstaller", "BootImage", "Application".

        When using this parameter you must also use ObjectID.
    .PARAMETER Confirm
        Suppress the prompt to continue.
    .EXAMPLE 
        PS C:\> Get-DPContent -Package -DistributionPoint "dp1.contoso.com" | Remove-DPContent

        Removes all packages distributed to dp1.contoso.com.
    .EXAMPLE
        PS C:\> Get-DPContentDistributionState -DistributionPoint "dp1.contoso.com" -DistributionFailed | Remove-DPContent

        Removes objects with content distribution status of "failed" distributed to dp1.contoso.com.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="InputObject")]
        [PSTypeName('PSCMContentMgmt')]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory, ParameterSetName="SpecifyProperties")]
        [ValidateNotNullOrEmpty()]
        [String]$DistributionPoint,

        [Parameter(Mandatory, ParameterSetName="SpecifyProperties")]
        [ValidateNotNullOrEmpty()]
        [String]$ObjectID,

        [Parameter(Mandatory, ParameterSetName="SpecifyProperties")]
        [ValidateSet("Package","DriverPackage","DeploymentPackage","OperatingSystemImage","OperatingSystemInstaller","BootImage","Application")]
        [SMS_DPContentInfo]$ObjectType,

        [Parameter()]
        [Bool]$Confirm = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteServer = $CMSiteServer,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteCode = $CMSiteCode
    )
    begin {
        if ($PSCmdlet.ParameterSetName -ne "InputObject") {
            $InputObject = [PSCustomObject]@{
                ObjectID          = $ObjectID
                ObjectType        = $ObjectType
                DistributionPoint = $DistributionPoint
            }
        }

        $OriginalLocation = (Get-Location).Path

        if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -ErrorAction Stop | Out-Null
        }

        Set-Location ("{0}:\" -f $SiteCode) -ErrorAction "Stop"
    }
    process {
        if ($LastDP -ne $InputObject.DistributionPoint) {
            try {     
                Resolve-DP -DistributionPoint $InputObject.DistributionPoint
            }
            catch {
                Write-Error -ErrorRecord $_
                return
            }
        }
        else {
            $LastDP = $InputObject.DistributionPoint
        }

        if ($Confirm -eq $true) {
            $Title = "Removing '{0}' ({1}) from '{2}'" -f $InputObject.ObjectID, [SMS_DPContentInfo]$InputObject.ObjectType, $InputObject.DistributionPoint
            $Question = "`nDo you want to remove '{0}' ({1}) from distribution point '{2}'?" -f $InputObject.ObjectID, [SMS_DPContentInfo]$InputObject.ObjectType, $InputObject.DistributionPoint
            $Choices = "&Yes", "&No"
            $Decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
            if ($Decision -eq 1) {
                return
            }
        }

        $result = [ordered]@{ 
            ObjectID   = $InputObject.ObjectID
            ObjectType = $InputObject.ObjectType
        }
        
        $Command = 'Remove-CMContentDistribution -DistributionPointName "{0}" -{1} "{2}" -Force -ErrorAction "Stop"' -f $InputObject.DistributionPoint, [SMS_DPContentInfo_CMParameters][SMS_DPContentInfo]$InputObject.ObjectType, $InputObject.ObjectID
        $ScriptBlock = [ScriptBlock]::Create($Command)
        try {
            Invoke-Command -ScriptBlock $ScriptBlock -ErrorAction "Stop"
            $result["Result"] = "Success"
        }
        catch {
            Write-Error -ErrorRecord $_
            $result["Result"] = "Failed: {0}" -f $_.Exception.Message
        }
        [PSCustomObject]$result
    }
    end {
        Set-Location $OriginalLocation
    }
}