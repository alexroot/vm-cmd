# Укажите имя вашей виртуальной машины
$vmName = "app-server"

# Путь к файлу blacklist.txt (в текущей папке)
$blacklistFile = ".\blacklist.txt"

# Загружаем blacklist в массив
if (Test-Path $blacklistFile) {
    $blacklist = Get-Content -Path $blacklistFile | Where-Object { $_ -ne "" }
} else {
    Write-Host "Файл blacklist.txt не найден. Продолжаем без фильтрации." -ForegroundColor Yellow
    $blacklist = @()
}


# Получаем объект виртуальной машины
$vm = Get-VM -Name $vmName

if ($vm) {
    # Массив для хранения информации об исходных дисках
    $originalDisksInfo = @()

    # Массив для хранения команд cp
    $cpCommands = @()

    # Получаем информацию о жестких дисках (Hard Disk) для этой ВМ
    $hardDisks = $vm | Get-HardDisk

    foreach ($disk in $hardDisks) {
        # Разбираем путь к VMDK
        if ($disk.Filename -match "\[(.*?)\]\s+(.*)") {
            $originalDatastore = $matches[1]  # Имя оригинального datastore
            $originalVmdkPath = $matches[2]  # Путь внутри оригинального datastore

            # Формируем полный путь в формате /vmfs/volumes/<datastore>/<vmdk>
            $originalFullPath = "/vmfs/volumes/$originalDatastore/$originalVmdkPath"

            # Сохраняем информацию об исходном диске
            $originalDisksInfo += [PSCustomObject]@{
                DiskName       = $disk.Name
                OriginalPath   = $originalFullPath
            }

            # Формируем шаблон для snap-datastore (snap-<любые_символы>-<имя_исходного_datastore>)
            $snapDatastorePattern = "snap-*-$(($originalDatastore -split '\.')[-1])"  # Поддержка snap-XXX-LUNSSD

            # Ищем все snap-datastores через vCenter
            $snapDatastores = Get-Datastore | Where-Object { $_.Name -like $snapDatastorePattern }

            if ($snapDatastores.Count -eq 0) {
                Write-Host "  Snap-datastores для '$originalDatastore' не найдены." -ForegroundColor Yellow
            } else {
                foreach ($snapDatastore in $snapDatastores) {
                    # Проверяем, находится ли snap-datastore в черном списке
                    if ($blacklist -contains $snapDatastore.Name) {
                        Write-Host "  Snap-datastore '$($snapDatastore.Name)' для '$originalDatastore' пропущен (в черном списке)." -ForegroundColor Red
                        continue
                    }

                    # Формируем путь к snap-VMDK
                    $snapFullPath = "/vmfs/volumes/$($snapDatastore.Name)/$originalVmdkPath"

                    # Сохраняем команду cp
                    $cpCommands += "cp $snapFullPath $originalFullPath"
                }
            }
        } else {
            Write-Host "Не удалось разобрать путь для диска: $($disk.Name)" -ForegroundColor Red
        }
    }

    # Добавляем обработку .vmx файла
    $vmxFileInfo = $vm | Get-View | Select-Object -ExpandProperty Config | Select-Object -ExpandProperty Files
    $originalVmxPath = $vmxFileInfo.VmPathName
    if ($originalVmxPath -match "\[(.*?)\]\s+(.*)") {
        $originalVmxDatastore = $matches[1]
        $originalVmxFilePath = $matches[2]
        $originalVmxFullPath = "/vmfs/volumes/$originalVmxDatastore/$originalVmxFilePath"

        # Сохраняем информацию о .vmx файле
        $originalDisksInfo += [PSCustomObject]@{
            DiskName       = "VMX File"
            OriginalPath   = $originalVmxFullPath
        }

        # Формируем шаблон для snap-datastore (snap-<любые_символы>-<имя_исходного_datastore>)
        $snapDatastorePattern = "snap-*-$(($originalVmxDatastore -split '\.')[-1])"

        # Ищем все snap-datastores через vCenter
        $snapDatastores = Get-Datastore | Where-Object { $_.Name -like $snapDatastorePattern }

        if ($snapDatastores.Count -eq 0) {
            Write-Host "  Snap-datastores для '$originalVmxDatastore' не найдены." -ForegroundColor Yellow
        } else {
            foreach ($snapDatastore in $snapDatastores) {
                # Проверяем, находится ли snap-datastore в черном списке
                if ($blacklist -contains $snapDatastore.Name) {
                    Write-Host "  Snap-datastore '$($snapDatastore.Name)' для '$originalVmxDatastore' пропущен (в черном списке)." -ForegroundColor Red
                    continue
                }

                # Формируем путь к snap-VMX
                $snapVmxFullPath = "/vmfs/volumes/$($snapDatastore.Name)/$originalVmxFilePath"

                # Сохраняем команду cp
                $cpCommands += "cp $snapVmxFullPath $originalVmxFullPath"
            }
        }
    } else {
        Write-Host "Не удалось разобрать путь для .vmx файла." -ForegroundColor Red
    }

    # Выводим информацию об исходных дисках
    Write-Host "`nИнформация по исходным дискам:" -ForegroundColor Green
    foreach ($info in $originalDisksInfo) {
        Write-Host "  Диск: $($info.DiskName)" -ForegroundColor Yellow
        Write-Host "    Путь: $($info.OriginalPath)"
    }

    # Выводим команды cp
    Write-Host "`nКоманды для копирования snap-VMDK и snap-VMX в исходное расположение:" -ForegroundColor Green
    foreach ($command in $cpCommands) {
        Write-Host $command
    }

    # Экспорт всей информации в текстовый файл
    $outputFileName = "$((Get-Date).ToString('yyyyMMdd_HHmmss')).$($vm.Name).txt"
    $outputFilePath = Join-Path -Path $PWD -ChildPath $outputFileName

    $outputContent = @"
Информация по исходным дискам:
$(foreach ($info in $originalDisksInfo) {
    "  Диск: $($info.DiskName)    Путь: $($info.OriginalPath)`n"
})

Команды для копирования snap-VMDK и snap-VMX в исходное расположение:
$($cpCommands -join "`n")
"@

    Set-Content -Path $outputFilePath -Value $outputContent -Encoding UTF8
    Write-Host "`nВся информация экспортирована в файл: $outputFilePath" -ForegroundColor Green
} else {
    Write-Host "Виртуальная машина с именем '$vmName' не найдена." -ForegroundColor Red
}