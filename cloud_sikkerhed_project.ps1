# Connect to Azure
Connect-AzAccount

# Variables
$resourceGroupName = "MyResourceGroup"
$location = "UKSouth"
$vmSize = "Standard_D2s_v3"
$adminUsername = "azureuser"
$adminPassword = "<password>"

# Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Public IPs
$publicIpWeb = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "WebPublicIP" -Location $location -AllocationMethod Static -Sku Standard

# Credentials
$adminPassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$adminCredential = New-Object System.Management.Automation.PSCredential($adminUsername, $adminPassword)

# Virtual Network and Subnets
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "MyVNet" -AddressPrefix "10.0.0.0/16"
$subnetWeb = Add-AzVirtualNetworkSubnetConfig -Name "WebSubnet" -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
$subnetApp = Add-AzVirtualNetworkSubnetConfig -Name "AppSubnet" -AddressPrefix "10.0.2.0/24" -VirtualNetwork $vnet
$subnetData = Add-AzVirtualNetworkSubnetConfig -Name "DataSubnet" -AddressPrefix "10.0.3.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Create Load Balancers
$frontendIpConfigWeb = New-AzLoadBalancerFrontendIpConfig -Name "WebFrontEnd" -PublicIpAddress $publicIpWeb
$backendPoolWeb = New-AzLoadBalancerBackendAddressPoolConfig -Name "WebBackEndPool"
$probeWeb = New-AzLoadBalancerProbeConfig -Name "WebHealthProbe" -Protocol "Tcp" -Port 80 -IntervalInSeconds 10 -ProbeCount 1
$ruleConfigWeb = New-AzLoadBalancerRuleConfig -Name "WebHTTPRule" -FrontendIpConfiguration $frontendIpConfigWeb -BackendAddressPool $backendPoolWeb -Probe $probeWeb -Protocol Tcp -FrontendPort 80 -BackendPort 80
$loadBalancerWeb = New-AzLoadBalancer -ResourceGroupName $resourceGroupName -Name "WebLoadBalancer" -Location $location -FrontendIpConfiguration $frontendIpConfigWeb -BackendAddressPool $backendPoolWeb -Probe $probeWeb -LoadBalancingRule $ruleConfigWeb

# Create Network Security Group and Rules
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name "MyNSG"
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTP" -Protocol "Tcp" -Direction "Inbound" -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 80 -Access "Allow" | Set-AzNetworkSecurityGroup
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-MySQL" -Protocol "Tcp" -Direction "Inbound" -Priority 110 -SourceAddressPrefix "10.0.1.0/24" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 3306 -Access "Allow" | Set-AzNetworkSecurityGroup

# Get Subnet IDs
$subnetWebId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "MyVNet").Subnets | Where-Object { $_.Name -eq "WebSubnet" } | Select-Object -ExpandProperty Id
$subnetAppId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "MyVNet").Subnets | Where-Object { $_.Name -eq "AppSubnet" } | Select-Object -ExpandProperty Id

# Create NICs for VMs in Web Subnet
$nicWeb1 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "WebNic1" -SubnetId $subnetWebId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPoolWeb.Id
$nicWeb2 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "WebNic2" -SubnetId $subnetWebId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPoolWeb.Id
$nicApp1 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "AppNic1" -SubnetId $subnetWebId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPoolWeb.Id
$nicApp2 = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "AppNic2" -SubnetId $subnetWebId -NetworkSecurityGroupId $nsg.Id -LoadBalancerBackendAddressPoolId $backendPoolWeb.Id

# Create VMs
$vmConfigWeb1 = New-AzVMConfig -VMName "WebVM1" -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName "WebVM1" -Credential $adminCredential | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
    Add-AzVMNetworkInterface -Id $nicWeb1.Id | `
    Set-AzVMBootDiagnostic -Disable

$vmConfigWeb2 = New-AzVMConfig -VMName "WebVM2" -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName "WebVM2" -Credential $adminCredential | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
    Add-AzVMNetworkInterface -Id $nicWeb2.Id | `
    Set-AzVMBootDiagnostic -Disable

$vmConfigApp1 = New-AzVMConfig -VMName "AppVM1" -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName "AppVM1" -Credential $adminCredential | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
    Add-AzVMNetworkInterface -Id $nicApp1.Id | `
    Set-AzVMBootDiagnostic -Disable

$vmConfigApp2 = New-AzVMConfig -VMName "AppVM2" -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName "AppVM2" -Credential $adminCredential | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
    Add-AzVMNetworkInterface -Id $nicApp2.Id | `
    Set-AzVMBootDiagnostic -Disable

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfigWeb1
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfigWeb2
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfigApp1
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfigApp2

