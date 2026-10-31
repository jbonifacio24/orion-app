# MotoHub

MotoHub is a multiplatform application for motorcycle users.

## FASE 1

This repository currently contains the project foundation only:

- Flutter application in `frontend/` using Clean Architecture, Material 3, BLoC/Cubit, GetIt, Dio and GoRouter.
- ASP.NET Core solution in `Backend/` split into Domain, Application, Infrastructure and Api.
- No business features are implemented.

## Validation

From `frontend/`:

```text
flutter pub get
flutter analyze
flutter test
```

From the repository root:

```text
dotnet build MotoHub.sln
```

## Google Sign-In

The login screen supports Google on Flutter Web and Android. The public client ID is configured in `frontend/lib/core/constants/environment_config.dart` and `Backend/MotoHub.Api/appsettings.Development.json`. Register every Web origin in Google Cloud, including `http://localhost:3000` and `http://localhost:8080` for local development, plus the deployed site origin.

Run Flutter Web normally:

```text
cd frontend
flutter run -d chrome --web-port=8080
```

For Android, create an Android OAuth client in Google Cloud with application ID `com.example.motohub` and the SHA-1 fingerprints for each signing key (debug and release). The API uses the Web client ID as the expected ID-token audience.

Google sign-in links a verified Google email to an existing MotoHub account with the same email. New Google users receive a MotoHub profile and the default `User` role. The existing password login remains available.

## PostgreSQL

The backend uses PostgreSQL. The development connection defaults to `localhost:5432` with database `MotoHub_Fase2` and role `postgres`. If local authentication requires a password, provide the full connection string through `ConnectionStrings__MotoHubDatabase` in your local environment; do not commit credentials.

The SQL Server migration history has been replaced with a fresh PostgreSQL baseline. Existing database contents are not migrated. From the repository root, install the EF Core 8 CLI once and apply the baseline:

```powershell
$env:ConnectionStrings__MotoHubDatabase = "Host=localhost;Port=5432;Database=MotoHub_Fase2;Username=postgres"
$toolPath = Join-Path $env:TEMP 'MotoHubEfTools'
dotnet tool install --tool-path $toolPath dotnet-ef --version 8.0.18
& "$toolPath\dotnet-ef.exe" database update --project Backend\MotoHub.Infrastructure\MotoHub.Infrastructure.csproj --startup-project Backend\MotoHub.Api\MotoHub.Api.csproj --context MotoHubDbContext
```

If PostgreSQL requires a password, add it to the environment variable in your terminal before running the migration command.

## Docker Compose

The root `docker-compose.yml` applies EF Core migrations with a one-shot .NET 8 migrator, starts the API, and serves Flutter Web through Nginx. PostgreSQL runs directly on the Debian host; only product images use a Docker named volume. Set `DB_HOST` and `DB_PORT` in `.env` to the host address and PostgreSQL port. On Linux, Compose maps `host.docker.internal` to the Docker host.

On Debian, prepare the environment file and replace the example secrets. Use random hexadecimal values for the database password and JWT signing key:

```bash
cp .env.example .env
openssl rand -hex 32
nano .env
```

Before starting Compose, create the PostgreSQL role and database on Debian using the matching `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` values from `.env`:

```sql
CREATE ROLE motohub WITH LOGIN PASSWORD '<POSTGRES_PASSWORD from .env>';
CREATE DATABASE "MotoHub_Fase2" OWNER motohub;
```

Run these statements as the PostgreSQL administrator, and replace the example role/database names if `.env` uses different values.

For deployment, set `API_BASE_URL` to `https://api.your-domain.example/api` and `FRONTEND_ORIGIN` to `https://your-domain.example` (origin only, without a path). Start the services from the repository root:

```bash
docker compose up --build -d
docker compose ps
docker compose logs -f migrate api
```

Configure the Cloudflare Tunnel hostnames to send the frontend to `http://localhost:8080` and the API hostname to `http://localhost:5001`. These ports bind to loopback only; do not expose PostgreSQL's port publicly. The first startup applies the PostgreSQL baseline to the configured database. Existing databases and data are not copied automatically.

PostgreSQL must accept connections from the Docker bridge network. Configure `listen_addresses` and `pg_hba.conf` for that network, and restrict port 5432 with the Debian firewall to Docker-host traffic. Do not allow public access to PostgreSQL.
