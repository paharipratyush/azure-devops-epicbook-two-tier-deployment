# 🚀 Two-Tier Azure DevOps Architecture (Decoupled Infra & App CI/CD)

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Azure](https://img.shields.io/badge/Microsoft_Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)

Welcome to the EpicBook Automated Deployment project! This repository provides a foolproof, step-by-step guide to deploying a production-style, two-tier architecture (Node.js/React frontend, MySQL backend) on Microsoft Azure. 

This project intentionally decouples the **Infrastructure as Code (Terraform)** from the **Configuration Management (Ansible)** into two distinct CI/CD pipelines, mimicking real-world enterprise team boundaries.

---
## 🏗️ Architecture Overview

**The Workflow:**
1. **Developer Commits:** Code is pushed to this unified GitHub repository.
2. **Azure DevOps Pipelines:**
   * **Pipeline 1 (Infra):** Uses Terraform to provision an Azure Virtual Network, Subnet, Network Security Group (NSG), an Ubuntu 22.04 Virtual Machine (App Server), and an Azure Database for MySQL Flexible Server.
   * **Pipeline 2 (App):** Uses Ansible to configure the Ubuntu VM, install Nginx & PM2, inject secure database credentials, seed the MySQL database, and serve the Node.js React application.
3. **Security:** Azure Workload Identity Federation authenticates the pipelines to Azure without passwords. Secure Files vault injects SSH keys at runtime.

---

## ⚠️ Real-World Edge Cases Solved Here
If you are running this in your own Azure environment, this repository already includes fixes for common enterprise cloud challenges:
1. **Azure RBAC Restrictions:** Details how to configure Workload Identity Federation (OIDC) when you only have Contributor access.
2. **Regional Capacity Limits:** Uses the `B_Standard_B1ms` MySQL SKU to bypass frequent capacity errors in regions like South Africa North.
3. **Strict SSL/TLS Enforcement:** Azure enforces `require_secure_transport=ON`. The Ansible Sequelize templates here are pre-configured to inject SSL dialect options, preventing connection crashes.
4. **The Ansible Handler Trap:** Includes idempotent Nginx restart configurations to ensure the proxy properly routes traffic even if a previous pipeline run was interrupted.

---

## 🛑 Phase 0: Getting Started from Zero (Workstation Setup)
Before touching cloud configurations, your local computer must be ready. 

**For Mac & Linux Users:**
You have a native terminal. You are ready to go.

**For Windows Users:**
Cloud engineering requires Linux tools. You must enable **Windows Subsystem for Linux (WSL)**:
1. Open PowerShell as Administrator.
2. Type `wsl --install` and press Enter. 
3. Restart your computer. You now have an "Ubuntu" app on your computer. Open it and use it as your primary terminal for this project.

**Account Setup:**
1. **Azure Cloud:** Create a free account at [portal.azure.com](https://portal.azure.com).
2. **Azure DevOps:** Create a free organization at [dev.azure.com](https://dev.azure.com). 

---

## 📥 Phase 1: Bringing the Code into Azure DevOps
You cannot run pipelines directly from someone else's GitHub. You need to copy (import) this code into your own Azure DevOps workspace.

1. Go to your Azure DevOps Organization and create a **New Project** (e.g., "EpicBook-Deployment").
2. Go to **Repos** in the left menu.
3. Because your repo is empty, you will see an option to **Import a repository**. Click it.
4. Set the Source type to **Git**.
5. Paste the URL of this GitHub repository and click **Import**. 

*You now have a perfect copy of this code inside your own Azure DevOps environment!*

---
## ⚙️ Phase 2: Create a Self-Hosted Agent (Crucial for Free Accounts)
Microsoft restricts free hosted agents. To run these pipelines, you need to turn your own laptop (via WSL or Linux) into a pipeline runner.

**1. Create a Personal Access Token (PAT):**
* In Azure DevOps, click the **User Settings icon** (top right, next to your profile picture) -> **Personal access tokens**.
* Click **+ New Token**. Name it `AgentToken`. 
* Under Scopes, select **Show all scopes**, find **Agent Pools**, and check **Read & manage**.
* Click Create and **copy the token**.

**2. Create the Agent Pool:**
* Go to **Project Settings** (bottom left) -> **Agent pools**.
* Click **Add pool**. Select **Self-hosted**, name it `SelfHostedPool`, and click Create.
* Click into `SelfHostedPool` -> click **New agent** -> select **Linux**.

**3. Install the Agent on your PC (in WSL/Linux):**
* Open your terminal and follow the exact commands listed on the screen Azure DevOps provides. It will look like this:
  ```bash
  mkdir myagent && cd myagent
  wget <download_link_provided_by_azure>
  tar zxvf <downloaded_file.tar.gz>
  ./config.sh
  ```
* When prompted by `./config.sh`:

  - Enter your Azure DevOps Server URL (https://dev.azure.com/YOUR_ORG).
  - Authentication type: Press Enter for PAT.
  - Enter the PAT token you copied earlier.
  - Enter agent pool name: `SelfHostedPool`.
  - Press Enter for the rest of the defaults.

* Finally, run ./run.sh. Leave this terminal window open! Your computer is now waiting for pipeline jobs.

## 🔐 Phase 3: The Azure Foundation & Authentication

**Why are we doing this?** Azure DevOps is a separate system from Azure Cloud. To allow Azure DevOps to build servers for us, we must create a "robot user" (called a Service Principal or SPN) and give it permissions to access our cloud account.

**1. Create the Container (Azure Portal):**
* Go to [portal.azure.com](https://portal.azure.com).
* Search for **Resource groups** and click **Create**.
* Name it `rg-epicbook` and choose a region (e.g., South Africa North).
* *Why?* We are creating an empty folder first. This allows us to securely restrict our "robot user" so it can only build things inside this specific folder, rather than having free reign over our entire account.

**2. Configure the Service Connection (Azure DevOps):**
*(Note: You must have 'Owner' access on the Azure subscription or the Resource Group to do this).*
* Go back to Azure DevOps -> **Project Settings** (bottom left corner) -> **Service connections**.
* Click **New service connection** -> **Azure Resource Manager** -> **Next**.
* Select **Workload Identity federation (automatic)** -> **Next**.
* Under Scope Level, select **Subscription**.
* **CRITICAL:** Under the Resource Group dropdown, select `rg-epicbook`.
* Name the connection `azure-spn-connection`.
* Check the box for **Grant access permission to all pipelines** and hit Save.

---

## 🗝️ Phase 4: The Security Vault (SSH Keys)

**Why are we doing this?** Terraform needs a *Public* key to securely lock the new Azure VM. Later, Ansible needs the matching *Private* key to unlock it and install the application. 

**1. Generate the Key:**
* Open your terminal (Ubuntu/WSL for Windows).
* Run `ssh-keygen -t ed25519`. Press Enter through all prompts to accept the defaults.

**2. Provide Terraform the Public Key:**
* Run `cat ~/.ssh/id_ed25519.pub` and copy the entire output string (it will look like ssh-ed25519 AAAA...).
* In Azure DevOps, go to **Repos** -> **Files** -> open `infra/variables.tf` folder.
* Click **Edit**. Find the variable `ssh_public_key` (or similar).
* Paste your copied key string directly into the default value so it looks exactly like this:
  ```
  variable "ssh_public_key" {
  description = "Your raw SSH public key string"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...<YOUR_KEY_HERE>"
  }
  ```
* Click **Commit**. 

**3. Extract the Private Key from your laptop:**
* Run `cd ~/.ssh` to move into the hidden SSH folder.
* **Windows WSL Trick:** Run `explorer.exe .` (do not forget the space and dot). A Windows folder will pop open showing the inside of your Linux folder!
* Copy the file named exactly `id_ed25519` (NOT the `.pub` file) and paste it on your Windows Desktop for easy access.

**4. Upload Private Key to the Vault:**
* Go to Azure DevOps -> **Pipelines** -> **Library**.
* Click the **Secure files** tab -> **+ Secure file**.
* Upload the `id_ed25519` file from your Desktop.
* Once uploaded, click the file name. Under **Pipeline permissions**, click the three dots (`⋮`), select **Open access**, and hit Save.
* *(Security Best Practice: Now delete the private key from your Windows Desktop. The original remains safe in your WSL folder).*

---

## 🏗️ Phase 5: The Infrastructure Pipeline (Terraform)
This pipeline reads our Terraform code and talks to Azure to build the Network, the Ubuntu VM, and the MySQL Database.

**Important Setup Check:** Open `infra/azure-pipelines.yml`. Make sure the `pool: name:` is set to `SelfHostedPool` so it correctly uses the agent you set up in Phase 2.

1. Go to Azure DevOps -> **Pipelines** -> **Create Pipeline**.
2. Select **Azure Repos Git** -> select your imported repo.
3. Select **Existing Azure Pipelines YAML file**. Point it to the `infra/azure-pipelines.yml` file.
4. Before running, click **Variables** (top right corner).
5. Click **+ New variable**. Name it `DB_PASSWORD`, give it a strong password (e.g., `EpicBook!2026`), and **check the box to keep it secret**.
6. Click **Save and run**. 
7. Once finished, click into the pipeline logs and copy the `app_public_ip` and `mysql_fqdn`.

---

## 🤝 Phase 6: The Manual Handoff
In a decoupled enterprise architecture, infrastructure outputs must be passed to the application configuration.
1. In Azure DevOps, go to **Repos** -> **Files**.
2. Navigate to `app/inventory.ini`. Click **Edit**, replace the IP address with your new `app_public_ip`, and click **Commit**.
3. Navigate to `app/group_vars/web.yml`. Click **Edit**, replace the `db_host` with your new `mysql_fqdn`, and click **Commit**.

---

## ⚙️ Phase 7: The Application Pipeline (Ansible)
This pipeline securely downloads the SSH key from the vault, logs into the new VM, installs Node.js and Nginx, injects the database password, and starts the application.

**Important Setup Check:** Open `app/azure-pipelines.yml`. Make sure the `pool: name:` is set to `SelfHostedPool`.

1. Go to **Pipelines** -> **New Pipeline**.
2. Select your repo, choose **Existing Azure Pipelines YAML file**, and point it to `app/azure-pipelines.yml`.
3. Click **Variables**. Create another `DB_PASSWORD` variable. You **must** use the exact same password from Phase 5. **Check the box to keep it secret**.
4. Click **Save and run**. 
5. When the pipeline turns green, type your `app_public_ip` into your web browser. Welcome to the EpicBook!

---

## 🧹 Safe Teardown (Zero-Cost State)
If you are using a free tier, you can destroy the resources without breaking your Service Connection setup.
1. Go to the Azure Portal -> open `rg-epicbook`.
2. Delete the **Virtual Machine** and the **MySQL Flexible Server** manually first.
3. Wait for them to disappear, then select all remaining resources and delete them.
4. Keep the empty `rg-epicbook` container. It costs $0.00 and preserves your permissions for your next pipeline run!

---

## 📌 Author

Built with 💻 by [Pratyush Pahari](https://github.com/paharipratyush)

Developed as part of the DevOps Micro Internship (DMI) Cohort 2.

Feel free to ⭐ the repo if you found it useful!