# Install Apache2 and retrieve index.php in WebVMs
$script = @"
sudo apt-get update
sudo apt-get install -y apache2 php libapache2-mod-php php-mysql
sudo wget -O /var/www/html/index.php https://javierstorage33.blob.core.windows.net/phpfile/index.php
sudo rm /var/www/html/index.html
sudo chmod 777 /var/www/html
"@

Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "WebVM1" -CommandId "RunShellScript" -ScriptString $script
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "WebVM2" -CommandId "RunShellScript" -ScriptString $script

# Script to install MySQL and configure database on AppVMs
$mysqlScript = @"
sudo apt-get update
echo 'mysql-server mysql-server/root_password password A987dministrator.' | sudo debconf-set-selections
echo 'mysql-server mysql-server/root_password_again password A987dministrator.' | sudo debconf-set-selections
sudo apt-get install -y mysql-server
sudo mysql -u root -p'A987dministrator.' -e "CREATE DATABASE cloudsikkerhed;"
sudo mysql -u root -p'A987dministrator.' -e "USE cloudsikkerhed; CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), lastname VARCHAR(50), email VARCHAR(50));"
sudo mysql -u root -p'A987dministrator.' -e "USE cloudsikkerhed; INSERT INTO users (name, lastname, email) VALUES ('Tahseen', 'Uddin', 'taud@kea.dk'), ('Charlie', 'Demasi', 'chad@kea.dk'), ('Malene', 'Hasse', 'malh@kea.dk'), ('Per', 'Fogt', 'pefo@kea.dk'), ('Javier', 'Volpe', 'javo0001@stud.kea.dk');"
sudo sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql
sudo mysql -u root -p'A987dministrator.' -e "CREATE USER 'javier'@'%' IDENTIFIED BY 'A987dministrator.';"
sudo mysql -u root -p'A987dministrator.' -e "GRANT ALL PRIVILEGES ON *.* TO 'javier'@'%' WITH GRANT OPTION;"
sudo mysql -u root -p'A987dministrator.' -e "FLUSH PRIVILEGES;"
"@

Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "AppVM1" -CommandId "RunShellScript" -ScriptString $mysqlScript
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName "AppVM2" -CommandId "RunShellScript" -ScriptString $mysqlScript

# Create Load Balancer for App
$frontendIpConfigApp = New-AzLoadBalancerFrontendIpConfig -Name "AppFrontEnd" -PrivateIpAddress "10.0.2.10" -SubnetId $subnetAppId
$backendPoolApp = New-AzLoadBalancerBackendAddressPoolConfig -Name "AppBackEndPool"
$probeApp = New-AzLoadBalancerProbeConfig -Name "AppHealthProbe" -Protocol Tcp -Port 3306 -IntervalInSeconds 10 -ProbeCount 1
$ruleConfigApp = New-AzLoadBalancerRuleConfig -Name "AppMySQLRule" -FrontendIpConfiguration $frontendIpConfigApp -BackendAddressPool $backendPoolApp -Probe $probeApp -Protocol Tcp -FrontendPort 3306 -BackendPort 3306
$loadBalancerApp = New-AzLoadBalancer -ResourceGroupName $resourceGroupName -Name "AppLoadBalancer" -Location $location -FrontendIpConfiguration $frontendIpConfigApp -BackendAddressPool $backendPoolApp -Probe $probeApp -LoadBalancingRule $ruleConfigApp

# Move App VMs to App Subnet: They needed to be in the Web subnet to have access to the Internet, to download required software. 
# They will NOT have internet access in this subnet.

# Get the NICs
$nicApp1 = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name "AppNic1"
$nicApp2 = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name "AppNic2"

# Update the IP configuration to use the App Subnet and Load Balancer
$nicApp1.IpConfigurations[0].Subnet.Id = $subnetAppId
$nicApp1.IpConfigurations[0].LoadBalancerBackendAddressPools = @($backendPoolApp)

$nicApp2.IpConfigurations[0].Subnet.Id = $subnetAppId
$nicApp2.IpConfigurations[0].LoadBalancerBackendAddressPools = @($backendPoolApp)

# Apply the changes
$nicApp1 | Set-AzNetworkInterface
$nicApp2 | Set-AzNetworkInterface
