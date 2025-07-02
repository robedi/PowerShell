# Zabbix Agent Unified Installer for Windows

This PowerShell script automates the detection, installation, and configuration of Zabbix Agent (either classic Agent or Agent 2) on Windows systems. It ensures the appropriate version is installed based on system architecture and administrator input, and handles configuration and service state cleanly.

---

## 📦 Features

* Automatic detection of existing Zabbix Agent or Agent 2
* Installation of latest stable version (default: `7.4.0`)
* Architecture-aware (`amd64` or `i386`)
* Secure TLS 1.2 download
* Graceful service stop/start with status check
* Configuration injection (Server IPs, Hostname, Metadata)
* Auto-elevation if not run as Administrator

---

## 🔧 Parameters

| Parameter            | Description                                                      |
| -------------------- | ---------------------------------------------------------------- |
| `ZabbixServer`       | IP address of Zabbix server. Default: `10.30.8.4`                |
| `ZabbixServerActive` | IP for active checks. Default: `10.30.8.4`                       |
| `ListenPort`         | Agent listening port. Default: `10050`                           |
| `EnablePath`         | Enable system.run\[] command. Default: `1`                       |
| `AllowDenyKey`       | Key whitelist. Default: `AllowKey=system.run[*]`                 |
| `HostMetaData`       | Metadata to pass to Zabbix. Default: `Windows clients`           |
| `ForceAgent`         | Force install of `Agent1` or `Agent2`, overrides detection logic |

---

## ▶️ Usage

### Run directly with PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File Install-ZabbixAgent.ps1
```

### From network share:

```powershell
powershell -ExecutionPolicy Bypass -File "\\myserver\scripts\Install-ZabbixAgent.ps1"
```

### With custom parameters:

```powershell
powershell -ExecutionPolicy Bypass -File Install-ZabbixAgent.ps1 -ZabbixServer "192.168.1.10" -ForceAgent "Agent2"
```

---

## ⚙️ Behavior

1. **Admin Check**: Relaunches itself elevated if not run as Administrator.
2. **Service Stop**: Calls `Stop-ZabbixAgentService` to stop any existing agent service.
3. **Download**: Chooses correct MSI package based on architecture and version.
4. **Install**: Silently installs the MSI using `/qn` mode.
5. **Configure**: Applies server IP, hostname, interface, and metadata to the config file.
6. **Service Start**: Starts the service and waits for it to be fully running.

---

## 🗂 Directory Structure

* Installs to:

  * `C:\Program Files\Zabbix Agent\` *(Agent1)*
  * `C:\Program Files\Zabbix Agent 2\` *(Agent2)*
* Temporary config: `$env:TEMP\template_zabbix_agent[d|2].conf`
* Local cache: `C:\Tools\`

---

## 🔐 Security

* Uses TLS 1.2 for secure downloads
* Script enforces elevation check
* Cleanly handles overwriting config files (with `Remove-Item` before `Copy-Item`)

---

## 🧪 Compatibility

* Windows 10, 11, Server 2016/2019/2022
* Requires PowerShell 5.1+

---

## 📎 References

* [Zabbix Downloads](https://www.zabbix.com/download_agents)
* [PowerShell Docs](https://docs.microsoft.com/en-us/powershell/)
* GitHub Repo: [github.com/RoBeDi/PowerShell](https://github.com/RoBeDi/PowerShell)

---

## 👤 Author

**RoBeDi**
📅 Created: July 2, 2025
🔗 [GitHub Profile](https://github.com/RoBeDi)
