using Xunit;

namespace MotoHub.Infrastructure.Tests.Postgres;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class PostgresCollection : ICollectionFixture<PostgresTestFixture>
{
    public const string Name = "Postgres";
}