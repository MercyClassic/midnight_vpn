# Midnight VPN — macOS

## Описание
**Нативное macOS приложение в menu bar для запуска `sing-box` (v1.13+).** <br>
**Приложение живёт в menu bar без иконки в Dock и предоставляет следующее API:**
- **Запуск / остановка VPN**
- **Смена конфига**
- **Просмотр логов в реальном времени**
- **Редактирование конфига**
- **Выход**

### Вот как это выглядит:

### Трей

<img src="docs/images/tray.png" width="300"/>

### Логи

<img src="docs/images/logs.png" width="600"/>

## Требования

- **macOS 13+**
- **[sing-box](https://github.com/SagerNet/sing-box) установленный через Homebrew:**
```bash
brew install sing-box
```

## Старт

**1. Открываем Midnight.dmg и переносим его в Applications** <br>

**2. Кладём конфиг в папку:** <br>
`~/Library/Application Support/Midnight/configs/config.json`

**3. Разрешаем sing-box запускаться без пароля — добавляем путь в sudoers: (`sudo visudo`)** <br>
`your_username ALL=(ALL) NOPASSWD: /opt/homebrew/bin/sing-box`

**4. Запускаем приложение:** <br>
`open Midnight.app` или через `Finder`

При первом запуске macOS может заблокировать приложение.
Переходим в **Системные настройки → Конфиденциальность и безопасность → Открыть всё равно**.

## Автозапуск при входе

**Системные настройки → Основные → Объекты входа → добавить `Midnight.app`**

## Компиляция:
Если по каким-либо причинам придётся изменить исходный код приложения, то можно пересобрать `Midnight.app`: 

```bash
# по умолчанию используется сертификат с названием MidnightDev

# собрать Midnight.app с сертификатом MidnightDev
./build.sh

# собрать Midnight.app со своим сертификатом
./build.sh --cert "Название сертификата"

# собрать и упаковать в dmg
./build.sh --cert "Название сертификата" --package
```
