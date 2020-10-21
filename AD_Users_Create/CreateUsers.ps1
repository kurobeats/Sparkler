Function CreateUser{

    <#
        .SYNOPSIS
            Creates a user in an active directory environment based on random data
        
        .DESCRIPTION
            Starting with the root container this tool randomly places users in the domain.
        
        .PARAMETER Domain
            The stored value of get-addomain is used for this.  It is used to call the PDC and other items in the domain
        
        .PARAMETER OUList
            The stored value of get-adorganizationalunit -filter *.  This is used to place users in random locations.
        
        .PARAMETER ScriptDir
            The location of the script.  Pulling this into a parameter to attempt to speed up processing.
        
        .EXAMPLE
            
     
        
        .NOTES
            
            
            Unless required by applicable law or agreed to in writing, software
            distributed under the License is distributed on an "AS IS" BASIS,
            WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
            See the License for the specific language governing permissions and
            limitations under the License.    
        
    #>
    [CmdletBinding()]
    
    param
    (
        [Parameter(Mandatory = $false,
            Position = 1,
            HelpMessage = 'Supply a result from get-addomain')]
            [Object[]]$Domain,
        [Parameter(Mandatory = $false,
            Position = 2,
            HelpMessage = 'Supply a result from get-adorganizationalunit -filter *')]
            [Object[]]$OUList,
        [Parameter(Mandatory = $false,
            Position = 3,
            HelpMessage = 'Supply the script directory for where this script is stored')]
        [string]$ScriptDir
    )
    
        if(!$PSBoundParameters.ContainsKey('Domain')){
                $setDC = (Get-ADDomain).pdcemulator
                $dnsroot = (get-addomain).dnsroot
            }
            else {
                $setDC = $Domain.pdcemulator
                $dnsroot = $Domain.dnsroot
            }
        if (!$PSBoundParameters.ContainsKey('OUList')){
            $OUsAll = get-adobject -Filter {objectclass -eq 'organizationalunit'} -ResultSetSize 300
        }else {
            $OUsAll = $OUList
        }
        if (!$PSBoundParameters.ContainsKey('ScriptDir')){
            function Get-ScriptDirectory {
                Split-Path -Parent $PSCommandPath
            }
            $scriptPath = Get-ScriptDirectory
        }else{
            $scriptpath = $scriptdir
        }
    
    $ouLocation = (Get-Random $OUsAll).distinguishedname
    
    
    
    $accountType = 1..100|get-random 
    if($accountType -le 10){ # X percent chance of being a service account
    #service
    $nameSuffix = "SA"
    $description = ''
    #removing do while loop and making random number range longer, sorry if the account is there already
    # this is so that I can attempt to import multithreading on user creation
    
        $name = ""+ (Get-Random -Minimum 100 -Maximum 9999999999) + "$nameSuffix"
        
        
    }else{
        $surname = get-content($scriptpath + '\Names\family_names.txt')|get-random
    $genderpreference = 0,1|get-random
    if ($genderpreference -eq 0){$givenname = get-content($scriptpath + '\Names\female_names.txt')|get-random}else{$givenname = get-content($scriptpath + '\Names\male_names.txt')|get-random}
    $name = $givenname+"."+$surname
    }
    
        $departmentnumber = [convert]::ToInt32('9999999') 
        
        
    #Need to figure out how to do the L attribute
    $description = ''
    $passStrings = Get-Content "Passwords\passwords.txt"
    # Select random object
    $pwd = Get-Random -InputObject $passStrings -Count 1

    $passwordinDesc = 1..1000|get-random
    if ($passwordinDesc -lt 10) {
        $description = 'The account password is ' + $pwd
    }else{}

    new-aduser -server $setdc -Description $Description -DisplayName $name -Name $name -SamAccountName $name -GivenName $givenname -Surname $surname -Enabled $true -Path $ouLocation -AccountPassword (ConvertTo-SecureString ($pwd) -AsPlainText -force)

    $pwd = ''
    
    #===============================
    #SET ATTRIBUTES - no additional attributes set at this time besides UPN
    #Todo: Set SPN for kerberoasting.  Example attribute edit is in createcomputers.ps1
    #===============================
    
    $upn = $name + '@' + $dnsroot
    try{Set-ADUser -Identity $name -UserPrincipalName "$upn" }
    catch{}
    
    ################################
    #End Create User Objects
    ################################
    
    }
    
    
    