<#
    .Synopsis
       Generates users, groups, OUs, computers in an active directory domain.  Then places ACLs on random OUs.
    .DESCRIPTION
       This tool is for research purposes and training only.  Intended only for personal use.  This adds a large number of objects into a domain, and should never be  run in production.
    .EXAMPLE
       There are currently no parameters for the tool.  Simply run the ps1 as a DA and it begins. Follow the prompts and type 'yes' when appropriate and the tool runs.
    .OUTPUTS
       [String]
    .NOTES
       Forked from BadBlood which was written by David Rowe and mashed together with kurobeats' Active-Directory-User-Script.
       None of the authors, contributors, sponsors, or anyone else connected with Sparkler in any way whatsoever can be responsible for any damage caused by using this tool. Sparkler is designed to create randomised active directory deployments to enable learning.  
    .FUNCTIONALITY
       Adds Users, Groups, OUs, Computers, and a vast amount of ACLs in a domain.
    .LINK
       https://github.com/kurobeats/Sparkler
   
    #>

function Get-ScriptDirectory {
   Split-Path -Parent $PSCommandPath
}
$basescriptPath = Get-ScriptDirectory
$totalscripts = 9

$i = 0
cls
write-host "Welcome to Sparkler"
write-host "You are responsible for how you use this tool. It is intended for personal use only "
write-host "and will leave a Production Active Directory server in an irreparable state."
write-host "It is not intended for commercial use."
$agreement = Read-Host -Prompt "Type `'yes`' to get this party started."
$agreement.tolower()
if ($agreement -ne 'yes') { exit }
if ($agreement -eq 'yes') {
   $Domain = Get-addomain
   if (!$Domain) {
      .($basescriptPath + '\AD_Setup_Domain\DCSetup.ps1')
      Write-Progress -Activity "Task: Deploying a fresh domain." -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
      $I++
      write-host "OK, fresh domain is setup, we need to reboot. Run Invoke-Sparkler.ps1 after reboot."
      Start-Sleep -Second 10
      Restart-Computer -f
   }
   else {}

   .($basescriptPath + '\AD_LAPS_Install\InstallLAPSSchema.ps1')
   Write-Progress -Activity "Task: Install LAPS" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
   $I++
   
   .($basescriptPath + '\AD_OU_CreateStructure\CreateOUStructure.ps1')
   Write-Progress -Activity "Task: Creating OUs" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
   $I++
   $ousAll = Get-adorganizationalunit -filter *
   write-host "Creating Users on Domain" -ForegroundColor Green
   $NumOfUsers = 1000..5000 | Get-random #this number is the random number of users to create on a domain.  Todo: Make process createusers.ps1 in a parallel loop
   $X = 1
   Write-Progress -Activity "Task: Creating Users" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
   $I++
   
   .($basescriptPath + '\AD_Users_Create\CreateUsers.ps1')
   $createuserscriptpath = $basescriptPath + '\AD_Users_Create\'
   do {
      createuser -Domain $Domain -OUList $ousAll -ScriptDir $createuserscriptpath
      Write-Progress -Activity "Task: Creating $NumOfUsers Users" -Status "Progress:" -PercentComplete ($x / $NumOfUsers * 100)
      $x++
   }while ($x -lt $NumOfUsers)
   $AllUsers = Get-aduser -Filter *
   write-host "Creating Groups on Domain" -ForegroundColor Green
   $NumOfGroups = 100..500 | Get-random 
   $X = 1
   Write-Progress -Activity "Task: Creating $NumOfGroups Groups" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
   $I++
    
   .($basescriptPath + '\AD_Groups_Create\CreateGroups.ps1')
    
   do {
      Creategroup
      Write-Progress -Activity "Task: Creating $NumOfGroups Groups" -Status "Progress:" -PercentComplete ($x / $NumOfGroups * 100)
    
      $x++
   }while ($x -lt $NumOfGroups)
   $Grouplist = Get-ADGroup -Filter { GroupCategory -eq "Security" -and GroupScope -eq "Global" } -Properties isCriticalSystemObject
   $LocalGroupList = Get-ADGroup -Filter { GroupScope -eq "domainlocal" } -Properties isCriticalSystemObject
   write-host "Creating Computers on Domain" -ForegroundColor Green
   $NumOfComps = 50..150 | Get-random 
   $X = 1
   Write-Progress -Activity "Task: Creating Computers" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
    
   .($basescriptPath + '\AD_Computers_Create\CreateComputers.ps1')
   $I++
   do {
      Write-Progress -Activity "Task: Creating $NumOfComps computers" -Status "Progress:" -PercentComplete ($x / $NumOfComps * 100)
      createcomputer
      $x++
   }while ($x -lt $NumOfComps)
   $Complist = get-adcomputer -filter *
   $I++
   write-host "Creating Permissions on Domain" -ForegroundColor Green
   Write-Progress -Activity "Task: Creating Random Permissions" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
   
   .($basescriptPath + '\AD_Permissions_Randomizer\GenerateRandomPermissions.ps1')
   $I++
   write-host "Nesting objects into groups on Domain" -ForegroundColor Green
   
   .($basescriptPath + '\AD_Groups_Create\AddRandomToGroups.ps1')
   Write-Progress -Activity "Task: Adding Stuff to Stuff and Things" -Status "Progress:" -PercentComplete ($i / $totalscripts * 100)
   AddRandomToGroups -Domain $Domain -Userlist $AllUsers -GroupList $Grouplist -LocalGroupList $LocalGroupList -complist $Complist
    
}
