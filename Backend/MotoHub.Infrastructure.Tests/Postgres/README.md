# PostgreSQL integration tests

These tests require a local PostgreSQL role with permission to create databases. Set a connection string to the maintenance database in the current PowerShell session:

```powershell
$env:MOTOHUB_TEST_POSTGRES = "Host=localhost;Port=5432;Database=postgres;Username=postgres"
```

If local authentication requires a password, add it to the connection string in the terminal only. Do not commit credentials. The fixture accepts loopback hosts only, creates a uniquely named `MotoHub_Test_<GUID>` database, applies the EF migrations, and drops only that generated database during cleanup.

Run only PostgreSQL integration tests:

```powershell
dotnet test --filter "Category=Postgres"
```

Run tests that do not require a PostgreSQL connection:

```powershell
dotnet test --filter "Category!=Postgres"
```