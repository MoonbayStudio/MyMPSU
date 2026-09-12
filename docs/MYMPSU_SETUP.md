# Мой МПГУ: состояние и настройка форка

Основа: `MoonbayStudio/MyMPSU`, commit `83efba5838df81bbce02eb94f78d1ef6efa21f38`.
MyMPSU поддерживается как самостоятельный проект Moonbay Studio для МПГУ.

## Что адаптировано

- Название интерфейса: **Мой МПГУ**, имя проекта: **MyMPSU**.
- Apple: `iOS/MyMPSU.xcodeproj`, схема `MyMPSU`, bundle ID `MoonbayStudio.MyMPSU`;
  виджет `MoonbayStudio.MyMPSU.Widget`, отдельная App Group и ссылки `mympsu://`.
- Android: `ru.moonbaystudio.mympsu`, отдельная локальная база и настройки.
- Логотип: исходный `20121118132132!Mpgu_logo.jpg`. Экспорт без перерисовки,
  с сохранением пропорций и полями для масок системных иконок.
- Иконки iOS/macOS, Android, стартовые экраны, сайт и логотип в письмах.
- Основной акцент интерфейса: синий; альтернативные темы и специальные
  возможности исходного приложения сохранены.
- Письма, сайт, документация, Docker-проект и шаблоны БД используют MyMPSU.
- Название основного AI-помощника: «Помощник МПГУ». Имена программных типов
  `Pelikasha`, ключей API и модели Ollama оставлены совместимыми с исходным кодом.

## Расписание: требуется реализация адаптера МПГУ

Это подготовка бренда и отдельного проекта, а не готовая интеграция расписания МПГУ.
Схемы данных и преобразователи исходного API сохранены. Нельзя просто подставить
адрес будущего сервиса без адаптации: контракты институтов, групп и занятий
должны быть зафиксированы после появления API МПГУ.

Мобильные клиенты теперь ожидают совместимый сервис по адресу
`https://api.mympsu.moonbaystudio.ru/schedule/v1`. Этот адрес — настройка будущего
сервиса, его развёртывание и DNS не выполнялись и не проверялись.
В backend `MPGU_SCHEDULE_API_BASE_URL` по умолчанию пуст; обращение к адаптеру
возвращает HTTP 503 «Расписание МПГУ ещё не подключено».

Точки интеграции:

- `iOS/MyMPSU/Services/APIService.swift` — институты, группы и расписание;
- `Android/app/src/main/java/ru/moonbaystudio/mympsu/data/remote/MpguScheduleApiService.kt`;
- `Android/app/src/main/java/ru/moonbaystudio/mympsu/di/NetworkModule.kt`;
- `API/app/services/schedule_service.py` и `API/app/core/config.py`;
- `mcp/` — отдельный MCP-адаптер расписания МПГУ, не подключённый к приложению.
  Перед использованием нужно реализовать и проверить новый ScheduleProvider.

## Собственные внешние сервисы

`mympsu.moonbaystudio.ru` и `api.mympsu.moonbaystudio.ru` — предполагаемые адреса
проекта, не опубликованный сервис. Для запуска настройте:

1. Backend, БД, JWT, SMTP и DNS по `.env.example` и `docs/SETUP.md`.
2. App IDs, App Groups, capabilities и профили подписи для новых идентификаторов
   в Apple Developer. Подпись для распространения не проверялась.
3. Собственные Google OAuth clients и `GoogleService-Info.plist` для Apple;
   `GOOGLE_WEB_CLIENT_ID` в Android `util/Constants.kt`, Google IDs в backend.
   Значения OAuth из оригинала нельзя считать готовой конфигурацией MyMPSU.
4. Apple Service ID и callback в Android `util/Constants.kt`.
5. Продукты StoreKit / Google Play и отдельную публикацию приложений.
   Кнопки загрузки на сайте должны вести к Releases MyMPSU.
6. Собственную Ollama-модель (переменная `PELIKASHA_MODEL`) при включении AI.

Git remote `origin` указывает на пользовательский форк MyMPSU.
Изменения подготовлены локально; коммит, push и публикация не выполнялись.

## Повторный экспорт графики

Из корня репозитория:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/export-brand-assets.swift
```

Светлое и тёмное оформление используют один исходный знак на белой подложке.
Иконка не содержит сгенерированных элементов.

## Проверка этой адаптации

- iOS Simulator, Debug, схема `MyMPSU`: сборка проходит с отключённой подписью.
- Backend: 39 существующих тестов проходят; дополнительный тест проверяет
  HTTP 503 и отсутствие исходящего запроса при неподключённом расписании.
- Сайт: главная и страница выпусков проверены в браузере, логотип отображается.
- JSON каталогов ресурсов и ссылки на изображения Apple проверены.
- Запуск мобильных приложений на устройствах, вход, покупки и реальные
  расписания МПГУ не проверялись.

Команда сборки iOS из корня:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project iOS/MyMPSU.xcodeproj -scheme MyMPSU -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/mympsu-derived CODE_SIGNING_ALLOWED=NO build
```

В Android удалён унаследованный абсолютный путь Java на `/Volumes/T7`.
Используйте JDK 17 или 21; исходный Kotlin/KSP не работает с Java 25.
Пример для macOS с установленным JDK 21:

```bash
JAVA_HOME="$(/usr/libexec/java_home -v 21)" \
ANDROID_HOME="$HOME/Library/Android/sdk" \
Android/gradlew -p Android --no-daemon \
  -Pkotlin.compiler.execution.strategy=in-process assembleDebug
```

Android Debug также собран успешно. Артефакт:
`Android/app/build/outputs/apk/debug/app-debug.apk`.
В APK подтверждены имя «Мой МПГУ» и package `ru.moonbaystudio.mympsu`;
в собранном iOS-приложении — «Мой МПГУ» и `MoonbayStudio.MyMPSU`.
