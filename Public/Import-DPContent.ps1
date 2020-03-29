function Import-DPContent {
    <#
    .SYNOPSIS
        Imports .pkgx files to the local distribution point found in the given -Folder.

        Must be run locally to the distribution point you're importing content to, and run as administrator (ExtractContent.exe requirement).
    .DESCRIPTION
        Imports .pkgx files to the local distribution point found in the given -Folder.

        Must be run locally to the distribution point you're importing content to, and run as administrator (ExtractContent.exe requirement).

        By default, this function only imports objects which are in "pending" state in the SMS_PackageStatusDistPointsSummarizer class on the site server (in console, view objects' distribution state in Monitoring > Distribution Status > Content Status).
        
        For objects which are "pending", the function looks in the given -Folder for .pkgx files and attempts to import them by calling ExtractContent.exe with those files.
        
        The .pkgx files in -Folder must match the file name pattern of "<ObjectType>_<ObjectID>.pkgx". The Export-DPContent function generates .pkgx files in this format. For example:
            512_16873723.pkgx - an Application (512, as per SMS_DPContentInfo) with CI_ID value 16873723
            258_ACC00004.pkgx - a Boot Image (258, as per SMS_DPContentInfo) with PackageID value ACC00004
            0_ACC00007.pkgx - a Package (0, as per SMS_DPContentInfo) with PackageID value ACC00007
        
        For .pkgx file that do not match this pattern, they are skipped.
        
        For .pkgx files that do match the pattern, but are not in the "pending" state, they are also skipped. Use the -ImportAllFromFolder switch to always import all matching .pkgx files.

        When calling this function, you are prompted for confirmation whether you want to import content to local host. Suppress this with -Confirm:$false.
    .PARAMETER Folder
        Folder containing .pkgx files.
    .PARAMETER ExtractContentExe
        Absolute path to ExtractContent.exe.

        The function attempts to discover the location of this exe on disk, however if it is unable to find it you will receive a terminating error and asked to use this parameter.
    .PARAMETER ImportAllFromFolder
        Import all .pkgx files found -Folder regardless as to whether the object is currently in pending state or not.
    .PARAMETER Confirm
        Suppress the prompt to continue.
    .PARAMETER SiteServer
        Query SMS_DPContentInfo on this server.
        
        It is not usually necessary to specify this parameter as importing the PSCMContentMgr module sets the $CMSiteServer variable which is the default value for this parameter.
        
        Specify this to query an alternative server, or if the module import process was unable to auto-detect and set $CMSiteServer.
    .PARAMETER SiteCode
        Site code of which the server specified by -SiteServer belongs to.
        
        It is not usually necessary to specify this parameter as importing the PSCMContentMgr module sets the $CMSiteCode variable which is the default value for this parameter.
        
        Specify this to query an alternative site, or if the module import process was unable to auto-detect and set $CMSiteCode.
    .EXAMPLE
        PS C:\> Import-DPContent -Folder "F:\prestaged"

        Imports .pkgx files found in F:\prestaged but only if the objects are in "pending" state.
    .EXAMPLE
        PS C:\> Import-DPContent -Folder "\\server\share\prestaged" -ImportAllFromFolder

        Imports all .pkgx files found in \\server\share\prestaged.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
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

        [Parameter()]
        [ValidateScript({
            if (([System.IO.File]::Exists($_) -And ($_ -like "*ExtractContent.exe"))) {
                return $true
            } else {
                throw "Invalid path or given file is not named ExtractContent.exe"
            }
        })]
        [String]$ExtractContentExe,

        [Parameter()]
        [Switch]$ImportAllFromFolder,
        
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
        if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") -eq $false) {
            $Exception = [Exception]::new("Must run as administrator")
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                "2",
                [System.Management.Automation.ErrorCategory]::PermissionDenied,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        $DistributionPoint = [System.Net.Dns]::GetHostByName($env:ComputerName).HostName        

        try {
            Resolve-DP -DistributionPoint $DistributionPoint
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($Confirm -eq $true) {
            $Title = "Importing content to '{0}'" -f $DistributionPoint
            $Question = @(
                "`nDo you want to import all .pkgx files in '{0}' to distribution point '{1}'?" -f $Folder, $DistributionPoint
                "`nNOTE: Run this command local to the distribution point you want to import content to"
            )
            $Choices = "&Yes", "&No"
            $Decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
            if ($Decision -eq 1) {
                return
            }
        }

        # Get-PSDrive instead of Get-Volume because of UAC
        :loop foreach ($Volume in (Get-PSDrive -PSProvider "FileSystem")) {
            $Paths = @(
                "{0}SMS_DP$\sms\Tools\ExtractContent.exe" -f $Volume.Root
                "{0}SMS_DP$\ExtractContent.exe" -f $Volume.Root
            )
            foreach ($Path in $Paths) {
                try {
                    if (Test-Path $Path -ErrorAction "Stop") {
                        $ExtractContentExe = $Path
                        break loop
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Error -Message ("Access denied finding ExtractContent.exe in {0}" -f (Split-Path -Parent $Path)) -Category "PermissionDenied" -CategoryTargetName $Path
                }
                catch {
                    Write-Error -ErrorRecord $_
                }
            }
        }

        if (-not $ExtractContentExe) {
            $Exception = [Exception]::new("Could not find ExtractContent.exe on disk, please use -ExtractContentExe parameter")
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                "2",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        try {
            if ($ImportAllFromFolder.IsPresent -eq $true) {
                $Files = Get-ChildItem -Path $Folder -Filter "*.pkgx" -ErrorAction "Stop"
            }
            else {
                $Namespace = "ROOT/SMS/Site_{0}" -f $SiteCode
                $Filter = "ServerNALPath like '%{0}%'" -f $DistributionPoint
                $ObjPackagesPending = (Get-CimInstance -ComputerName $SiteServer -Namespace $Namespace -ClassName "SMS_PackageStatusDistPointsSummarizer" -Filter $Filter -ErrorAction "Stop").Where{ $_.State -ne 0 }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        # TODO is there a way to dedup the lines below so there's just one Invoke-NativeCommand call?
        if ($ImportAllFromFolder.IsPresent -eq $true) {
            foreach ($File in $Files) {
                if ($File.Name -match "^(?<ObjectType>0|3|5|257|258|259|512)_(?<ObjectID>[A-Za-z0-9]+)\.pkgx$") {
                    $result = [ordered]@{ ObjectID = $Matches.ObjectID }
                    try {
                        [void](Invoke-NativeCommand $ExtractContentExe /p:$($File.FullName) /F -ErrorAction "Stop")
                        $result["Result"] = "Success"
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                        $result["Result"] = "Failed: {0}" -f $_.Exception.Message
                    }
                    [PSCustomObject]$result
                }
                else {
                    Write-Warning ("File '{0}' is not identifiable, skipping")
                }
            }
        }
        else {
            foreach ($ObjPackage in $ObjPackagesPending) {
                # All of the object type values between SMS_DPContentInfo and SMS_PackageStatusDistPointsSummarizer are similar except for Application
                $ObjectType = ([SMS_DPContentInfo]([SMS_PackageStatusDistPointsSummarizer_PackageType]$ObjPackage.PackageType).ToString()).value__
    
                if ($ObjectType -eq [SMS_DPContentInfo]"Application") {
                    $ObjectID = ConvertTo-PackageIDCIID -PackageID $ObjPackage.PackageID
                }
                else {
                    $ObjectID = $ObjPackage.PackageID
                }
    
                $FileName = "{0}_{1}.pkgx" -f $ObjectType, $ObjectID
                $Path = Join-Path -Path $Folder -ChildPath $FileName
    
                if (Test-Path $Path) {
                    Write-Verbose ("Importing '{0}'" -f $Path)
                    $result = [ordered]@{ ObjectID = $ObjectID }
                    try {
                        [void](Invoke-NativeCommand $ExtractContentExe /p:$Path /F -ErrorAction "Stop")
                        $result["Result"] = "Success"
                    }
                    catch {
                        Write-Error -ErrorRecord $_
                        $result["Result"] = "Failed: {0}" -f $_.Exception.Message
                    }
                    [PSCustomObject]$result
                }
                else {
                    Write-Warning ("Could not find {0} ({1}) '{2}'" -f $ObjectID, [SMS_DPContentInfo]$ObjectType, $Path)
                }
            }
        }
    }
    end {
    }
}