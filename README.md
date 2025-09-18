# Midnight VPN

## Описание
**Кастомный исполняемый файл (`.exe`) для запуска `sing-box.exe` с конфигурацией**

## Запуск через ярлык
Быстрый запуск ядра без компиляции (`sing-box.exe`).  
Создаём ярлык и в поле **Объект** указываем:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command "& 'C:\Apps\midnight\core\sing-box.exe' run -c 'C:\Apps\midnight\core\config.json'"
```

## Компиляция:
Сборка midnight.exe
### 1. Заходим в core папку
`cd C:\Apps\midnight`

### 2. Компилируем логгер
`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /t:exe /out:core\logger.exe /win32icon:icons\log.ico scripts\logger.cs`

### 3. Компилируем клиент
`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /t:winexe /out:midnight.exe /win32icon:icons\gear.ico scripts\midnight.cs`
