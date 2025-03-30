function Transfer-VmTagsAndAttributes {
    param (
        [Parameter(Mandatory=$true)]
        [string]$sourceVmName,

        [Parameter(Mandatory=$true)]
        [string]$targetVmName
    )

    # Проверка существования исходной ВМ
    $sourceVm = Get-VM -Name $sourceVmName -ErrorAction SilentlyContinue
    if (-not $sourceVm) {
        Write-Host "Исходная ВМ '$sourceVmName' не найдена." -ForegroundColor Red
        return
    }

    # Проверка существования целевой ВМ
    $targetVm = Get-VM -Name $targetVmName -ErrorAction SilentlyContinue
    if (-not $targetVm) {
        Write-Host "Целевая ВМ '$targetVmName' не найдена." -ForegroundColor Red
        return
    }

    # Подтверждение операции
    Write-Host "Вы собираетесь перенести теги и кастомные атрибуты:" -ForegroundColor Yellow
    Write-Host "  Исходная ВМ: $sourceVmName" -ForegroundColor Cyan
    Write-Host "  Целевая ВМ: $targetVmName" -ForegroundColor Cyan
    $confirmation = Read-Host "Вы уверены, что хотите продолжить? (y/n)"
    if ($confirmation.ToLower() -ne "y") {
        Write-Host "Операция отменена." -ForegroundColor DarkYellow
        return
    }

    # Получение тегов исходной ВМ
    $sourceTags = Get-TagAssignment -Entity $sourceVm
    if ($sourceTags.Count -eq 0) {
        Write-Host "У исходной ВМ '$sourceVmName' нет тегов." -ForegroundColor Yellow
    } else {
        Write-Host "Перенос тегов..." -ForegroundColor Green
        foreach ($tag in $sourceTags) {
            try {
                New-TagAssignment -Entity $targetVm -Tag $tag.Tag -ErrorAction Stop | Out-Null
                Write-Host "Тег '$($tag.Tag.Name)' успешно перенесён." -ForegroundColor Green
            } catch {
                Write-Host "Не удалось перенести тег '$($tag.Tag.Name)': $_" -ForegroundColor Red
            }
        }
    }

    # Получение пользовательских атрибутов исходной ВМ
    $customFields = Get-Annotation -Entity $sourceVm -CustomAttribute * | Where-Object { 
         $_.Value -ne $null -and $_.Value -ne "" 
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

    Write-Host "Операция завершена." -ForegroundColor Green
}