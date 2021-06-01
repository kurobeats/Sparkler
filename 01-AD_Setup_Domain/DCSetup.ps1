$Configuration = Get-Content -Path 01-AD_Setup_Domain\config.json | ConvertFrom-Json

Get-WindowsFeature -Name AD-Domain-Services | Install-WindowsFeature -Verbose

Import-Module ADDSDeployment

Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName $Configuration.domain.DomainName `
    -DomainNetbiosName $Configuration.domain.DomainNetbiosName `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$true `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword (ConvertTo-SecureString ($Configuration.domain.SafeModeAdministratorPassword) -AsPlainText -force) `
    -Force:$true