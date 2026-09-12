# Operations and database management

This document covers the Docker Compose installation. Run commands from the
repository root.

## Service status and logs

```bash
docker compose ps
docker compose logs --tail=200 api
docker compose logs --tail=200 db
curl --fail http://127.0.0.1:8000/health
```

The current `/health` endpoint confirms that the API process responds. It does
not yet prove that PostgreSQL or external services are reachable, so also check
the container health states.

## Starting with an empty database

No user-account transfer is required. A new installation automatically creates
an empty schema:

```bash
cp .env.example .env
# Replace secrets in .env
docker compose up --build -d
```

Users register or sign in again against the new installation. Old sessions,
roles, homework and settings are not present.

## Backup

Create a SQL backup while the database is running:

```bash
make backup
```

The dump is written to `backups/mympsu-YYYYMMDD-HHMMSS.sql`. The directory is
ignored by Git. Copy backups to encrypted storage on a different machine.

A backup is not considered valid until a test restore has succeeded. Keep at
least several recent daily copies and one older monthly copy.

## Restore

Use a backup produced by the same or a compatible application version:

```bash
make restore FILE=backups/mympsu-YYYYMMDD-HHMMSS.sql
```

The command stops the API, asks for explicit confirmation, restores PostgreSQL
and starts the API again. Check the logs and `/health` afterwards.

Restoring an old production database transfers personal data. Only do this when
the new operator has a legitimate reason, appropriate access and a secure host.
For ordinary student continuity, prefer a new empty database.

## Update

Before updating:

```bash
git status --short
make backup
```

Then fetch the reviewed release and rebuild:

```bash
git pull --ff-only
docker compose up --build -d
docker compose ps
curl --fail http://127.0.0.1:8000/health
```

Deploy tagged releases in production instead of an arbitrary moving commit.

## Database inspection

Open a PostgreSQL shell:

```bash
docker compose exec db sh -c \
  'psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"'
```

The command and the backup/restore scripts read `POSTGRES_USER` and
`POSTGRES_DB` from the container environment.

Useful read-only commands inside `psql`:

```text
\dt
\d users
SELECT count(*) FROM users;
\q
```

Avoid editing rows manually. Administrative behavior should normally go through
the API so validation and audit logging remain active.

## Secret rotation

- Changing `DATABASE_PASSWORD` also requires changing the password stored by
  PostgreSQL; editing only `.env` will break the connection.
- Changing `JWT_SECRET` invalidates existing authentication tokens.
- Revoke and replace SMTP/OAuth credentials through their provider consoles.
- Never paste production secrets into issues, chat logs or documentation.

## Disaster recovery checklist

1. Provision a clean host with Docker.
2. Clone a reviewed release of the repository.
3. Create `.env` with new secrets.
4. Decide whether to start empty or restore an authorized backup.
5. Start the stack and verify container health.
6. Configure HTTPS and DNS.
7. Configure OAuth, email and AI only after the core API is healthy.
8. Record who now owns operational access.

## Network checklist

From outside the server, only HTTPS should be needed by the mobile and web
clients. Periodically verify:

```bash
curl --fail https://api.mympsu.example.org/health
```

Confirm with the host firewall or hosting control panel that PostgreSQL `5432`,
FastAPI `8000` and Ollama `11434` are not publicly reachable. A database shell,
backup or Ollama request should be performed locally over SSH, not by opening
those ports to the internet.
