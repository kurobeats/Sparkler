Function CreateGroup {

    
    $setDC = (Get-ADDomain).pdcemulator
    
    #=======================================================================
    #P1
    #set owner and creator here
    
    #p1
    $userlist = get-aduser -ResultSetSize 2500 -Server $setdc -Filter *
    $ownerinfo = get-random $userlist
    
    $Description = ''
    
    #================================
    # OU LOCATION
    #================================
    $OUsAll = get-adobject -Filter { objectclass -eq 'organizationalunit' } -ResultSetSize 300
    #will work on adding objects to containers later $ousall += get-adobject -Filter {objectclass -eq 'container'} -ResultSetSize 300|where-object -Property objectclass -eq 'container'|where-object -Property distinguishedname -notlike "*}*"|where-object -Property distinguishedname -notlike  "*DomainUpdates*"

    $ouLocation = (Get-Random $OUsAll).distinguishedname

    #==========================================
    #END OU WORKFLOW
    
    function Get-ScriptDirectory {
        Split-Path -Parent $PSCommandPath
    }
    $groupscriptPath = Get-ScriptDirectory
           
    $GroupNameFull = try { (get-content($groupscriptPath + '\groups.txt') | get-random).substring(0, 9) } catch { (get-content($groupscriptPath + '\groups.txt') | get-random).substring(0, 3) }                                                
    
    #=============================================
    #ATTEMPTING TO CREATE GROUP
    #=============================================
    try { New-ADGroup -Server $setdc -Description $Description -Name $GroupNameFull -Path $ouLocation -GroupCategory Security -GroupScope Global -ManagedBy $ownerinfo.distinguishedname }
    catch {
        #oopsie
    }    
}
