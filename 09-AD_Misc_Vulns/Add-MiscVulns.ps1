<#
    .Synopsis
       Adds a bunch of vulns to the DC
    .DESCRIPTION
       The script was derived from @WazeHell's vulnerable-AD (https://github.com/WazeHell/vulnerable-AD)  
    #>

#Base Lists 
$Global:HumansNames = @('Luca');
$Global:BadPasswords = @('redwings');
$Global:HighGroups = @('Office Admin', 'IT Admins', 'Executives');
$Global:MidGroups = @('Senior management', 'Project management');
$Global:NormalGroups = @('marketing', 'sales', 'accounting');
$Global:BadACL = @('GenericAll', 'GenericWrite', 'WriteOwner', 'WriteDACL', 'Self');
$Global:ServicesAccountsAndSPNs = @('mssql_svc,mssqlserver', 'http_svc,httpserver', 'exchange_svc,exserver');
$Global:CreatedUsers = @();
$Global:AllObjects = @();
$Global:Domain = "";
#Strings 
$Global:Spacing = "`t"
$Global:PlusLine = "`t[+]"
$Global:ErrorLine = "`t[-]"
$Global:InfoLine = "`t[*]"
function Write-Good { param( $String ) Write-Host $Global:PlusLine  $String -ForegroundColor 'Green' }
function Write-Bad { param( $String ) Write-Host $Global:ErrorLine $String -ForegroundColor 'red' }
function Write-Info { param( $String ) Write-Host $Global:InfoLine $String -ForegroundColor 'gray' }

function GetRandom {
    Param(
        [array]$InputList
    )
    return Get-Random -InputObject $InputList
}

