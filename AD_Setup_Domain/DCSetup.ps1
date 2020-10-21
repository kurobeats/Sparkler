$Configuration = import-ini config.ini 

Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -name Shell -Value $Configuration["shell"]["DefaultShell"]

Get-WindowsFeature -Name AD-Domain-Services|Install-WindowsFeature -Verbose

Import-Module ADDSDeployment

Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName $Configuration["domain"]["DomainName"] `
-DomainNetbiosName $Configuration["domain"]["DomainNetbiosName"] `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true