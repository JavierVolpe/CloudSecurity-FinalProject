# TODO: Install / Import all Az Modules

# Connect to Azure
Connect-AzAccount

# Variables
$resourceGroupName = "MyResourceGroup"
$location = "UKSouth"
$vmSize = "Standard_D2s_v3"
$adminUsername = "azureuser"
$adminPassword = ConvertTo-SecureString "A987dministrator." -AsPlainText -Force
$adminCredential = New-Object System.Management.Automation.PSCredential($adminUsername, $adminPassword)

# Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create Public IP for Load Balancer
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "MyPublicIP" -Location $location -AllocationMethod Static -Sku Standard

# Create Load Balancer components
$frontendIpConfig = New-AzLoadBalancerFrontendIpConfig -Name "MyFrontEnd" -PublicIpAddress $publicIp
$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "MyBackEndPool"
$probe = New-AzLoadBalancerProbeConfig -Name "MyHealthProbe" -Protocol "Tcp" -Port 80 -IntervalInSeconds 10 -ProbeCount 1

# Create Load Balancer
$loadBalancer = New-AzLoadBalancer -ResourceGroupName $resourceGroupName -Name "MyLoadBalancer" -Location $location -FrontendIpConfiguration $frontendIpConfig -BackendAddressPool $backendPool -Probe $probe

# Create Load Balancer Rule
New-AzLoadBalancerRuleConfig -Name "MyHTTPRule" -FrontendIpConfiguration $frontendIpConfig -BackendAddressPool $backendPool -Probe $probe -Protocol Tcp -FrontendPort 80 -BackendPort 80

# Update Load Balancer with the Rule
$loadBalancer | Add-AzLoadBalancerRuleConfig -Name "MyHTTPRule" -FrontendIpConfiguration $frontendIpConfig -BackendAddressPool $backendPool -Probe $probe -Protocol Tcp -FrontendPort 80 -BackendPort 80
$loadBalancer | Set-AzLoadBalancer

# Create Network Security Group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name "MyNSG"

# Create Virtual Network
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "MyVNet" -AddressPrefix "10.0.0.0/16"
$subnet = Add-AzVirtualNetworkSubnetConfig -Name "MySubnet" -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Get Subnet ID
$subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "MyVNet").Subnets[0].Id

# Create NICs for VMs
$nic1 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic1" -SubnetId $subnetId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPool.Id
$nic2 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic2" -SubnetId $subnetId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPool.Id

# Create Linux VMs with Apache2, PHP, MySQL connector
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
Start-Sleep -Seconds 5
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
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTP" -Protocol "Tcp" -Direction "Inbound" -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 80 -Access "Allow" | Set-AzNetworkSecurityGroup

## TEST AREA: 
# Create Application Load Balancer for MySQL VMs with Private IP
$appLbFrontendIpConfig = New-AzLoadBalancerFrontendIpConfig -Name "AppFrontEnd" -PrivateIpAddress "10.0.1.10" -SubnetId $subnetId
$appLbBackendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "AppBackEndPool"
$appLbProbe = New-AzLoadBalancerProbeConfig -Name "AppHealthProbe" -Protocol Tcp -Port 3306 -IntervalInSeconds 10 -ProbeCount 1
$appLbRule = New-AzLoadBalancerRuleConfig -Name "AppMySQLRule" -FrontendIpConfiguration $appLbFrontendIpConfig -BackendAddressPool $appLbBackendPool -Probe $appLbProbe -Protocol Tcp -FrontendPort 3306 -BackendPort 3306

$appLoadBalancer = New-AzLoadBalancer -ResourceGroupName $resourceGroupName -Name "AppLoadBalancer" -Location $location -FrontendIpConfiguration $appLbFrontendIpConfig -BackendAddressPool $appLbBackendPool -Probe $appLbProbe -LoadBalancingRule $appLbRule

# Create NICs for MySQL VMs
$subnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "MyVNet").Subnets[0].Id

$nic3 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic3" -SubnetId $subnetId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $appLbBackendPool.Id
$nic4 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "MyNic4" -SubnetId $subnetId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $appLbBackendPool.Id

