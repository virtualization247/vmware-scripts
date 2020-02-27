####### Automate configuring SNMP on ESXi hosts #######
#################### version 1.0  #####################
#######################################################
<# This script will connect to both your vCenter Server,
ESXi hosts you select, update the SNMP community string
for either SNMP v1 or v2, then start or restart the
SNMP service for the change to take effect. #>
#######################################################
###################  Variables ########################
#######################################################

$vcenter = Read-Host -Prompt "Enter your vCenter Server name (FQDN)"
$vcenterCred = Get-Credential -Message "Enter your vCenter Server Credentials"
$esxiCred = Get-Credential -Message "Enter your ESXi root credentials"

#######################################################
##############  Connect to vCenter ####################
#######################################################

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false `
    -DefaultVIServerMode Multiple | Out-Null
Connect-VIServer -Server $vcenter -Credential $vcenterCred

#######################################################
###############  Get SNMP Settings ####################
#######################################################

$myHosts = Get-VMHost | Out-GridView -OutputMode Multiple
Connect-ViServer $myHosts -Credential $esxiCred
$hostSNMP = Get-VMHostSnmp -Server $myHosts.Name
Write-Host "`nThe current settings for your ESXi hosts are as follows:" `
    -ForegroundColor Blue
$hostSNMP | Select-Object VMHost,Enabled,Port,ReadOnlyCommunities | `
    Format-Table -AutoSize


#######################################################
###############  Set SNMP Settings ####################
#######################################################

$communityString = Read-Host "Enter SNMP string."
Write-Host "SNMP community string entered is: $communityString `n" `
    -ForegroundColor Blue
Write-Host "Updated settings for your ESXi hosts are as follows: `n" `
    -ForegroundColor Green
$hostSNMP = Set-VMHostSNMP $hostSNMP -Enabled:$true `
    -ReadOnlyCommunity $communityString
$hostSNMP | Select-Object VMHost,Enabled,Port,ReadOnlyCommunities | `
     Format-Table -AutoSize
$snmpStatus = $myHosts| Get-VMHostService | `
    Where-Object{$_.Key -eq "snmpd"} 

ForEach ($i in $snmpStatus) {
    if ($snmpStatus.running -eq $true) {
        $i | Restart-VMHostService -Confirm:$false | Out-Null
    }
    else {
        $i | Start-VMHostService -Confirm:$false | Out-Null
    }
}

Write-Host "SNMP service has been started on the ESXi host(s)." `
    -ForegroundColor Blue
$myHosts | Get-VMHostService | Where-Object{$_.Key -eq "snmpd"} | `
    Select-Object VMHost,Key,Running | Format-Table -AutoSize

#######################################################
#######  Disconnect from vCenter and ESXi hosts #######
#######################################################
Disconnect-VIServer -Server * -Confirm:$false