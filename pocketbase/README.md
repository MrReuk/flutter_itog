# Сервер «Атриума» (PocketBase 0.40.6)

Запуск: `start.bat` (Windows) или `./pocketbase serve` (Linux/macOS, бинарный файл скачайте со страницы релизов PocketBase).
При первом запуске автоматически создаются коллекции (`pb_migrations/`) и тестовые данные; серверные правила лежат в `pb_hooks/`.

- Панель управления: http://127.0.0.1:8090/_/ — `root@atrium.test` / `Root123456`
- REST API: http://127.0.0.1:8090/api/

| Роль | Email | Пароль |
|---|---|---|
| Администратор | admin@atrium.test | Admin12345 |
| Кассир | cashier@atrium.test | Cashier12345 |
| Зритель | viewer@atrium.test | Viewer12345 |

`reset.bat` удаляет базу, чтобы создать её заново (нужно после изменения миграций).

Схема базы:

- `schema.sql` – физическая схема в виде SQL (SQLite), с комментариями об ограничениях;
- `pb_schema.json` – экспорт коллекций в формате PocketBase (Settings → Import collections), включая правила доступа.
