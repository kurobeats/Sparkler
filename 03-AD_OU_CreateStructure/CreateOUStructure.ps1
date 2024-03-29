﻿#
#GET ALL AFFILIATE CODES FROM ALL OUS in production
function Get-ScriptDirectory {
    Split-Path -Parent $PSCommandPath
}
$scriptPath = Get-ScriptDirectory

$TopLevelOUs = @('Admin', 'Global', 'National', 'Staging', 'Quarantine', 'Staff', 'Testing', 'SCADA', 'Russia', 'Australia', 'SouthAmerica', 'Asia', 'Canada', 'UK')
    
$AdminSubOUs = @('Enterprise', 'Global', 'National', 'Staging') 
#loop before the ou name by making T#-OBJECT name as the OU
$AdminobjectOUs = @('Accounts', 'Servers', 'Devices', 'Permissions', 'Roles') 
#########################
$skipSubOUs = @('Disabled', 'Quarantine', 'Groups')
#########################
#$tierOUs = @('Global', 'National')
$ObjectSubOUs = @('ServiceAccounts', 'Groups', 'Devices', 'Test', 'Managed')


#Consodated list of all 3 letter codes which IAM uses. 
$3LetterCodeCSV = $scriptPath + '\3lettercodes.csv'


Set-Location c:
$dn = (Get-ADDomain).distinguishedname
#=============================================
#ROUND:1
#Create Top Level OUS
#=============================================
Write-host "Creating Tiered OU Structure" -ForegroundColor Green
$topOUCount = $TopLevelOUs.count
$x = 1
foreach ($name in $TopLevelOUs) {
    Write-Progress -Activity "Deploying OU Structure" -Status "Top Level OU Status:" -PercentComplete ($x / $topOUCount * 100)
    New-ADOrganizationalUnit -Name $Name -ProtectedFromAccidentalDeletion:$true
    $fulldn = "OU=" + $name + "," + $dn 
    #$toplevelouinfo = Get-ADOrganizationalUnit $fulldn
    #=====================================================================================
    #ROUND:2
    #Create First level Down Sub OUs in Privileged Access, and Provisioned Users
    #=====================================================================================
    if ($name -eq $TopLevelOUs[0]) {

        foreach ($adminsubou in $AdminSubOUs) {
            New-ADOrganizationalUnit -Name $adminsubou -Path $fulldn
            $adminsubfulldn = "OU=" + $adminsubou + "," + $fulldn
                    
            if ($adminsubou -eq "Staging") {                          
            }     
                                 
            else {
                foreach ($AdminobjectOU in $AdminobjectOUs) {
                    #add name together
                    if ($adminsubou -eq 'Enterprise') { $adminOUPrefix = "T0-" }
                    elseif ($adminsubou -eq 'Global') { $adminOUPrefix = "T1-" }
                    elseif ($adminsubou -eq 'National') { $adminOUPrefix = "T2-" }
                    $adminobjectoucombo = $adminOUPrefix + $adminobjectou

                    New-ADOrganizationalUnit -Name $adminobjectoucombo -Path $adminsubfulldn
                }
            }
        }
    }
    elseif ($skipSubOUs -contains $name) {
        #this skips the creation of the sub containers
    }
    elseif (($name -eq 'Global') -or ($name -eq 'National') -or ($name -eq 'Stage')) {
        $fulldn = "OU=" + $name + "," + $dn 
        $csvlist = @()
        $csvlist = import-csv $3LetterCodeCSV

        foreach ($ou in $csvlist) {
            New-ADOrganizationalUnit -Name ($ou.name) -Path $fulldn -Description ($ou.description)
            $csvdn = "OU=" + $ou.name + "," + $fulldn 
            
            foreach ($ObjectSubOU in $ObjectSubOUs) {
                New-ADOrganizationalUnit -Name $ObjectSubOU -Path $csvdn
                $Objectfulldn = "OU=" + $ObjectSubOU + "," + $csvdn
            }
        }
    }

    elseif (($name -eq 'Staff')) {
        $fulldn = "OU=" + $name + "," + $dn 
        $csvlist = @()
        $csvlist = import-csv $3LetterCodeCSV
        


        foreach ($ou in $csvlist) {
            New-ADOrganizationalUnit -Name ($ou.name) -Path $fulldn -Description ($ou.description)
            $csvdn = "OU=" + $ou.name + "," + $fulldn 
            
        }
        #Create Two Sub OUs in Staff OU required for IDM provisioning 
        New-ADOrganizationalUnit -Name 'Disabled' -Path $fulldn -Description 'User account that have been Disabled by the IDM System'
        New-ADOrganizationalUnit -Name 'Unassociated' -Path $fulldn -Description 'User Object that do have have any department affliation'
    }
    
    else {}
    $x++
}
    





