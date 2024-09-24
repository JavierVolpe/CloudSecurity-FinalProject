# TODO: Install / Import all Az Modules

# Connect to Azure
Connect-AzAccount

# Variables
$resourceGroupName = "MyResourceGroup"
$location = "UKSouth" # westeurope
$vmSize = "Standard_D2s_v3"
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString "A987dministrator." -AsPlainText -Force
$adminCredential = New-Object System.Management.Automation.PSCredential($adminUsername, $adminPassword)
# $subscriptionId = (Get-AzContext).Subscription.Id

# Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create Public IP for Load Balancer
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "MyPublicIP" -Location $location -AllocationMethod Static -Sku Standard
# Create Load Balancer components
$frontendIpConfig = New-AzLoadBalancerFrontendIpConfig -Name "MyFrontEnd" -PublicIpAddress $publicIp
$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "MyBackEndPool"
$probe = New-AzLoadBalancerProbeConfig -Name "MyHealthProbe" -Protocol "Tcp" -Port 80 -IntervalInSeconds 10 -ProbeCount 2

# Create Load Balancer
$loadBalancer = New-AzLoadBalancer `
    -ResourceGroupName $resourceGroupName `
    -Name "MyLoadBalancer" `
    -Location $location `
    -FrontendIpConfiguration $frontendIpConfig `
    -BackendAddressPool $backendPool `
    -Probe $probe

# Create Load Balancer Rule
$lbRule = New-AzLoadBalancerRuleConfig -Name "MyHTTPRule" `
    -FrontendIpConfiguration $frontendIpConfig `
    -BackendAddressPool $backendPool `
    -Probe $probe `
    -Protocol Tcp `
    -FrontendPort 80 `
    -BackendPort 80

# Update Load Balancer with the Rule
$loadBalancer | Add-AzLoadBalancerRuleConfig -Name "MyHTTPRule" -FrontendIpConfiguration $frontendIpConfig -BackendAddressPool $backendPool -Probe $probe -Protocol Tcp -FrontendPort 80 -BackendPort 80
$loadBalancer | Set-AzLoadBalancer

# Create Network Security Group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name "MyNSG"

# Create Virtual Network
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "MyVNet" -AddressPrefix "10.0.0.0/16"
$subnet = Add-AzVirtualNetworkSubnetConfig -Name "MySubnet" -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Create NICs for VMs
#$subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "MyVNet").Subnets[0].Id

# Get Subnet ID
$subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "MyVNet").Subnets[0].Id


$nic1 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic1" -SubnetId $subnetId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPool.Id
$nic2 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic2" -SubnetId $subnetId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPool.Id

# Create Linux VMs with Apache2, PHP, MySQL connector
<# $vmConfig = @{
    ResourceGroupName = $resourceGroupName
    Location = $location
    VirtualNetworkName = $vnet.Name
    SubnetName = $subnet.Name
    SecurityGroupName = $nsg.Name
    PublicIpAddressName = $publicIp.Name
    LoadBalancerName = $loadBalancer.Name
    Credential = $adminCredential
    VmSize = $vmSize
} #>

<# $vm1 = New-AzVM @vmConfig -Name "MyVM1" -NetworkInterfaceId $nic1.Id -Image "Canonical:UbuntuServer:24.04-LTS:latest"
$vm2 = New-AzVM @vmConfig -Name "MyVM2" -NetworkInterfaceId $nic2.Id -Image "Canonical:UbuntuServer:24.04-LTS:latest"
 #>

 # Test: Create storage account to enable boot diagnosis

 #$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name "jvmystorageaccount" -Location $location -SkuName "Standard_LRS" -Kind "StorageV2" -AllowBlobPublicAccess $false
 #$existingStorageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | Where-Object { $_.AllowBlobPublicAccess -eq $false } | Select-Object -First 1

 $vmConfig1 = New-AzVMConfig -VMName "MyVM1" -VMSize $vmSize | `
 Set-AzVMOperatingSystem -Linux -ComputerName "MyVM1" -Credential $adminCredential | `
 Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
 Add-AzVMNetworkInterface -Id $nic1.Id | `
 Set-AzVMBootDiagnostic -Disable

$vmConfig2 = New-AzVMConfig -VMName "MyVM2" -VMSize $vmSize | `
 Set-AzVMOperatingSystem -Linux -ComputerName "MyVM2" -Credential $adminCredential | `
 Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
 Add-AzVMNetworkInterface -Id $nic2.Id | `
 Set-AzVMBootDiagnostic -Disable

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig1
Start-Sleep -Seconds 5 # Wait for the first VM to be created before creating the second one
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig2




# Install Apache2, PHP, MySQL connector on VMs and get index.php from another storage account
$script = @"
sudo apt-get update
sudo apt-get install -y apache2 php libapache2-mod-php php-mysql
sudo wget -O /var/www/html/index.php https://javierstorage33.blob.core.windows.net/phpfile/index.php
sudo rm /var/www/html/index.html
"@

Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MyVM1" -CommandId "RunShellScript" -ScriptString $script
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MyVM2" -CommandId "RunShellScript" -ScriptString $script

