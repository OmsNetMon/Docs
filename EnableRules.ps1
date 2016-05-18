
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$False)]
  [string]$portNumber="8084",
[switch]$DisableRule #by default it is false
)

$firewallRuleName="NPMDFirewallRule"
$firewallRuleDescription = "NPMD Firewall port exception"
$processName = "NPMDAgent.exe"
$protocolName = "tcp"
$direction = "in"

$ICMPv4DestinationUnreachableRuleName = "NPMDICMPV4DestinationUnreachable"
$ICMPv4TimeExceededRuleName = "NPMDICMPV4TimeExceeded"
$ICMPv6DestinationUnreachableRuleName = "NPMDICMPV6DestinationUnreachable"
$ICMPv6TimeExceededRuleName = "NPMDICMPV6TimeExceeded"

$registryPath = "HKLM:\Software\Microsoft"
$keyName = "NPMD"
$NPMDPath = "HKLM:\Software\Microsoft\NPMD"
$NPMDLogRegistryPath = "Registry::HKEY_USERS\S-1-5-20\Software\Microsoft"
$NPMDLogKeyPath = "Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\NPMD"
$portNumberName = "PortNumber"
$logLocationName = "LogLocation"
$enableLogName = "EnableLog"

#Creates or deletes firewall rule based on disable rule flag
#Incase rule already created if it is just update of port number it just updates rule
function EnableDisableFirewallRule
{
    #Check if the ICMPv4 firewall rules already exist
    $icmpV4DURuleExists = 1;
    $existingRule = netsh advfirewall firewall show rule name=$ICMPv4DestinationUnreachableRuleName
    if(!($existingRule -cmatch $ICMPv4DestinationUnreachableRuleName))
    { 
        $icmpV4DURuleExists = 0;
    }

    $icmpV4TERuleExists = 1;
    $existingRule = netsh advfirewall firewall show rule name=$ICMPv4TimeExceededRuleName
    if(!($existingRule -cmatch $ICMPv4TimeExceededRuleName))
    { 
        $icmpV4TERuleExists = 0;
    }        
	
    #Check if the ICMPv6 firewall rule already exists
    $icmpV6DURuleExists = 1;
    $existingRule = netsh advfirewall firewall show rule name=$ICMPv6DestinationUnreachableRuleName
    if(!($existingRule -cmatch $ICMPv6DestinationUnreachableRuleName))
    { 
        $icmpV6DURuleExists = 0;
    }

    $icmpV6TERuleExists = 1;
    $existingRule = netsh advfirewall firewall show rule name=$ICMPv6TimeExceededRuleName
    if(!($existingRule -cmatch $ICMPv6TimeExceededRuleName))
    { 
        $icmpV6TERuleExists = 0;
    }
    		
    if(!($DisableRule))
    {
        #TCP Firewall Rule
        $existingRule = netsh advfirewall firewall show rule name=$firewallRuleName
        if(!($existingRule -cmatch $firewallRuleName))
        { 
            netsh advfirewall firewall add rule action="Allow" Description=$firewallRuleDescription Dir=$direction LocalPort=$portNumber Name=$firewallRuleName Protocol=$protocolName
        }
        else
        {
            if(!($existingRule.LocalPort -cmatch $portNumber))
            {
                netsh advfirewall firewall set rule name=$firewallRuleName new LocalPort=$portNumber
            }
        }
		
        #ICMPv4 firewall rule
        if($icmpV4DURuleExists -eq 0)
        {
            netsh advfirewall firewall add rule name=$ICMPv4DestinationUnreachableRuleName protocol="icmpv4:3,any" dir=in action=allow
        }

        if($icmpV4TERuleExists -eq 0)
        {
            netsh advfirewall firewall add rule name=$ICMPv4TimeExceededRuleName protocol="icmpv4:11,any" dir=in action=allow
        }
		
        #ICMPv6 firewall rule
        if($icmpV6DURuleExists -eq 0)
        {
            netsh advfirewall firewall add rule name=$ICMPv6DestinationUnreachableRuleName protocol="icmpv6:1,any" dir=in action=allow
        }

        if($icmpV6TERuleExists -eq 0)
        {
            netsh advfirewall firewall add rule name=$ICMPv6TimeExceededRuleName protocol="icmpv6:3,any" dir=in action=allow
        }
    }
    else
    {
        netsh advfirewall firewall delete rule name=$firewallRuleName
        #Remove ICMPv4 firewall rules
        if($icmpV4DURuleExists -eq 1)
        {
            netsh advfirewall firewall delete rule name=$ICMPv4DestinationUnreachableRuleName
        }

        if($icmpV4TERuleExists -eq 1)
        {
            netsh advfirewall firewall delete rule name=$ICMPv4TimeExceededRuleName
        }
		
        #Remove ICMPv6 firewall rules
        if($icmpV6DURuleExists -eq 1)
        {
            netsh advfirewall firewall delete rule name=$ICMPv6DestinationUnreachableRuleName
        }

        if($icmpV6TERuleExists -eq 1)
        {
            netsh advfirewall firewall delete rule name=$ICMPv6TimeExceededRuleName
        }
    }

    CreateDeleteRegistry
}

#Creates or deletes registry based on disablerule flag
#In case registry already created, if it just update of port number it updates port on registry
function CreateDeleteRegistry
{
    if(!($DisableRule))
    {
        if(!(Test-Path -Path $NPMDPath))
        {
            New-Item -Path $registryPath -Name $keyName
            New-ItemProperty -Path $NPMDPath -Name $portNumberName -Value $portNumber -PropertyType DWORD
        }
        else
        {
            Set-ItemProperty -Path $NPMDPath -Name $portNumberName -Value $portNumber
        }
        #Key path to set Log key for Network Service SID
        if(!(Test-Path -Path $NPMDLogKeyPath))
        {
            New-Item -Path $NPMDLogRegistryPath -Name $keyName
            New-ItemProperty -Path $NPMDLogKeyPath -Name $logLocationName
            New-ItemProperty -Path $NPMDLogKeyPath -Name $enableLogName -Value 0 -PropertyType DWORD
        }
        SetAclOnRegistry $NPMDPath
        SetAclOnRegistry $NPMDLogKeyPath

    }
    else
    {
        if((Test-Path -Path $NPMDPath))
        {
            Remove-Item -Path $NPMDPath
        }
        if((Test-Path -Path $NPMDLogKeyPath))
        {
            Remove-Item -Path $NPMDLogKeyPath
        }
    }
    
}

#set acl to network service to read registry
function SetAclOnRegistry([string] $path)
{
    $acl = Get-Acl -Path $path
    $inherit = [system.security.accesscontrol.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $propagation = [system.security.accesscontrol.PropagationFlags]"None"
    $rule=new-object system.security.accesscontrol.registryaccessrule "NETWORK SERVICE","ReadKey",$inherit,$propagation,"Allow"
    $acl.addaccessrule($rule)
    $acl|set-acl
}

#Script starts here
EnableDisableFirewallRule