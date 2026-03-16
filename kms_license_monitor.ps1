<#
RU:
  Скрипт для Zabbix Agent 2.
  Выполняет локальный CIM-запрос к SoftwareLicensingProduct,
  кэширует результат на диске и отдает:
    - discovery JSON для LLD
    - отдельные метрики по идентификатору продукта

EN:
  Script for Zabbix Agent 2.
  Executes a local CIM query against SoftwareLicensingProduct,
  caches the result on disk and returns:
    - discovery JSON for LLD
    - per-product metrics by product identifier
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('discover','metric')]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$ProductId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('days','minutes','state','status_code','name','type')]
    [string]$Field,

    [Parameter(Mandatory = $false)]
    [int]$CacheSeconds = 900
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataRoot = Join-Path $env:ProgramData 'Zabbix'
$CacheFile = Join-Path $DataRoot 'kms_licenses_cache.json'

$LicenseStatusMap = @{
    0 = 'Unlicensed'
    1 = 'Licensed'
    2 = 'OOBGrace'
    3 = 'OOTGrace'
    4 = 'NonGenuineGrace'
    5 = 'Notification'
    6 = 'ExtendedGrace'
}

function Ensure-DataRoot {
    if (-not (Test-Path -LiteralPath $DataRoot)) {
        New-Item -Path $DataRoot -ItemType Directory -Force | Out-Null
    }
}

function Get-StableProductId {
    param(
        [string]$Name,
        [string]$ApplicationId,
        [string]$Id,
        [string]$PartialProductKey
    )

    $seed = '{0}|{1}|{2}|{3}' -f $Name, $ApplicationId, $Id, $PartialProductKey
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($seed)
        $hash = $sha1.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha1.Dispose()
    }
}

function Get-ProductType {
    param([string]$Name, [string]$ApplicationId)

    if ($ApplicationId -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -or $Name -match 'Windows') {
        return 'Windows'
    }
    if ($Name -match 'Visio') {
        return 'Visio'
    }
    if ($Name -match 'Project') {
        return 'Project'
    }
    if ($Name -match 'Office|Microsoft Office|LTSC|Mondo|ProPlus|Standard|Professional Plus') {
        return 'Office'
    }
    return 'Other'
}

function Convert-Product {
    param($Product)

    $productType = Get-ProductType -Name $Product.Name -ApplicationId ([string]$Product.ApplicationID)
    if ($productType -eq 'Other') {
        return $null
    }

    $graceMinutes = -1
    if ($null -ne $Product.GracePeriodRemaining) {
        try {
            $graceMinutes = [double]$Product.GracePeriodRemaining
        }
        catch {
            $graceMinutes = -1
        }
    }

    $days = -1
    if ($graceMinutes -ge 0) {
        $days = [math]::Floor($graceMinutes / 1440)
    }

    $statusCode = 0
    if ($null -ne $Product.LicenseStatus) {
        $statusCode = [int]$Product.LicenseStatus
    }

    $statusText = if ($LicenseStatusMap.ContainsKey($statusCode)) {
        $LicenseStatusMap[$statusCode]
    }
    else {
        'Unknown'
    }

    [PSCustomObject]@{
        productid         = Get-StableProductId -Name ([string]$Product.Name) -ApplicationId ([string]$Product.ApplicationID) -Id ([string]$Product.ID) -PartialProductKey ([string]$Product.PartialProductKey)
        name              = [string]$Product.Name
        type              = $productType
        application_id    = [string]$Product.ApplicationID
        product_object_id = [string]$Product.ID
        partial_key       = [string]$Product.PartialProductKey
        status_code       = $statusCode
        state             = $statusText
        minutes           = $graceMinutes
        days              = $days
    }
}

function Read-Cache {
    if (-not (Test-Path -LiteralPath $CacheFile)) {
        return $null
    }

    $item = Get-Item -LiteralPath $CacheFile
    $age = (Get-Date) - $item.LastWriteTime
    if ($age.TotalSeconds -gt $CacheSeconds) {
        return $null
    }

    try {
        $raw = Get-Content -LiteralPath $CacheFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Write-Cache {
    param([object]$Data)

    Ensure-DataRoot
    $json = $Data | ConvertTo-Json -Depth 8 -Compress
    Set-Content -LiteralPath $CacheFile -Value $json -Encoding UTF8
}

function Get-FreshInventory {
    $all = Get-CimInstance -ClassName SoftwareLicensingProduct

    $filtered = foreach ($item in $all) {
        if (-not $item.Name) { continue }
        if (-not $item.PartialProductKey) { continue }
        $converted = Convert-Product -Product $item
        if ($null -ne $converted) {
            $converted
        }
    }

    # Deduplicate by productid in case CIM returns repeated records.
    $unique = $filtered | Sort-Object productid -Unique

    [PSCustomObject]@{
        generated_at = (Get-Date).ToString('s')
        count        = @($unique).Count
        products     = @($unique)
    }
}

function Get-Inventory {
    $cached = Read-Cache
    if ($null -ne $cached) {
        return $cached
    }

    $fresh = Get-FreshInventory
    Write-Cache -Data $fresh
    return $fresh
}

function Write-Discovery {
    $inventory = Get-Inventory

    $data = foreach ($p in @($inventory.products)) {
        [PSCustomObject]@{
            '{#PRODUCTID}'   = [string]$p.productid
            '{#PRODUCTNAME}' = [string]$p.name
            '{#PRODUCTTYPE}' = [string]$p.type
        }
    }

    [PSCustomObject]@{ data = @($data) } | ConvertTo-Json -Depth 5 -Compress
}

function Write-Metric {
    if ([string]::IsNullOrWhiteSpace($ProductId)) {
        throw 'ProductId is required in metric mode.'
    }
    if ([string]::IsNullOrWhiteSpace($Field)) {
        throw 'Field is required in metric mode.'
    }

    $inventory = Get-Inventory
    $product = @($inventory.products) | Where-Object { $_.productid -eq $ProductId } | Select-Object -First 1

    if ($null -eq $product) {
        switch ($Field) {
            'days'        { '-1'; return }
            'minutes'     { '-1'; return }
            'status_code' { '0'; return }
            default       { 'NotFound'; return }
        }
    }

    switch ($Field) {
        'days'        { [string]$product.days }
        'minutes'     { [string]$product.minutes }
        'state'       { [string]$product.state }
        'status_code' { [string]$product.status_code }
        'name'        { [string]$product.name }
        'type'        { [string]$product.type }
    }
}

try {
    switch ($Mode) {
        'discover' { Write-Output (Write-Discovery) }
        'metric'   { Write-Output (Write-Metric) }
    }
    exit 0
}
catch {
    switch ($Mode) {
        'discover' { Write-Output '{"data":[]}' }
        'metric' {
            switch ($Field) {
                'days'        { Write-Output '-1' }
                'minutes'     { Write-Output '-1' }
                'status_code' { Write-Output '0' }
                default       { Write-Output 'Error' }
            }
        }
    }
    exit 0
}
