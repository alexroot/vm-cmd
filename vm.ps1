# Подключение модулей
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\vmsl.ps1"   # Модуль для простого переноса ВМ
. "$scriptPath\vmtags.ps1" # Модуль для переноса тегов и атрибутов
. "$scriptPath\info.ps1"   # Модуль для просмотра информации о ВМ

# Проверка наличия файла конфигурации
$configFile = "$scriptPath\config.json"
if (-Not (Test-Path $configFile)) {
    Write-Host "Файл конфигурации config.json не найден." -ForegroundColor Red
    exit
}

# Загрузка конфигурации
try {
    $config = Get-Content $configFile | ConvertFrom-Json
    $vCenterServer = $config.vCenterServer
} catch {
    Write-Host "Ошибка при чтении файла конфигурации: $_" -ForegroundColor Red
    exit
}

# Проверка наличия модуля VMware PowerCLI
function Test-PowerCLIModule {
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Host "Модуль VMware PowerCLI не установлен. Установите его с помощью команды:" -ForegroundColor Red
        Write-Host "Install-Module -Name VMware.PowerCLI -Scope CurrentUser" -ForegroundColor Yellow
        exit
    }
    Import-Module VMware.PowerCLI -ErrorAction Stop
}

# Функция для проверки подключения к vCenter
function Is-ConnectedToVCenter {
    try {
        # Попытка выполнить команду Get-Datacenter
        Get-Datacenter -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Функция для вывода меню
function Show-Menu {
    param (
        [bool]$isConnected  # Статус подключения
    )

    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Скрипт для работы с .vmx файлами виртуальных машин" -ForegroundColor Cyan
    Write-Host "Автор: Grinevich Alexandr, Версия 1.3" -ForegroundColor Cyan
    Write-Host "========================================="
    if ($isConnected) {
        Write-Host "Статус подключения: Подключено" -ForegroundColor Green
    } else {
        Write-Host "Статус подключения: Не подключено" -ForegroundColor Red
    }
    Write-Host "1. Подключиться" -ForegroundColor Yellow
    if (-not $isConnected) {
        Write-Host "   (Не подключено)" -ForegroundColor Red
    } else {
        Write-Host "   (Подключено)" -ForegroundColor Green
    }
    Write-Host "2. Перенос тегов и атрибутов" -ForegroundColor Yellow
    Write-Host "3. Простой перенос ВМ" -ForegroundColor Yellow
    Write-Host "4. Информация о ВМ" -ForegroundColor Yellow
    Write-Host "5. Отключиться" -ForegroundColor Yellow
    Write-Host "6. Выход" -ForegroundColor Yellow
    Write-Host "========================================="
}

# Главная логика скрипта
Test-PowerCLIModule

while ($true) {
    $isConnected = Is-ConnectedToVCenter
    Show-Menu -isConnected $isConnected
    $choice = Read-Host "Выберите действие (1-6)"

    switch ($choice) {
        "1" {
            if (-not $isConnected) {
                try {
                    # Запрос учетных данных
                    $credential = Get-Credential -Message "Введите учетные данные для подключения к vCenter"

                    # Подключение к vCenter
                    Connect-VIServer -Server $vCenterServer -Credential $credential -ErrorAction Stop
                    Write-Host "Успешно подключено к vCenter: $vCenterServer" -ForegroundColor Green
                } catch {
                    Write-Host "Ошибка подключения к vCenter: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Вы уже подключены к vCenter." -ForegroundColor Yellow
            }
        }
        "2" {
            if (-not $isConnected) {
                Write-Host "Необходимо сначала подключиться к vCenter." -ForegroundColor Red
                continue
            }
            $sourceVmName = Read-Host "Введите название исходной виртуальной машины"
            $targetVmName = Read-Host "Введите название целевой виртуальной машины"
            Transfer-VmTagsAndAttributes -sourceVmName $sourceVmName -targetVmName $targetVmName
        }
        "3" {
            if (-not $isConnected) {
                Write-Host "Необходимо сначала подключиться к vCenter." -ForegroundColor Red
                continue
            }

            # Запрос названия виртуальной машины у пользователя
            $vmName = Read-Host "Введите название виртуальной машины для простого переноса"

            # Вызов функции из модуля vm.ps1
            Simple-VmMigration -vmName $vmName
        }
        "4" {
            if (-not $isConnected) {
                Write-Host "Необходимо сначала подключиться к vCenter." -ForegroundColor Red
                continue
            }
            # Вызов функции из модуля vm.ps1
            Info
        }
        "5" {
            if ($isConnected) {
                try {
                    # Отключение от vCenter
                    Disconnect-VIServer -Confirm:$false -Force -ErrorAction Stop
                    Write-Host "Успешно отключено от vCenter." -ForegroundColor Green
                } catch {
                    Write-Host "Ошибка отключения от vCenter: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Вы уже отключены от vCenter." -ForegroundColor Yellow
            }
        }
        "6" {
            Write-Host "Выход из скрипта..." -ForegroundColor Cyan
            break
        }
        default {
            Write-Host "Неверный выбор. Пожалуйста, выберите действие от 1 до 6." -ForegroundColor Red
        }
    }

    # Если выбран выход, завершаем цикл
    if ($choice -eq "6") {
        break
    }

    Read-Host "Нажмите Enter для продолжения..."
}