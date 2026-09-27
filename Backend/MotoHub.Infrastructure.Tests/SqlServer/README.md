# SQL Server tests

These tests require SQL Server LocalDB and an explicit test connection string.

```powershell
$env:MOTOHUB_TEST_SQLSERVER = "Server=(localdb)\MSSQLLocalDB;Integrated Security=true;TrustServerCertificate=true"
```

The fixture creates a unique `MotoHub_Test_<GUID>` database, applies the existing EF Core migrations, and drops only that generated database during cleanup.

Run the fast suite without SQL Server tests:

```powershell
dotnet test --filter "Category!=SqlServer"
```

Run only SQL Server tests:

```powershell
dotnet test --filter "Category=SqlServer"
```

Run the complete suite:

```powershell
dotnet test
```

Do not set `MOTOHUB_TEST_SQLSERVER` to a development or production database.
