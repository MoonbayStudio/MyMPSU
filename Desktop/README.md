# Мой МПГУ Desktop

Нативно упакованный desktop-клиент на Tauri 2 с React, TypeScript и Vite. Одна
кодовая база предназначена для macOS, Windows и Linux; UI использует desktop-
навигацию, клавиатуру, адаптивный sidebar и системное окно, а не мобильный layout.

## Возможности MVP

- «Сегодня» и шестидневная недельная сетка;
- воспроизводимые тестовые пары, пока API расписания МПГУ не готов;
- offline-кэш последнего успешного расписания;
- список и CRUD домашних заданий с проверкой роли;
- вход, профиль и безопасное системное хранение токена;
- темы system/light/dark, dev/prod backend, восстановление окна;
- локальные уведомления по явному действию пользователя;
- сочетания `Cmd/Ctrl+1`, `Cmd/Ctrl+2`, `Cmd/Ctrl+3`, `Cmd/Ctrl+,` и `Cmd/Ctrl+R`.

## Требования

- Node.js 20.19+;
- Rust stable и системные зависимости Tauri 2;
- macOS: Xcode Command Line Tools;
- Windows: Microsoft C++ Build Tools и WebView2;
- Ubuntu: WebKitGTK 4.1 и зависимости из `.github/workflows/desktop.yml`.

Если Rust установлен на macOS через keg-only формулу Homebrew `rustup`, добавьте
его только для текущей shell-сессии (изменять `.zshrc` не обязательно):

```bash
export PATH="$(brew --prefix rustup)/bin:$PATH"
```

## Запуск

```bash
cd Desktop
cp .env.example .env
npm install
npm run tauri:dev
```

Frontend без нативной оболочки можно открыть командой `npm run dev`. В этом
режиме авторизация намеренно недоступна, потому что браузерный fallback не
сохраняет токен в `localStorage`.

## Проверки и сборка

```bash
npm run typecheck
npm run lint
npm test
npm run build
cargo check --manifest-path src-tauri/Cargo.toml
npm run tauri:build
```

Собирайте установщик на целевой ОС: `.app`/`.dmg` на macOS, MSI/NSIS на Windows,
AppImage/deb/rpm на Linux. CI проверяет каждую систему нативно; хрупкий
cross-compilation с macOS намеренно не используется.

## Структура

- `src/app` — оболочка, маршруты и app-wide state;
- `src/features` — экраны расписания, домашки, профиля и настроек;
- `src/api` — единый типизированный HTTP-клиент;
- `src/models` — API/domain contracts;
- `src/platform` — storage, credentials, notifications и OS abstraction;
- `src/services` — бизнес-логика, права и генератор расписания;
- `src-tauri` — минимальная Rust-оболочка и capabilities.

## Environments и тестовое расписание

Публичные URL задаются в `.env` по примеру `.env.example`. Переменные `VITE_*`
встраиваются в bundle и не подходят для секретов. Выбранное окружение и режим
тестового расписания меняются также в Settings. Генератор использует seed из
группы и начала недели: данные разнообразны между неделями, но стабильны для
тестов и скриншотов.

Production API аккаунта: `https://api.mympsu.moonbaystudio.ru`; development:
`http://127.0.0.1:8000`. Настоящее расписание включается после появления
контракта: реализуйте mapping в `src/api/schedule.ts` и выключите mock toggle.

## Безопасность

Capabilities ограничены main window, Store/OS/Notification/Window State. Shell
и произвольный filesystem не разрешены. CSP допускает только локальный bundle и
два задокументированных API origin. Токен хранится через crate `keyring` в
системном credential vault. Общие правила: `../docs/SECURITY.md`.

## Deep links и updater

Маршруты `/schedule`, `/homework`, `/profile` готовы стать целями
`mympsu://...`. Регистрацию deep-link plugin следует включить вместе с политикой
single-instance перед релизом и протестировать на каждой ОС.

Updater пока выключен (`createUpdaterArtifacts: false`): production endpoint и
ключ подписи не существуют. Для включения потребуется сгенерировать отдельную
пару ключей, хранить приватный ключ только в CI secrets, добавить публичный ключ
и HTTPS endpoint в Tauri config, затем включить updater artifacts. Не коммитьте
приватный ключ.

## Ограничения

- API расписания заменён mock provider по умолчанию;
- вход и домашние задания требуют доступного MyMPSU backend и реального аккаунта;
- macOS можно проверить в текущей среде, Windows/Linux проверяются только на
  соответствующих runners/машинах;
- deep links и updater подготовлены архитектурно, но не активированы до релиза.
