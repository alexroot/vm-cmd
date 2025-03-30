function Compare-VmMacAddresses {
    param (
        [Parameter(Mandatory=$true)]
        [string]$sourceVmName,

        [Parameter(Mandatory=$true)]
        [string]$targetVmName
    )

    # Поиск исходной ВМ
    $sourceVm = Get-VM -Name $sourceVmName -ErrorAction SilentlyContinue
    if (-not $sourceVm) {
        Write-Host "Исходная ВМ '$sourceVmName' не найдена." -ForegroundColor Red
        return
    }

    # Поиск целевой ВМ
    $targetVm = Get-VM -Name $targetVmName -ErrorAction SilentlyContinue
    if (-not $targetVm) {
        Write-Host "Целевая ВМ '$targetVmName' не найдена." -ForegroundColor Red
        return
    }

    # Получение MAC-адресов исходной ВМ
    $sourceMacAddresses = $sourceVm | Get-NetworkAdapter | Select-Object Name, MacAddress
    if ($sourceMacAddresses.Count -eq 0) {
        Write-Host "У исходной ВМ '$sourceVmName' нет сетевых адаптеров." -ForegroundColor Yellow
        return
    }

    # Получение MAC-адресов целевой ВМ
    $targetMacAddresses = $targetVm | Get-NetworkAdapter | Select-Object Name, MacAddress
    if ($targetMacAddresses.Count -eq 0) {
        Write-Host "У целевой ВМ '$targetVmName' нет сетевых адаптеров." -ForegroundColor Yellow
        return
    }

    # Сравнение количества адаптеров
    if ($sourceMacAddresses.Count -ne $targetMacAddresses.Count) {
        Write-Host "Количество сетевых адаптеров не совпадает:" -ForegroundColor Red
        Write-Host "  Исходная ВМ: $($sourceMacAddresses.Count) адаптер(а/ов)" -ForegroundColor Red
        Write-Host "  Целевая ВМ: $($targetMacAddresses.Count) адаптер(а/ов)" -ForegroundColor Red
        return
    }

    # Сравнение MAC-адресов
    Write-Host "Сравнение MAC-адресов..." -ForegroundColor Cyan
    $mismatchFound = $false

    for ($i = 0; $i -lt $sourceMacAddresses.Count; $i++) {
        $sourceAdapter = $sourceMacAddresses[$i]
        $targetAdapter = $targetMacAddresses[$i]

        if ($sourceAdapter.MacAddress -ne $targetAdapter.MacAddress) {
            Write-Host "MAC-адреса не совпадают для адаптера '$($sourceAdapter.Name)':" -ForegroundColor Red
            Write-Host "  Исходная ВМ: $($sourceAdapter.MacAddress)" -ForegroundColor Red
            Write-Host "  Целевая ВМ: $($targetAdapter.MacAddress)" -ForegroundColor Red
            $mismatchFound = $true
        } else {
            Write-Host "MAC-адрес для адаптера '$($sourceAdapter.Name)' совпадает: $($sourceAdapter.MacAddress)" -ForegroundColor Green
        }
    }

    if (-not $mismatchFound) {
        Write-Host "Все MAC-адреса совпадают." -ForegroundColor Green
    } else {
        Write-Host "Обнаружены различия в MAC-адресах." -ForegroundColor Red
    }
}