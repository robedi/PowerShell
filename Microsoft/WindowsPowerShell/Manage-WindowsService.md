# Manage-WindowsService.ps1

PowerShell script to manage Windows services: start, stop, and optionally reinstall them if start-up fails. This script is reusable, modular, and customizable for any Windows service—not just Zabbix.

---

## 🔧 Features

- Start any Windows service with timeout handling
- Stop a running service with confirmation loop
- Optional service reinstall fallback using a custom script block
- Handles service-not-found and timeout scenarios gracefully
- Lightweight and dependency-free

---

## 💡 Usage

### Start a service

```powershell
.\Manage-WindowsService.ps1
Start-WindowsService -ServiceName "Spooler"
````

### Stop a service

```powershell
Stop-WindowsService -ServiceName "Spooler"
```

### Start with reinstall logic (if startup fails)

```powershell
Start-WindowsService -ServiceName "MyCustomService" -ReinstallAction {
    # Custom reinstall logic here
    & "C:\Installers\Install-MyCustomService.ps1"
}
```

---

## 📁 Functions

| Function Name          | Description                                                |
| ---------------------- | ---------------------------------------------------------- |
| `Start-WindowsService` | Starts a service with timeout logic and optional reinstall |
| `Stop-WindowsService`  | Stops a service and waits until it's fully stopped         |

---

## ⚠️ Requirements

* Windows PowerShell 5.1+ or PowerShell Core 7+
* Administrator privileges (for starting/stopping/deleting services)

---

## 📌 Suggested Tags for GitHub

* `PowerShell`
* `WindowsService`
* `DevOps`
* `ITAdmin`
* `Scripting`
* `Automation`
* `ServiceManagement`
* `Infrastructure`

---

## 📄 License

MIT License. Feel free to modify and use in commercial or personal projects. Just give credit where appropriate.

---

## 🙌 Contributions

Pull requests are welcome! If you find a bug or want to suggest a feature, feel free to open an issue.

```
