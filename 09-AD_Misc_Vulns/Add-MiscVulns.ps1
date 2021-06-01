<#
    .Synopsis
       Adds a bunch of vulns to the DC
    .DESCRIPTION
       The script was derived from @WazeHell's vulnerable-AD (https://github.com/WazeHell/vulnerable-AD)  
#>

#Base Lists 
HumansNames = @('Luca');
BadPasswords = @('redwings');
BadACL = @('GenericAll', 'GenericWrite', 'WriteOwner', 'WriteDACL', 'Self');
ServicesAccountsAndSPNs = @('mssql_svc,mssqlserver', 'http_svc,httpserver', 'exchange_svc,exserver');
CreatedUsers = @();
AllObjects = @();
Domain = (get-addomain).dnsroot;

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
        Write-Host "Creating $group Group"
        Try { New-ADGroup -name $group -GroupScope Global } Catch {}
        for ($i = 1; $i -le (Get-Random -Maximum 20); $i = $i + 1 ) {
            $randomuser = (GetRandom -InputList CreatedUsers)
            Write-Host "Adding $randomuser to $group"
            Try { Add-ADGroupMember -Identity $group -Members $randomuser } Catch {}
        }
        AllObjects += $group;
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
    foreach ($abuse in BadACL) {
        $ngroup = GetRandom -InputList NormalGroups
        $mgroup = GetRandom -InputList MidGroups
        $DstGroup = Get-ADGroup -Identity $mgroup
        $SrcGroup = Get-ADGroup -Identity $ngroup
        AddACL -Source $SrcGroup.sid -Destination $DstGroup.DistinguishedName -Rights $abuse
        Write-Host "BadACL $abuse $ngroup to $mgroup"
    }
    foreach ($abuse in BadACL) {
        $hgroup = GetRandom -InputList HighGroups
        $mgroup = GetRandom -InputList MidGroups
        $DstGroup = Get-ADGroup -Identity $hgroup
        $SrcGroup = Get-ADGroup -Identity $mgroup
        AddACL -Source $SrcGroup.sid -Destination $DstGroup.DistinguishedName -Rights $abuse
        Write-Host "BadACL $abuse $mgroup to $hgroup"
    }
    for ($i = 1; $i -le (Get-Random -Maximum 25); $i = $i + 1 ) {
        $abuse = (GetRandom -InputList BadACL);
        $randomuser = GetRandom -InputList CreatedUsers
        $randomgroup = GetRandom -InputList AllObjects
        if ((Get-Random -Maximum 2)) {
            $Dstobj = Get-ADUser -Identity $randomuser
            $Srcobj = Get-ADGroup -Identity $randomgroup
        }
        else {
            $Srcobj = Get-ADUser -Identity $randomuser
            $Dstobj = Get-ADGroup -Identity $randomgroup
        }
        AddACL -Source $Srcobj.sid -Destination $Dstobj.DistinguishedName -Rights $abuse 
        Write-Host "BadACL $abuse $randomuser and $randomgroup"
    }
}
function Kerberoasting {
    $selected_service = (GetRandom -InputList ServicesAccountsAndSPNs)
    $svc = $selected_service.split(',')[0];
    $spn = $selected_service.split(',')[1];
    $password = GetRandom -InputList BadPasswords;
    Write-Host "Kerberoasting $svc $spn"
    Try { New-ADServiceAccount -Name $svc -ServicePrincipalNames "$svc/$spn.Domain" -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -RestrictToSingleComputer -PassThru } Catch {}
    foreach ($sv in ServicesAccountsAndSPNs) {
        if ($selected_service -ne $sv) {
            $svc = $sv.split(',')[0];
            $spn = $sv.split(',')[1];
            Write-Host "Creating $svc services account"
            $password = ([System.Web.Security.Membership]::GeneratePassword(12, 2))
            Try { New-ADServiceAccount -Name $svc -ServicePrincipalNames "$svc/$spn.Domain" -RestrictToSingleComputer -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) -PassThru } Catch {}

        }
    }
}
function ASREPRoasting {
    for ($i = 1; $i -le (Get-Random -Maximum 6); $i = $i + 1 ) {
        $randomuser = (GetRandom -InputList CreatedUsers)
        $password = GetRandom -InputList BadPasswords;
        Set-AdAccountPassword -Identity $randomuser -Reset -NewPassword (ConvertTo-SecureString $password -AsPlainText -Force)
        Set-ADAccountControl -Identity $randomuser -DoesNotRequirePreAuth 1
        Write-Host "AS-REPRoasting $randomuser"
    }
}
function DnsAdmins {
    for ($i = 1; $i -le (Get-Random -Maximum 6); $i = $i + 1 ) {
        $randomuser = (GetRandom -InputList CreatedUsers)
        Add-ADGroupMember -Identity "DnsAdmins" -Members $randomuser
        Write-Host "DnsAdmins : $randomuser"
    }
    $randomg = (GetRandom -InputList MidGroups)
    Add-ADGroupMember -Identity "DnsAdmins" -Members $randomg
    Write-Host "DnsAdmins Nested Group : $randomg"
}
function DCSync {
    for ($i = 1; $i -le (Get-Random -Maximum 6); $i = $i + 1 ) {
        $randomuser = (GetRandom -InputList CreatedUsers)

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
        Write-Host "Giving DCSync to : $randomuser"
    }
}
function DisableSMBSigning {
    Set-SmbClientConfiguration -RequireSecuritySignature 0 -EnableSecuritySignature 0 -Confirm -Force
}

BadAcls
Write-Host "BadACL Done"
Kerberoasting
Write-Host "Kerberoasting Done"
ASREPRoasting
Write-Host "AS-REPRoasting Done"
DnsAdmins
Write-Host "DnsAdmins Done"
DCSync
Write-Host "DCSync Done"
DisableSMBSigning
Write-Host "SMB Signing Disabled"