function AddADGroup {
    Param(
        [array]$GroupList
    )
    foreach ($group in $GroupList) {
        Write-Info "Creating $group Group"
        Try { New-ADGroup -name $group -GroupScope Global } Catch {}
        for ($i = 1; $i -le (Get-Random -Maximum 20); $i = $i + 1 ) {
            $randomuser = (GetRandom -InputList $Global:CreatedUsers)
            Write-Info "Adding $randomuser to $group"
            Try { Add-ADGroupMember -Identity $group -Members $randomuser } Catch {}
        }
        $Global:AllObjects += $group;
    }
}
function AddACL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Security.Principal.IdentityReference]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Rights

    )
    $ADObject = [ADSI]("LDAP://" + $Destination)
    $identity = $Source
    $adRights = [System.DirectoryServices.ActiveDirectoryRights]$Rights
    $type = [System.Security.AccessControl.AccessControlType] "Allow"
    $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity, $adRights, $type, $inheritanceType
    $ADObject.psbase.ObjectSecurity.AddAccessRule($ACE)
    $ADObject.psbase.commitchanges()
}
function BadAcls {
    foreach ($abuse in $Global:BadACL) {
        $ngroup = GetRandom -InputList $Global:NormalGroups
        $mgroup = GetRandom -InputList $Global:MidGroups
        $DstGroup = Get-ADGroup -Identity $mgroup
        $SrcGroup = Get-ADGroup -Identity $ngroup
        AddACL -Source $SrcGroup.sid -Destination $DstGroup.DistinguishedName -Rights $abuse
        Write-Info "BadACL $abuse $ngroup to $mgroup"
    }
    foreach ($abuse in $Global:BadACL) {
        $hgroup = GetRandom -InputList $Global:HighGroups
        $mgroup = GetRandom -InputList $Global:MidGroups
        $DstGroup = Get-ADGroup -Identity $hgroup
        $SrcGroup = Get-ADGroup -Identity $mgroup
        AddACL -Source $SrcGroup.sid -Destination $DstGroup.DistinguishedName -Rights $abuse
        Write-Info "BadACL $abuse $mgroup to $hgroup"
    }
    for ($i = 1; $i -le (Get-Random -Maximum 25); $i = $i + 1 ) {
        $abuse = (GetRandom -InputList $Global:BadACL);
        $randomuser = GetRandom -InputList $Global:CreatedUsers
        $randomgroup = GetRandom -InputList $Global:AllObjects
        if ((Get-Random -Maximum 2)) {
            $Dstobj = Get-ADUser -Identity $randomuser
            $Srcobj = Get-ADGroup -Identity $randomgroup
        }
        else {
            $Srcobj = Get-ADUser -Identity $randomuser
            $Dstobj = Get-ADGroup -Identity $randomgroup
        }
        AddACL -Source $Srcobj.sid -Destination $Dstobj.DistinguishedName -Rights $abuse 
        Write-Info "BadACL $abuse $randomuser and $randomgroup"
    }
}
function Kerberoasting {
    $selected_service = (GetRandom -InputList $Global:ServicesAccountsAndSPNs)
    $svc = $selected_service.split(',')[0];
    $spn = $selected_service.split(',')[1];
    $password = GetRandom -InputList $Global:BadPasswords;
    Write-Info "Kerberoasting $svc $spn"
    Try { New-ADServiceAccount -Name $svc -ServicePrincipalNames "$svc/$spn.$Global:Domain" -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -RestrictToSingleComputer -PassThru } Catch {}
    foreach ($sv in $Global:ServicesAccountsAndSPNs) {
        if ($selected_service -ne $sv) {
            $svc = $sv.split(',')[0];
            $spn = $sv.split(',')[1];
            Write-Info "Creating $svc services account"
            $password = ([System.Web.Security.Membership]::GeneratePassword(12, 2))
            Try { New-ADServiceAccount -Name $svc -ServicePrincipalNames "$svc/$spn.$Global:Domain" -RestrictToSingleComputer -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -PassThru } Catch {}

        }
    }
}
function ASREPRoasting {
    for ($i = 1; $i -le (Get-Random -Maximum 6); $i = $i + 1 ) {
        $randomuser = (GetRandom -InputList $Global:CreatedUsers)
        $password = GetRandom -InputList $Global:BadPasswords;
        Set-AdAccountPassword -Identity $randomuser -Reset -NewPassword (ConvertTo-SecureString $password -AsPlainText -Force)
        Set-ADAccountControl -Identity $randomuser -DoesNotRequirePreAuth 1
        Write-Info "AS-REPRoasting $randomuser"
    }
}
function DnsAdmins {
    for ($i = 1; $i -le (Get-Random -Maximum 6); $i = $i + 1 ) {
        $randomuser = (GetRandom -InputList $Global:CreatedUsers)
        Add-ADGroupMember -Identity "DnsAdmins" -Members $randomuser
        Write-Info "DnsAdmins : $randomuser"
    }
    $randomg = (GetRandom -InputList $Global:MidGroups)
    Add-ADGroupMember -Identity "DnsAdmins" -Members $randomg
    Write-Info "DnsAdmins Nested Group : $randomg"
}
function DCSync {
    for ($i = 1; $i -le (Get-Random -Maximum 6); $i = $i + 1 ) {
        $randomuser = (GetRandom -InputList $Global:CreatedUsers)

        $userobject = (Get-ADUser -Identity $randomuser).distinguishedname
        $ACL = Get-Acl -Path "AD:\$userobject"
        $sid = (Get-ADUser -Identity $randomuser).sid

        $objectGuidGetChanges = New-Object Guid 1131f6aa-9c07-11d1-f79f-00c04fc2dcd2
        $ACEGetChanges = New-Object DirectoryServices.ActiveDirectoryAccessRule($sid, 'ExtendedRight', 'Allow', $objectGuidGetChanges)
        $ACL.psbase.AddAccessRule($ACEGetChanges)

        $objectGuidGetChanges = New-Object Guid 1131f6ad-9c07-11d1-f79f-00c04fc2dcd2
        $ACEGetChanges = New-Object DirectoryServices.ActiveDirectoryAccessRule($sid, 'ExtendedRight', 'Allow', $objectGuidGetChanges)
        $ACL.psbase.AddAccessRule($ACEGetChanges)

        $objectGuidGetChanges = New-Object Guid 89e95b76-444d-4c62-991a-0facbeda640c
        $ACEGetChanges = New-Object DirectoryServices.ActiveDirectoryAccessRule($sid, 'ExtendedRight', 'Allow', $objectGuidGetChanges)
        $ACL.psbase.AddAccessRule($ACEGetChanges)

        Set-ADUser $randomuser -Description "Replication Account"
        Write-Info "Giving DCSync to : $randomuser"
    }
}
function DisableSMBSigning {
    Set-SmbClientConfiguration -RequireSecuritySignature 0 -EnableSecuritySignature 0 -Confirm -Force
}

function Invoke-VulnAD {
    $Global:Domain = $DomainName
    Set-ADDefaultDomainPasswordPolicy -Identity $Global:Domain -LockoutDuration 00:01:00 -LockoutObservationWindow 00:01:00 -ComplexityEnabled $false -ReversibleEncryptionEnabled $False -MinPasswordLength 4
    AddADGroup -GroupList $Global:HighGroups
    Write-Good "$Global:HighGroups Groups Created"
    AddADGroup -GroupList $Global:MidGroups
    Write-Good "$Global:MidGroups Groups Created"
    AddADGroup -GroupList $Global:NormalGroups
    Write-Good "$Global:NormalGroups Groups Created"
    BadAcls
    Write-Good "BadACL Done"
    Kerberoasting
    Write-Good "Kerberoasting Done"
    ASREPRoasting
    Write-Good "AS-REPRoasting Done"
    DnsAdmins
    Write-Good "DnsAdmins Done"
    DCSync
    Write-Good "DCSync Done"
    DisableSMBSigning
    Write-Good "SMB Signing Disabled"
}