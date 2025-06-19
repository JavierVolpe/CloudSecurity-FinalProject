# Azure Three-Tier Load Balancing Infrastructure

This repository contains a PowerShell script that automates the creation of a **secure three-tier architecture** in Microsoft Azure. It was developed as a final project for the *Cloud Security* course.

---

## 🏗️ Overview

The deployment includes:
- 🕸️ **Web Tier**: 2 Ubuntu VMs behind an **external load balancer**
- 🧠 **App Tier**: 2 Ubuntu VMs with MySQL databases behind an **internal load balancer**
- 🗃️ **Data Tier**: MySQL database service co-hosted on app-tier VMs
- 🔐 **Network Security Groups (NSGs)** for tiered isolation and access control
- ⚙️ **Automation**: Configures Apache2, PHP, and MySQL on respective tiers

---

## 🛡️ Security Features

- NSGs to restrict access:
  - Only port 80 open to the public (Web Tier)
  - Only port 3306 open internally between Web and App tiers
- App and Data tiers are **fully private**
- No public IPs assigned to VMs
- Use of strong admin credentials
- Follows **least privilege** principles

---

## 📦 Prerequisites

- Active Azure subscription
- Azure PowerShell module:
  ```powershell
  Install-Module -Name Az -AllowClobber -Scope CurrentUser
  ```
- Required permissions to deploy Azure resources

---

## 🚀 Deployment Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/JavierVolpe/CloudSecurity-FinalProject
   cd CloudSecurity-FinalProject
   ```

2. Log in to Azure:
   ```powershell
   Connect-AzAccount
   ```

3. Run the script:
   ```powershell
   .\cloud_sikkerhed_project.ps1
   ```

4. If needed, allow scripts to execute:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## 🧹 Cleanup

To delete the entire setup:
```powershell
Remove-AzResourceGroup -Name "MyResourceGroup" -Force
```

---

## 📌 Notes

- The **App VMs initially launch in the Web subnet** to download packages.
- After setup, they're **moved to the private App subnet** with no internet access.
- Consider using:
  - **Azure Bastion** for secure admin access
  - **Azure Key Vault** for storing secrets
  - **Resource Locks** for deletion protection

---

## 👨‍💻 Author

This solution was developed by **Javier Alejandro Volpe** as part of the *Cloud Security* final project (KEA IT Technology, 3rd semester).

