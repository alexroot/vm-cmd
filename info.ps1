function Info {
# Запрос названия ВМ у пользователя
$vmName = Read-Host "Введите название виртуальной машины"

# Поиск ВМ
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "Виртуальная машина '$vmName' не найдена." -ForegroundColor Red
    exit
}

# Получение сетевых адаптеров
$networkAdapters = $vm | Get-NetworkAdapter

if ($networkAdapters.Count -eq 0) {
    Write-Host "У виртуальной машины '$vmName' нет сетевых адаптеров." -ForegroundColor Yellow
} else {
    Write-Host "MAC-адреса виртуальной машины '$vmName':" -ForegroundColor Green
    foreach ($adapter in $networkAdapters) {
        Write-Host "  Адаптер: $($adapter.Name), MAC-адрес: $($adapter.MacAddress)" -ForegroundColor Cyan
    }
}
Write-Host "Расположение VMX файла:"
Write-Host -ForegroundColor Cyan $vm.extensiondata.config.files.vmpathname
}