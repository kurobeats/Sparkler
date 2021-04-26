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

function Get-Agreement {
   <# 
   .DESCRIPTION
       Used to let the user know that we are starting, what the script does and gets the to confirm that they want to run the script.
   .OUTPUTS
       [Boolean]
   .FUNCTIONALITY
       Prints a warning and asks the user for enter yes to continue.
   #>

   Write-Host "Welcome to Sparkler"
   Write-Host "You are responsible for how you use this tool. It is intended for personal use only "
   Write-Host "and will leave a Production Active Directory server in an irreparable state."
   Write-Host "It is not intended for commercial use."
   $agreement = Read-Host -Prompt "Type `'yes`' to get this party started."
   $agreement.tolower()
   $result = $false
   if ($agreement -eq 'yes') {
      $result = $true
   }
   return $result
}

function Add-Domain {
   <#
   .DESCRIPTION
       Creates a new domain by calling the DCSetup script
   #>

   .($basescriptPath + '\01-AD_Setup_Domain\DCSetup.ps1')
   $ii = 0
   # Not sure why we record progress here when it is going to restart and lose state...
   Write-Progress -Activity "Task: Deploying a fresh domain." -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
   Write-Host "OK, fresh domain is setup, we need to reboot. Run Invoke-Sparkler.ps1 after reboot."
   Start-Sleep -Second 10
   Restart-Computer -f
}

function Install-LAPSSchema {
   <#
   .DESCRIPTION Installs the LASPSchema using the InstallLAPSSchema script
   #>

   .($basescriptPath + '\02-AD_LAPS_Install\InstallLAPSSchema.ps1')
   Write-Progress -Activity "Task: Install LAPS" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
}

function Add-OUStructure {
   <#
   .DESCRIPTION Adds OUs using the CreateOUStructure script
   #>
   
   .($basescriptPath + '\03-AD_OU_CreateStructure\CreateOUStructure.ps1')
   Write-Progress -Activity "Task: Creating OUs" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
}

function Add-Users {
   <#
   .DESCRIPTION Adds Users using the AD_Users_Create script
   #>

   Write-Host "Creating Users on Domain" -ForegroundColor Green
   $NumOfUsers = 1000..5000 | Get-Random #this number is the random number of users to create on a domain.  Todo: Make process createusers.ps1 in a parallel loop
   $X = 1
   Write-Progress -Activity "Task: Creating Users" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
   $ii++
  
   .($basescriptPath + '\04-AD_Users_Create\CreateUsers.ps1')
   $createuserscriptpath = $basescriptPath + '\04-AD_Users_Create\'

   $ousAll = Get-ADOrganizationalUnit -filter *

   do {
      createuser -Domain $Domain -OUList $ousAll -ScriptDir $createuserscriptpath
      Write-Progress -Activity "Task: Creating $NumOfUsers Users" -Status "Progress:" -PercentComplete ($jj / $NumOfUsers * 100)
      $jj++
   }while ($jj -lt $NumOfUsers)
}

function Add-Groups {
   <#
   .DESCRIPTION Adds Groups using the CreateGroups script
   #>

   Write-Host "Creating Groups on Domain" -ForegroundColor Green
   $NumOfGroups = 100..500 | Get-Random 
   $jj = 1
   Write-Progress -Activity "Task: Creating $NumOfGroups Groups" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
   
   .($basescriptPath + '\05-AD_Groups_Create\CreateGroups.ps1')
   
   do {
      Creategroup
      Write-Progress -Activity "Task: Creating $NumOfGroups Groups" -Status "Progress:" -PercentComplete ($jj / $NumOfGroups * 100)
      $jj++
   }while ($jj -lt $NumOfGroups)
}

function Add-Computers {
   <#
   .DESCRIPTION Adds Computers using the CreateComputers script
   #>

   Write-Host "Creating Computers on Domain" -ForegroundColor Green
   $NumOfComps = 50..150 | Get-Random 
   $jj = 1
   Write-Progress -Activity "Task: Creating Computers" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
   
   .($basescriptPath + '\06-AD_Computers_Create\CreateComputers.ps1')
   do {
      Write-Progress -Activity "Task: Creating $NumOfComps computers" -Status "Progress:" -PercentComplete ($jj / $NumOfComps * 100)
      createcomputer
      $jj++
   }while ($jj -lt $NumOfComps)
}

function Add-Permissions {
   <#
   .DESCRIPTION Adds Permissions using the GenerateRandomPermissions and AddToRandomGroups scripts script
   #>

   $AllUsers = Get-ADUser -Filter *
   $Grouplist = Get-ADGroup -Filter { GroupCategory -eq "Security" -and GroupScope -eq "Global" } -Properties isCriticalSystemObject
   $LocalGroupList = Get-ADGroup -Filter { GroupScope -eq "domainlocal" } -Properties isCriticalSystemObject
   $Complist = Get-ADComputer -filter *

   Write-Host "Creating Permissions on Domain" -ForegroundColor Green
   Write-Progress -Activity "Task: Creating Random Permissions" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
  
   .($basescriptPath + '\07-AD_Permissions_Randomiser\GenerateRandomPermissions.ps1')
   $ii++
   Write-Host "Nesting objects into groups on Domain" -ForegroundColor Green
}

function Add-ToGroups {
   <#
   .DESCRIPTION Adds Random things to groups using the AddToRandomGroups script
   #>

   .($basescriptPath + '\08-AD_Random_Groups\AddRandomToGroups.ps1')
   Write-Progress -Activity "Task: Adding Stuff to Stuff and Things" -Status "Progress:" -PercentComplete ($ii / $totalscripts * 100)
   AddRandomToGroups -Domain $Domain -Userlist $AllUsers -GroupList $Grouplist -LocalGroupList $LocalGroupList -complist $Complist
}

function Invoke-Sparkler {
   <#
   .DESCRIPTION
       Used to get the script rolling. Only responsible for handling basic logic around how the script runs and the order that other functions are called.
   .OUTPUTS
       [String]
   .FUNCTIONALITY
       Adds Users, Groups, OUs, Computers, and a vast amount of ACLs in a domain.
   #>
   if (Get-Agreement) {
      $basescriptPath = Split-Path -Parent $PSCommandPath
      $totalscripts = 9
      $ii = 0
      $Domain = Get-ADDomain
      # cls
      if (!$Domain) {
         Add-Domain
      }
      # I would prefer a different way of recording progress than this but it will do for now.
      Install-LAPSSchema
      $ii++
      Add-OUStructure
      $ii++
      Add-Users
      $ii++
      Add-Groups
      $ii++
      Add-Computers
      $ii++
      Add-Permissions
      $ii++
      Add-ToGroups
   }
   else {
      exit
   }
}

Invoke-Sparkler