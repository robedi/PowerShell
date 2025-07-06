# Ensure-PowerShellModule.ps1

A lightweight PowerShell utility to ensure that a specific PowerShell module is **installed** and **up-to-date**. Useful in automation, setup scripts, and DevOps pipelines where you want to guarantee module availability without manual intervention.

---

## ✅ Features

- Checks if a module is already installed
- Automatically installs the module if not present
- Detects if an update is available and applies it
- Supports `CurrentUser` scope (no admin rights needed)

---

## 🧪 Usage

```powershell
.\Ensure-PowerShellModule.ps1

# Call the function
Ensure-Module -ModuleName 'Pester'
```