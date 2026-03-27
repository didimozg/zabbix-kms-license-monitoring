# Zabbix KMS License Monitoring

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-red)
![PowerShell](https://img.shields.io/badge/PowerShell-5%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)
![Maintenance](https://img.shields.io/badge/Maintained-yes-brightgreen)

Russian documentation: [README_RU.md](./README_RU.md).

Monitoring **Windows / Office / Visio / Project** licenses via **Zabbix Agent 2** with automatic product discovery using **LLD (Low-Level Discovery)**.

This project allows centralized monitoring of **KMS / Volume activation expiration** on Windows hosts.

Designed for infrastructures with **hundreds or thousands of servers**.

---

# Features

- automatic license discovery via **Zabbix LLD**
- monitoring of:
  - Windows
  - Microsoft Office
  - Microsoft Visio
  - Microsoft Project
- monitoring of:
  - days until activation expiration
  - license state
  - licensing status codes
- automatic creation of:
  - items
  - triggers
  - graphs
- local data collection using **PowerShell**
- caching to reduce system load
- scalable for large infrastructures

---

# Architecture

```
PowerShell Script
        ↓
Zabbix Agent 2 (UserParameter)
        ↓
LLD Discovery
        ↓
Item Prototypes
        ↓
Trigger Prototypes
```

All data collection is performed **locally on the host**, while Zabbix retrieves processed metrics through the agent.

This significantly reduces load on the Zabbix server compared to remote WMI queries.

---

# Supported Products

The template automatically discovers:

- Windows
- Microsoft Office
- Microsoft Visio
- Microsoft Project

License data is retrieved using the Windows licensing class:

```
SoftwareLicensingProduct
```

---

# Repository Structure

```
.
├─ template_kms_volume_licenses_agent2.yaml
├─ kms_license_monitor.ps1
└─ kms_licenses.conf
```

---

# Components

## Zabbix Template

`template_kms_volume_licenses_agent2.yaml`

Contains:

- discovery rule
- item prototypes
- trigger prototypes

The template automatically creates items for each discovered licensed product.

---

## PowerShell Script

`kms_license_monitor.ps1`

The script performs:

- local CIM query to the Windows licensing system
- filtering of relevant products
- generation of JSON output for Zabbix LLD
- returning metrics for a specific product
- caching of results to reduce system load

---

## Zabbix Agent Configuration

`kms_licenses.conf`

`UserParameter` configuration exposing keys to Zabbix Agent 2:

```
kms.licenses.discovery
kms.license.days[*]
kms.license.minutes[*]
kms.license.state[*]
kms.license.status_code[*]
kms.license.name[*]
kms.license.type[*]
```

---

# Installation

## 1. Copy the PowerShell script

```
C:\Program Files\Zabbix Agent 2\scripts\kms_license_monitor.ps1
```

Create the `scripts` directory if it does not exist.

---

## 2. Copy the agent configuration

```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\kms_licenses.conf
```

---

## 3. Restart the Zabbix Agent

```powershell
Restart-Service "Zabbix Agent 2"
```

---

## 4. Test the discovery key

```powershell
zabbix_agent2.exe -t kms.licenses.discovery
```

Example output:

```json
{
  "data": [
    {
      "{#PRODUCTID}": "edcd20018b614ef546e9cef50a8a58280e642308",
      "{#PRODUCTNAME}": "Windows(R), Professional edition",
      "{#PRODUCTTYPE}": "Windows"
    }
  ]
}
```

---

## 5. Import the template

Import:

```
template_kms_volume_licenses_agent2.yaml
```

via:

```
Data collection → Templates → Import
```

---

## 6. Link the template to hosts

After linking the template, the discovery rule will automatically detect licensed products on the host.

---

# Example Items

After discovery, Zabbix automatically creates items like:

```
Windows(R), Professional edition: Days until activation expiry
Windows(R), Professional edition: License state
Office 16 ProPlus: Days until activation expiry
Office 16 ProPlus: License state
```

---

# Example Triggers

The template automatically creates triggers such as:

```
activation expires in <30 days
activation expires in <7 days
license is not activated
```

# Requirements

- **Zabbix 7.4**
- **Zabbix Agent 2**
- Windows Server / Windows Client
- PowerShell
- access to the CIM class `SoftwareLicensingProduct`

---

# Limitations

- works only on Windows hosts
- requires access to the Windows licensing subsystem
- not supported on Linux hosts

<img width="1489" height="686" alt="image" src="https://github.com/user-attachments/assets/403aeee3-a1fc-42f3-873b-2aefb601cddd" />


---

# Author

This project was created for centralized monitoring of Windows and Office license activation status using Zabbix.
