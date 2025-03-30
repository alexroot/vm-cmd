$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\net-compare.ps1"  # Сравнение Мак адресов

function Simple-VmMigration {


    param (
        [Parameter(Mandatory=$true)]
        [string]$vmName
    )

    # Проверка входного параметра
    if ([string]::IsNullOrEmpty($vmName)) {
        Write-Host "Пустой параметр" -ForegroundColor DarkYellow
        return
    }

    # Загрузка черного списка LUN из файла
    $excludeLunsFile = ".\blacklist.txt"
    if (-Not (Test-Path $excludeLunsFile)) {
        Write-Host "Файл blacklist.txt не найден" -ForegroundColor Red
        return
    }

    $excludeLuns = Get-Content $excludeLunsFile | Where-Object { $_ -ne "" }

    # Вывод информации о скрипте
    Write-Host "=================================================================" -ForegroundColor DarkCyan
    Write-Host " "
    Write-Host $vmName -ForegroundColor Green

    # Поиск ВМ
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "ВМ $vmName не найдена" -ForegroundColor DarkYellow
        return
    }

    # Получение пользовательских полей
    $customFields = Get-Annotation -Entity $vm -CustomAttribute * | Where-Object { 
        $_.Value -ne $null -and $_.Value -ne "" 
   }

    # Получение тегов
    $sourceTags = Get-TagAssignment -Entity $vm

    # Информация об ОС
    $osID = $vm.ExtensionData.Config.GuestId
    $osName = $vm.ExtensionData.Config.GuestFullName
    if ($osID -match "sles11_64Guest") {
        Write-Host "SUSE Linux Enterprise 11 (64-bit)" -ForegroundColor Red
    } else {
        Write-Host "[$osID] $osName" -ForegroundColor DarkYellow
    }
    Write-Host " " -ForegroundColor DarkCyan

    # Информация о расположении
    $registerName = $vm.Name
    $newName = "$($vm.Name)_corrupted"
    $folderName = $vm.Folder.Name
    $resPool = $vm.ResourcePool | Select-Object -ExpandProperty Name

    Write-Host "[$resPool][$folderName]" -ForegroundColor DarkCyan
    Write-Host " "

    # Получение LUN
    $lun = (Get-VM -Name $vmName | Get-HardDisk).Filename |
        ForEach-Object { $_.Split(']')[0].TrimStart('[') } |
        Sort-Object -Unique

    Write-Host "$lun"

    if ($lun -like "snap*") {
        Write-Host "ВМ уже на SNAP LUN" -ForegroundColor DarkYellow
        return
    }

    # Поиск доступных хранилищ
    $newDatastores = Get-Datastore -Name "snap*$lun" |
        Where-Object { $excludeLuns -notcontains $_.Name }

    if ($newDatastores.Count -ne 1) {
        Write-Host "Нужно подключить SNAP LUN или количество лунов отлично от 1" -ForegroundColor Red
        return
    }

    $newDatastore = $newDatastores[0].Name
    Write-Host "$newDatastore"
    Write-Host " "

    # Переименование ВМ
    Write-Host "Переименовать оригинал: $newName"
    $answer = Read-Host "Нажмите 1 для переименования"

    if ($answer -eq "1") {
        Set-VM -VM $vm -Name $newName -Confirm:$false
    } else {
        Write-Host "Отмена переименования" -ForegroundColor DarkYellow
    }

    # Регистрация новой ВМ
    $vmxPath = "[$newDatastore] $registerName/$registerName.vmx"
    Write-Host "Путь vmx для регистрации:"
    Write-Host $vmxPath

    $answer = Read-Host "Нажмите 2 для регистрации"

    if ($answer -eq "2") {
        New-VM -VMFilePath $vmxPath -ResourcePool (Get-ResourcePool -Name $resPool) -Location $folderName
    } else {
        Write-Host "Отмена регистрации" -ForegroundColor DarkYellow
        return
    }

    # Применение тегов и пользовательских полей к новой ВМ
    $targetVM = Get-VM -Name $registerName

    foreach ($tag in $sourceTags) {
        New-TagAssignment -Entity $targetVM -Tag $tag.Tag -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Тег $($tag.Tag.Name)" -ForegroundColor Green
    }

    if ($customFields.Count -eq 0) {
        Write-Host "У исходной ВМ '$sourceVmName' нет непустых пользовательских атрибутов." -ForegroundColor Yellow
    } else {
        Write-Host "Перенос пользовательских атрибутов..." -ForegroundColor Green
        foreach ($field in $customFields) {
            try {
                # Проверка, что Name не пустой
                if ([string]::IsNullOrWhiteSpace($field.Name)) {
                    Write-Host "Пропущен атрибут с пустым именем." -ForegroundColor Yellow
                    continue
                }

                Set-Annotation -Entity $targetVm -CustomAttribute $field.Name -Value $field.Value -ErrorAction Stop | Out-Null
                Write-Host "Атрибут '$($field.Name)' успешно перенесён." -ForegroundColor Green
            } catch {
                Write-Host "Не удалось перенести атрибут '$($field.Name)': $_" -ForegroundColor Red
            }
        }
    }

    # Проверка MAC-адресов
    Compare-VmMacAddresses -sourceVmName $newName -targetVmName $registerName

}