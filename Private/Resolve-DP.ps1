function Resolve-DP {
    <#
    .SYNOPSIS
        Validate whether a given host is a distribution point within a Configuration Manager site
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteServer = $CMSiteServer,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$SiteCode = $CMSiteCode
    )
    begin {
        $OriginalLocation = (Get-Location).Path

        if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer -ErrorAction Stop | Out-Null
        }

        Set-Location ("{0}:\" -f $SiteCode) -ErrorAction "Stop"
    }
    process {
        try {
            $Obj = Get-CMDistributionPoint -Name $Name -AllSite -ErrorAction "Stop"
            if (-not $Obj) {
                throw ("Distribution point '{0}' does not exist" -f $Name)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        Set-Location $OriginalLocation   
    }
}
