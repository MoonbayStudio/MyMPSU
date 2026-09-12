# Installation and configuration

This guide creates a new MyMPSU installation with an empty PostgreSQL
database. Existing user accounts are not needed.

## 1. Prepare the host

For a local installation, install Git and Docker with Compose support. For a
small production installation, use a supported Linux server with persistent
storage, HTTPS and automated backups.

Check the tools:

```bash
git --version
docker version
docker compose version
```

## 2. Clone and configure

```bash
git clone https://github.com/MoonbayStudio/MyMPSU.git
cd MyMPSU
cp .env.example .env
```

Generate secrets instead of using the example values:

```bash
openssl rand -hex 32
```

Use different generated values for `DATABASE_PASSWORD` and `JWT_SECRET`.

The `.env.example` file is the configuration checklist. Read every section and
replace every `example.org` address. The minimum local configuration is:

```dotenv
DATABASE_PASSWORD=<random database password>
JWT_SECRET=<random JWT signing secret>
OWNER_EMAILS=owner@example.com
ADMIN_EMAILS=admin@example.com
ENABLE_AI_AGENT=false
CORS_ORIGINS=http://localhost:8080
```

`OWNER_EMAILS` and `ADMIN_EMAILS` do not create accounts. A person first signs
in through a configured provider; an account whose email matches one of these
lists receives the corresponding privileges.

`CORS_ORIGINS` is a comma-separated list of web frontends allowed to call the
API from a browser. Replace the local URL with the HTTPS address of the
production website.

The Compose stack constructs `DATABASE_URL` automatically from `POSTGRES_DB`,
`POSTGRES_USER` and `DATABASE_PASSWORD`. Do not add a second database container
or expose PostgreSQL merely to connect the API.

## 3. Start and verify

```bash
docker compose up --build -d
docker compose ps
curl --fail http://127.0.0.1:8000/health
```

On first startup, the API creates every missing table in the empty database.
Inspect logs if it does not become healthy:

```bash
docker compose logs --tail=200 api db
```

## 4. Optional services

### AI assistant

The simplest setup uses OpenRouter. Create an API key, then add these values to
the root `.env` file (never to a client-side `VITE_*` variable):

```dotenv
ENABLE_AI_AGENT=true
AI_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=openrouter/free
OPENROUTER_SITE_URL=https://mympsu.example.org
OPENROUTER_APP_NAME=MyMPSU
```

`openrouter/free` lets OpenRouter select an available free model. To pin a
specific free model later, replace `OPENROUTER_MODEL` with its current model ID
ending in `:free`, then restart the API. Free models have lower rate limits and
availability than paid models, so they are best suited to the first version and
low-volume use.

The assistant's main system prompt lives in
`API/personas/default/pelikasha.md`; seasonal variants are in sibling persona
folders. Schedule facts are appended by the backend from the selected group and
date, so the model is instructed not to invent lessons.

For a fully local alternative, install Ollama on the Docker host, make it listen
on an address reachable from containers, and download the selected model. For
example:

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
ollama pull <model-name>
```

Keep TCP `11434` blocked by the server firewall. Docker reaches it through the
private host gateway added by `docker-compose.yml`. Set the same model name in
`.env`:

```dotenv
ENABLE_AI_AGENT=true
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://host.docker.internal:11434
PELIKASHA_MODEL=<model-name>
```

Verify Ollama from inside the API container:

```bash
docker compose exec api python -c \
  "import urllib.request; print(urllib.request.urlopen('http://host.docker.internal:11434/api/tags').status)"
```

If AI is not needed, leave `ENABLE_AI_AGENT=false`. The backend and schedule
features can run without Ollama.

### Email

Password recovery and email verification need a real SMTP account. Configure
the `SMTP_*` variables in `.env`. Do not use the example sender addresses unless
the new operator controls the corresponding domain.

### Apple and Google sign-in

Create OAuth applications owned by the new maintenance team, then fill the
Apple and Google client identifiers. Mobile bundle identifiers, signing teams,
redirect URLs and API addresses are currently tied to the official deployment;
see the handover checklist before distributing a forked mobile build.

## 5. Deploy the API on a server

### DNS

Create an `A` record such as `api.mympsu.example.org` pointing to the public
IPv4 address of the server. Add an `AAAA` record only if IPv6 is configured and
protected by the firewall too.

Set these values in `.env`:

```dotenv
API_BIND_ADDRESS=127.0.0.1
API_PORT=8000
FRONTEND_BASE_URL=https://mympsu.example.org
CORS_ORIGINS=https://mympsu.example.org
```

### Ports and firewall

Publicly allow:

- TCP `80` — HTTP redirect and certificate issuance;
- TCP `443` — HTTPS API traffic;
- TCP `22` — SSH, preferably restricted to maintainer addresses or a VPN.

Do not publicly allow:

- TCP `5432` — PostgreSQL;
- TCP `8000` — internal FastAPI port when a reverse proxy is used;
- TCP `11434` — Ollama.

The supplied Compose file does not publish PostgreSQL at all and binds FastAPI
to `127.0.0.1` by default.

### HTTPS reverse proxy

Install Caddy or nginx on the host. A minimal Caddy configuration is:

```caddyfile
api.mympsu.example.org {
    reverse_proxy 127.0.0.1:8000
}
```

After DNS resolves to the server, start the containers and reload Caddy:

```bash
docker compose up --build -d
sudo systemctl reload caddy
curl --fail https://api.mympsu.example.org/health
```

Do not expose FastAPI directly without HTTPS. Authentication tokens and account
data travel through this endpoint.

## 6. API endpoints and documentation

After startup:

- `/health` — basic process health check;
- `/docs` — interactive Swagger UI;
- `/redoc` — alternative API documentation;
- `/openapi.json` — machine-readable OpenAPI schema.

Local examples:

```bash
curl --fail http://127.0.0.1:8000/health
curl --fail http://127.0.0.1:8000/openapi.json -o openapi.json
```

Production examples:

```bash
curl --fail https://api.mympsu.example.org/health
```

Swagger is useful for maintainers, but authenticated endpoints still require a
valid user token. If public API documentation is not desired in production,
restrict `/docs`, `/redoc` and `/openapi.json` in the reverse proxy until the
application provides an environment switch for them.

## 7. Stop or remove

Stop containers without deleting data:

```bash
docker compose down
```

Delete the local database permanently:

```bash
docker compose down --volumes
```

Back up first if any data must be retained.
