Azure Three-Tier Load Balancing Infrastructure Deployment Script
================================================================
*This script was developed as part of the "Cloud Security" course final project.*

This repository contains a PowerShell script that automates the deployment of a secure, three-tier infrastructure on Microsoft Azure. The infrastructure includes:

-   **Three Subnets**: Web, App, and Data tiers.
-   **External Load Balancer**: Distributes incoming web traffic to two web servers.
-   **Internal Load Balancer**: Distributes traffic to two application servers.
-   **Virtual Machines**: Four Linux VMs (2 for Web tier, 2 for App tier).
-   **Network Security Groups (NSGs)**: Controls inbound and outbound traffic.
-   **Automated Configuration**: Installs and configures Apache2, PHP, and MySQL on the respective VMs.

Table of Contents
-----------------

-   [Architecture Overview](#architecture-overview)
-   [Prerequisites](#prerequisites)
-   [Deployment Instructions](#deployment-instructions)
-   [Security Features](#security-features)
-   [Cleanup](#cleanup)
-   [Notes](#notes)
-   [License](#license)

Architecture Overview
---------------------

The script sets up the following components:

-   **Web Tier**: Two Ubuntu VMs (`WebVM1`, `WebVM2`) behind an **External Load Balancer**.
-   **App Tier**: Two Ubuntu VMs (`AppVM1`, `AppVM2`) behind an **Internal Load Balancer**.
-   **Data Tier**: MySQL databases running on the App VMs.
-   **Network Security Groups**: Applied to control traffic between subnets and to the internet.

Prerequisites
-------------

-   **Azure Subscription**: Active subscription to deploy resources.

-   **Azure PowerShell Module**: Installed and configured. You can install it using:

    powershell

    Copy code

    `Install-Module -Name Az -AllowClobber -Scope CurrentUser`

-   **Permissions**: Ensure you have the necessary permissions to create resources in the Azure subscription.

Deployment Instructions
-----------------------

1.  **Clone the Repository**:

    bash

    Copy code

    `git clone https://github.com/JavierVolpe/CloudSecurity-FinalProject/blob/main/.git
    cd azure-three-tier-infrastructure`

2.  **Login to Azure**:

    Open PowerShell and run:

    powershell

    Copy code

    `Connect-AzAccount`

3.  **Run the Deployment Script**:

    Execute the script to deploy the infrastructure:

    powershell

    Copy code

    `.\cloud_sikkerhed_project.ps1`

    > **Note**: You may need to adjust execution policies to run the script:

    powershell

    Copy code

    `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

4.  **Monitor the Deployment**:

    The script will output the progress. Deployment may take several minutes.

Security Features
-----------------

-   **Network Security Groups (NSGs)**: Configured to allow only necessary traffic.
    -   Allows HTTP traffic on port 80 to the Web tier.
    -   Allows MySQL traffic on port 3306 between Web and App tiers.
-   **Least Privilege Principle**: Access controls are set to minimize exposure.
-   **Private Subnets**: App and Data tiers are isolated in private subnets.
-   **No Public IPs on VMs**: VMs do not have public IP addresses to reduce attack surface.
-   **Strong Passwords**: Uses complex passwords for administrative accounts.

Cleanup
-------

To avoid incurring charges, remove the resource group and all associated resources:


`Remove-AzResourceGroup -Name "MyResourceGroup" -Force`

Notes
-----

-   **Data Tier**: In this script, the data tier is implemented using MySQL on the App VMs. For production scenarios, consider using Azure SQL Database with failover groups for high availability.
-   **Additional Security Services**: While this script includes NSGs, you can enhance security by adding:
    -   **Azure Key Vault**: For managing secrets and keys.
    -   **Azure Bastion**: For secure remote management.
    -   **Resource Locks**: To prevent accidental deletion of critical resources.