# Create MySQL VMs
$vmConfig3 = New-AzVMConfig -VMName "MySQLVM1" -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName "MySQLVM1" -Credential $adminCredential | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
    Add-AzVMNetworkInterface -Id $nic3.Id | `
    Set-AzVMBootDiagnostic -Disable

$vmConfig4 = New-AzVMConfig -VMName "MySQLVM2" -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName "MySQLVM2" -Credential $adminCredential | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
    Add-AzVMNetworkInterface -Id $nic4.Id | `
    Set-AzVMBootDiagnostic -Disable

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig3
Start-Sleep -Seconds 5
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig4

# Create Public IPs for MySQL VMs with Standard SKU
$publicIpMySQLVM1 = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "MySQLVM1PublicIP" -Location $location -AllocationMethod Static -Sku Standard
$publicIpMySQLVM2 = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "MySQLVM2PublicIP" -Location $location -AllocationMethod Static -Sku Standard

# Assign Public IPs to NICs
$nic3.IpConfigurations[0].PublicIpAddress = $publicIpMySQLVM1
$nic3 | Set-AzNetworkInterface
$nic4.IpConfigurations[0].PublicIpAddress = $publicIpMySQLVM2
$nic4 | Set-AzNetworkInterface

# Install MySQL on MySQL VMs
$mysqlPassword = 'A987dministrator.'

$mysqlMasterScript = @"
sudo apt-get update
sudo apt-get install -y mysql-server
sudo sed -i '/\[mysqld\]/a server-id=1' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo mysql -u root -p$mysqlPassword <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysqlPassword';
FLUSH PRIVILEGES;
DROP USER IF EXISTS 'newuser'@'%';
CREATE USER 'newuser'@'%' IDENTIFIED BY '$mysqlPassword';
CREATE DATABASE newdatabase;
GRANT ALL PRIVILEGES ON newdatabase.* TO 'newuser'@'%';
FLUSH PRIVILEGES;
USE newdatabase;
CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), lastname VARCHAR(50), email VARCHAR(50));
INSERT INTO users (name, lastname, email) VALUES ('John', 'Doe', 'john.doe@example.com'), ('Jane', 'Doe', 'jane.doe@example.com'), ('Alice', 'Smith', 'alice.smith@example.com'), ('Bob', 'Brown', 'bob.brown@example.com'), ('Charlie', 'Black', 'charlie.black@example.com');
DROP USER IF EXISTS 'replicator'@'%';
CREATE USER 'replicator'@'%' IDENTIFIED WITH mysql_native_password BY 'replica_password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
EOF
sudo systemctl restart mysql
"@

Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MySQLVM1" -CommandId "RunShellScript" -ScriptString $mysqlMasterScript

# Slave configuration

$mysqlVM1PrivateIp = (Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name "MyNic3").IpConfigurations[0].PrivateIpAddress
$mysqlPassword = 'A987dministrator.'

$mysqlSlaveScript = @"
sudo apt-get update
sudo apt-get install -y mysql-server
sudo sed -i '/\[mysqld\]/a server-id=2' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo mysql -u root -p$mysqlPassword <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysqlPassword';
FLUSH PRIVILEGES;
CHANGE MASTER TO MASTER_HOST='$mysqlVM1PrivateIp', MASTER_USER='replicator', MASTER_PASSWORD='replica_password', MASTER_LOG_FILE='binlog.000005', MASTER_LOG_POS= 157;
START SLAVE;
EOF
sudo systemctl restart mysql
"@

Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MySQLVM2" -CommandId "RunShellScript" -ScriptString $mysqlSlaveScript






# Remove Public IPs from NICs
$nic3.IpConfigurations[0].PublicIpAddress = $null
$nic3 | Set-AzNetworkInterface
$nic4.IpConfigurations[0].PublicIpAddress = $null
$nic4 | Set-AzNetworkInterface

# Get the Private IP Address of the MySQL Load Balancer
$mysqlLbPrivateIp = "10.0.1.10"

## END TEST AREA

# Update the PHP File on the Web VMs
$updateScript = @"
sudo sed -i 's/localhost/$mysqlLbPrivateIp/' /var/www/html/index.php
"@

Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MyVM1" -CommandId "RunShellScript" -ScriptString $updateScript
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "MyVM2" -CommandId "RunShellScript" -ScriptString $updateScript

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
