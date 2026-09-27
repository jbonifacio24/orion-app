using Xunit;

namespace MotoHub.Infrastructure.Tests.SqlServer;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class SqlServerCollection : ICollectionFixture<SqlServerTestFixture>
{
    public const string Name = "SqlServer";
}