# Open port 80
$nsg | Add-AzNetworkSecurityRuleConfig -NetworkSecurityRule $nsgRule | Set-AzNetworkSecurityGroup
# Update the NSG with the new rule
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTP" -Protocol "Tcp" -Direction "Inbound" -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 80 -Access "Allow" | Set-AzNetworkSecurityGroup


##################### OK UNTIL HERE #####################


######## MYSQL Part
# Create Application Load Balancer for MySQL VMs
$appLbFrontendIpConfig = New-AzLoadBalancerFrontendIpConfig -Name "AppFrontEnd" -PublicIpAddress $publicIp
$appLbBackendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "AppBackEndPool"
$appLbProbe = New-AzLoadBalancerProbeConfig -Name "AppHealthProbe" -Protocol Tcp -Port 3306
$appLbRule = New-AzLoadBalancerRuleConfig -Name "AppMySQLRule" -FrontendIpConfiguration $appLbFrontendIpConfig -BackendAddressPool $appLbBackendPool -Probe $appLbProbe -Protocol Tcp -FrontendPort 3306 -BackendPort 3306

$appLoadBalancer = New-AzLoadBalancer -ResourceGroupName $resourceGroupName -Name "AppLoadBalancer" -Location $location -FrontendIpConfiguration $appLbFrontendIpConfig -BackendAddressPool $appLbBackendPool -Probe $appLbProbe -LoadBalancingRule $appLbRule

# Create NICs for MySQL VMs
$nic3 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic3" -SubnetId $subnet.Id -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $appLbBackendPool.Id
$nic4 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic4" -SubnetId $subnet.Id -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $appLbBackendPool.Id

# Create MySQL VMs
$mysqlVm1 = New-AzVM @vmConfig -Name "MySQLVM1" -NetworkInterfaceName $nic3.Name -Image "Canonical:UbuntuServer:24.04-LTS:latest"
$mysqlVm2 = New-AzVM @vmConfig -Name "MySQLVM2" -NetworkInterfaceName $nic4.Name -Image "Canonical:UbuntuServer:24.04-LTS:latest"

# Install MySQL on MySQL VMs
##### TODO: Change MySQL Password > create DB > dummy data
$mysqlScript = @"
sudo apt-get update
sudo apt-get install -y mysql-server
"@
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MySQLVM1" -CommandId "RunShellScript" -ScriptString $mysqlScript
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MySQLVM2" -CommandId "RunShellScript" -ScriptString $mysqlScript

# Create Storage Account for replication >> TODO: use mysql / cosmo?
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name "mystorageaccount" -Location $location -SkuName "Standard_LRS"

# Set up database replication (simplified example)
$replicationScript = @"
#!/bin/bash
# Add replication setup commands here
"@
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MySQLVM1" -CommandId "RunShellScript" -ScriptString $replicationScript
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MySQLVM2" -CommandId "RunShellScript" -ScriptString $replicationScript

# Create Azure Automation Account
$automationAccount = New-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name "MyAutomationAccount" -Location $location

# Create Runbook for VM Shutdown
$runbookContent = @"
workflow VMShutdown {
    param (
        [string] \$ResourceGroupName
    )
    \$vms = Get-AzVM -ResourceGroupName \$ResourceGroupName
    foreach (\$vm in \$vms) {
        Stop-AzVM -ResourceGroupName \$ResourceGroupName -Name \$vm.Name -Force
    }
}
"@
$runbook = New-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccount.Name -Name "VMShutdown" -Type "PowerShellWorkflow" -Description "Shutdown VMs at 6 PM" -Content $runbookContent

# Publish Runbook
Publish-AzAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccount.Name -Name $runbook.Name

# Schedule Runbook
$schedule = New-AzAutomationSchedule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccount.Name -Name "DailyShutdown" -StartTime (Get-Date).Date.AddHours(18) -DayInterval 1
Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccount.Name -RunbookName $runbook.Name -ScheduleName $schedule.Name -Parameters @{ ResourceGroupName = $resourceGroupName }

# Set up Alert
$actionGroup = New-AzActionGroup -ResourceGroupName $resourceGroupName -Name "MyActionGroup" -ShortName "AG" -EmailReceiver "jvolpe@gn.com"
$alertRule = New-AzMetricAlertRuleV2 -ResourceGroupName $resourceGroupName -Name "VMShutdownAlert" -Description "Alert for VM shutdown" -Severity 3 -WindowSize (New-TimeSpan -Minutes 5) -Frequency (New-TimeSpan -Minutes 5) -TargetResourceId $automationAccount.Id -Criteria (New-AzMetricAlertRuleV2Criteria -MetricName "RunbookJobCount" -TimeAggregation "Total" -Operator "GreaterThan" -Threshold 0) -ActionGroupId $actionGroup.Id
