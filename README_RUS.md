# Zabbix KMS License Monitoring

![Zabbix](https://img.shields.io/badge/Zabbix-7.4-red)
![PowerShell](https://img.shields.io/badge/PowerShell-5%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)
![Maintenance](https://img.shields.io/badge/Maintained-yes-brightgreen)

Мониторинг лицензий **Windows / Office / Visio / Project** через **Zabbix Agent 2** с автоматическим обнаружением продуктов через **LLD (Low-Level Discovery)**.

Проект позволяет централизованно контролировать срок действия **KMS / Volume активации** на Windows-хостах.

Подходит для инфраструктур с **сотнями и тысячами серверов**.

---

# Возможности

- автоматическое обнаружение лицензий через **Zabbix LLD**
- мониторинг:
  - Windows
  - Microsoft Office
  - Microsoft Visio
  - Microsoft Project
- контроль:
  - количества дней до истечения активации
  - состояния лицензии
  - кодов состояния лицензирования
- автоматическое создание:
  - items
  - triggers
  - графиков
- локальный сбор данных через **PowerShell**
- кэширование результатов
- масштабируемость для крупных инфраструктур

---

# Архитектура решения

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

Все данные собираются **локально на хосте**, а Zabbix получает уже готовые значения через агент.

Это значительно снижает нагрузку на Zabbix server и улучшает масштабируемость.

---

# Поддерживаемые продукты

Шаблон автоматически обнаруживает:

- Windows
- Microsoft Office
- Microsoft Visio
- Microsoft Project

Данные получаются из системного класса Windows лицензирования:

```
SoftwareLicensingProduct
```

---

# Структура репозитория

```
.
├─ template_kms_volume_licenses_agent2.yaml
├─ kms_license_monitor.ps1
└─ kms_licenses.conf
```

---

# Компоненты

## Zabbix Template

`template_kms_volume_licenses_agent2.yaml`

Содержит:

- discovery rule
- item prototypes
- trigger prototypes

Шаблон автоматически создаёт items для каждого обнаруженного продукта.

---

## PowerShell Script

`kms_license_monitor.ps1`

Скрипт выполняет:

- локальный CIM-запрос к лицензированию Windows
- фильтрацию нужных продуктов
- генерацию JSON для LLD
- возврат метрик по конкретному продукту
- кэширование результатов

---

## Zabbix Agent Configuration

`kms_licenses.conf`

Файл `UserParameter`, публикующий ключи для Zabbix Agent 2:

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

# Установка

## 1. Скопировать PowerShell-скрипт

```
C:\Program Files\Zabbix Agent 2\scripts\kms_license_monitor.ps1
```

Создать каталог `scripts`, если он отсутствует.

---

## 2. Скопировать конфигурацию агента

```
C:\Program Files\Zabbix Agent 2\zabbix_agent2.d\kms_licenses.conf
```

---

## 3. Перезапустить агент

```powershell
Restart-Service "Zabbix Agent 2"
```

---

## 4. Проверить discovery ключ

```powershell
zabbix_agent2.exe -t kms.licenses.discovery
```

Пример ответа:

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

## 5. Импортировать шаблон

Импортировать:

```
template_kms_volume_licenses_agent2.yaml
```

через:

```
Data collection → Templates → Import
```

---

## 6. Привязать шаблон к хостам

После привязки шаблона discovery автоматически обнаружит лицензии.

---

# Пример создаваемых items

После обнаружения лицензий Zabbix автоматически создаёт элементы:

```
Windows(R), Professional edition: Days until activation expiry
Windows(R), Professional edition: License state
Office 16 ProPlus: Days until activation expiry
Office 16 ProPlus: License state
```

---

# Пример триггеров

Шаблон автоматически создаёт триггеры:

```
activation expires in <30 days
activation expires in <7 days
license is not activated
```

---

# Требования

- **Zabbix 7.4**
- **Zabbix Agent 2**
- Windows Server / Windows Client
- PowerShell
- доступ к CIM классу `SoftwareLicensingProduct`

---

# Ограничения

- работает только на Windows-хостах
- требует доступа к локальной системе лицензирования Windows
- не поддерживает Linux

<img width="914" height="676" alt="image" src="https://github.com/user-attachments/assets/97b29bf3-46d7-435b-a46f-9ab141bf4041" />

---

# Лицензия

MIT License

```
MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files to deal in the Software
without restriction.

# Автор

Проект предназначен для централизованного мониторинга лицензий Windows и Office через Zabbix.
