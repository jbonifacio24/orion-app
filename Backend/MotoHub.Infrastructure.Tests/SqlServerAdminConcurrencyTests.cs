using System.Collections;
using System.Data;
using System.Data.Common;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Administration;
using MotoHub.Infrastructure.Auditing;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerAdminConcurrencyTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task UpdateStatusAsync_WhenTwoOperationalAdminsDeactivateEachOtherConcurrently_CharacterizesLastAdminProtection()
    {
        var setup = await CreateInitialStateAsync();
        using var synchronization = new OperationalAdminReadBarrier(
            setup.AdminRoleName,
            [setup.AdminAId, setup.AdminBId],
            TimeSpan.FromSeconds(30));
        await using var actorA = CreateProvider(synchronization);
        await using var actorB = CreateProvider(synchronization);

        var taskA = DeactivateAsync(actorA, setup.AdminAId, setup.AdminBId, setup.AdminBRowVersion, synchronization);
        var taskB = DeactivateAsync(actorB, setup.AdminBId, setup.AdminAId, setup.AdminARowVersion, synchronization);
        var results = await Task.WhenAll(taskA, taskB);

        Assert.Equal(2, synchronization.Arrivals);

        await using var verification = fixture.CreateContext();
        var profiles = await verification.Users
            .IgnoreQueryFilters()
            .Where(user => user.Id == setup.AdminAId || user.Id == setup.AdminBId)
            .ToDictionaryAsync(user => user.Id);
        var roleId = await verification.Set<MotoHubIdentityRole>()
            .Where(role => role.NormalizedName == setup.AdminRoleName)
            .Select(role => role.Id)
            .SingleAsync();
        var operationalAdminCount = await (
            from userRole in verification.Set<IdentityUserRole<Guid>>()
            join role in verification.Set<MotoHubIdentityRole>() on userRole.RoleId equals role.Id
            join profile in verification.Users.IgnoreQueryFilters() on userRole.UserId equals profile.Id
            where role.Id == roleId && profile.IsActive && !profile.IsDeleted
            select userRole.UserId).Distinct().CountAsync();
        var auditCount = await verification.AuditLogs.CountAsync(log => log.Action == "UserDeactivated");

        Assert.True(operationalAdminCount >= 1, "The last operational Admin invariant was violated.");
        Assert.Equal(results.Count(result => result.Response is not null), auditCount);

        AssertProfileOutcome(results, setup.AdminAId, setup.AdminBId, profiles);
        AssertProfileOutcome(results, setup.AdminBId, setup.AdminAId, profiles);

        Assert.True(await verification.Set<IdentityUserRole<Guid>>()
            .AnyAsync(userRole => userRole.UserId == setup.AdminAId && userRole.RoleId == roleId));
        Assert.True(await verification.Set<IdentityUserRole<Guid>>()
            .AnyAsync(userRole => userRole.UserId == setup.AdminBId && userRole.RoleId == roleId));
    }

    private async Task<InitialState> CreateInitialStateAsync()
    {
        await using var context = fixture.CreateContext();
        var adminRole = new MotoHubIdentityRole
        {
            Name = AdminSecurity.AdminRole,
            NormalizedName = AdminSecurity.AdminRole.ToUpperInvariant()
        };
        var adminA = NewIdentityUser("admin-a");
        var adminB = NewIdentityUser("admin-b");
        context.Set<MotoHubIdentityRole>().Add(adminRole);
        context.Set<MotoHubIdentityUser>().AddRange(adminA, adminB);
        context.Set<IdentityUserRole<Guid>>().AddRange(
            new IdentityUserRole<Guid> { UserId = adminA.Id, RoleId = adminRole.Id },
            new IdentityUserRole<Guid> { UserId = adminB.Id, RoleId = adminRole.Id });
        context.Users.AddRange(NewProfile(adminA), NewProfile(adminB));
        await context.SaveChangesAsync();

        await using var baseline = fixture.CreateContext();
        var profiles = await baseline.Users
            .IgnoreQueryFilters()
            .Where(user => user.Id == adminA.Id || user.Id == adminB.Id)
            .ToDictionaryAsync(user => user.Id);
        return new InitialState(
            adminA.Id,
            adminB.Id,
            adminRole.NormalizedName!,
            profiles[adminA.Id].RowVersion.ToArray(),
            profiles[adminB.Id].RowVersion.ToArray());
    }

    private ServiceProvider CreateProvider(OperationalAdminReadBarrier synchronization)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddHttpContextAccessor();
        services.AddDbContext<MotoHubDbContext>(options =>
        {
            options.UseSqlServer(fixture.ConnectionString, sql =>
                sql.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName));
            options.AddInterceptors(synchronization);
        });
        services.AddIdentityCore<MotoHubIdentityUser>()
            .AddRoles<MotoHubIdentityRole>()
            .AddEntityFrameworkStores<MotoHubDbContext>();
        services.AddScoped<ISessionRevocationService, SessionRevocationService>();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IAdminOperationalAccessService, AdminOperationalAccessService>();
        services.AddScoped<IAdminUserService, AdminUserService>();
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }

    private static async Task<ActorResult> DeactivateAsync(
        ServiceProvider provider,
        Guid actorId,
        Guid targetId,
        byte[] targetRowVersion,
        OperationalAdminReadBarrier synchronization)
    {
        try
        {
            await using var scope = provider.CreateAsyncScope();
            scope.ServiceProvider.GetRequiredService<IHttpContextAccessor>().HttpContext =
                new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(
                        [new Claim(ClaimTypes.NameIdentifier, actorId.ToString())], "test"))
                };
            var service = scope.ServiceProvider.GetRequiredService<IAdminUserService>();
            var response = await service.UpdateStatusAsync(
                actorId,
                targetId,
                new AdminUserStatusRequest(false, Convert.ToBase64String(targetRowVersion)),
                "127.0.0.1",
                default);
            return new ActorResult(actorId, targetId, response, null);
        }
        catch (Exception exception)
        {
            synchronization.Cancel(exception);
            return new ActorResult(actorId, targetId, null, exception);
        }
    }

    private static void AssertProfileOutcome(
        IReadOnlyCollection<ActorResult> results,
        Guid actorId,
        Guid targetId,
        IReadOnlyDictionary<Guid, User> profiles)
    {
        var result = Assert.Single(results, item => item.ActorId == actorId);
        if (result.Response is not null)
        {
            Assert.False(profiles[targetId].IsActive);
        }
        else
        {
            Assert.True(profiles[targetId].IsActive);
        }
    }

    private static MotoHubIdentityUser NewIdentityUser(string name)
    {
        var suffix = Guid.NewGuid().ToString("N");
        return new MotoHubIdentityUser
        {
            Id = Guid.NewGuid(),
            UserName = $"{name}-{suffix}",
            NormalizedUserName = $"{name}-{suffix}".ToUpperInvariant(),
            Email = $"{name}-{suffix}@example.test",
            NormalizedEmail = $"{name}-{suffix}@EXAMPLE.TEST",
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString()
        };
    }

    private static User NewProfile(MotoHubIdentityUser identityUser)
        => new(identityUser.Id)
        {
            UserName = identityUser.UserName!,
            NormalizedUserName = identityUser.NormalizedUserName!,
            Email = identityUser.Email!,
            NormalizedEmail = identityUser.NormalizedEmail!,
            IsActive = true,
            IsDeleted = false
        };

    private sealed record InitialState(
        Guid AdminAId,
        Guid AdminBId,
        string AdminRoleName,
        byte[] AdminARowVersion,
        byte[] AdminBRowVersion);

    private sealed record ActorResult(
        Guid ActorId,
        Guid TargetId,
        AdminUserStatusResponse? Response,
        Exception? Exception);

    private sealed class OperationalAdminReadBarrier(
        string adminRoleName,
        IReadOnlyCollection<Guid> actorIds,
        TimeSpan timeout) : DbCommandInterceptor, IDisposable
    {
        private readonly TaskCompletionSource<bool> released =
            new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly CancellationTokenSource timeoutCancellation = new(timeout);
        private int arrivals;

        public int Arrivals => Volatile.Read(ref arrivals);

        public override ValueTask<DbDataReader> ReaderExecutedAsync(
            DbCommand command,
            CommandExecutedEventData eventData,
            DbDataReader result,
            CancellationToken cancellationToken = default)
            => ValueTask.FromResult<DbDataReader>(
                IsTargetQuery(command) ? new CoordinatedReader(result, this) : result);

        public override DbDataReader ReaderExecuted(
            DbCommand command,
            CommandExecutedEventData eventData,
            DbDataReader result)
            => IsTargetQuery(command) ? new CoordinatedReader(result, this) : result;

        public async ValueTask AwaitSecondPositiveResultAsync(CancellationToken cancellationToken)
        {
            if (Interlocked.Increment(ref arrivals) == 2)
                released.TrySetResult(true);

            using var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(
                cancellationToken,
                timeoutCancellation.Token);
            try
            {
                await released.Task.WaitAsync(linkedCancellation.Token);
            }
            catch
            {
                released.TrySetCanceled(linkedCancellation.Token);
                throw;
            }
        }

        public void Cancel(Exception exception) => released.TrySetException(exception);

        public void Dispose() => timeoutCancellation.Dispose();

        private bool IsTargetQuery(DbCommand command)
        {
            if (command.CommandType != CommandType.Text ||
                !command.CommandText.Contains("AspNetUserRoles", StringComparison.OrdinalIgnoreCase) ||
                !command.CommandText.Contains("AspNetRoles", StringComparison.OrdinalIgnoreCase) ||
                !command.CommandText.Contains("Users", StringComparison.OrdinalIgnoreCase) ||
                !command.CommandText.Contains("NormalizedName", StringComparison.OrdinalIgnoreCase) ||
                !command.CommandText.Contains("IsActive", StringComparison.OrdinalIgnoreCase) ||
                !command.CommandText.Contains("IsDeleted", StringComparison.OrdinalIgnoreCase) ||
                !command.CommandText.Contains("UserId] <>", StringComparison.Ordinal))
            {
                return false;
            }

            var values = command.Parameters.Cast<DbParameter>()
                .Select(parameter => parameter.Value)
                .ToArray();
            return values.Any(value => string.Equals(value?.ToString(), adminRoleName, StringComparison.Ordinal)) &&
                values.Any(value => value is Guid id && actorIds.Contains(id));
        }

        private sealed class CoordinatedReader(DbDataReader inner, OperationalAdminReadBarrier barrier)
            : DbDataReader
        {
            private bool positiveRowReturned;
            private bool barrierPassed;

            public override bool Read()
            {
                var hasRow = inner.Read();
                if (hasRow && !positiveRowReturned)
                {
                    positiveRowReturned = true;
                    WaitForBarrier();
                }

                return hasRow;
            }

            public override async Task<bool> ReadAsync(CancellationToken cancellationToken)
            {
                var hasRow = await inner.ReadAsync(cancellationToken);
                if (hasRow && !positiveRowReturned)
                {
                    positiveRowReturned = true;
                    await WaitForBarrierAsync(cancellationToken);
                }

                return hasRow;
            }

            private void WaitForBarrier()
            {
                if (!barrierPassed)
                {
                    barrier.AwaitSecondPositiveResultAsync(default).AsTask().GetAwaiter().GetResult();
                    barrierPassed = true;
                }
            }

            private async ValueTask WaitForBarrierAsync(CancellationToken cancellationToken)
            {
                if (!barrierPassed)
                {
                    await barrier.AwaitSecondPositiveResultAsync(cancellationToken);
                    barrierPassed = true;
                }
            }

            public override int Depth => inner.Depth;
            public override int FieldCount => inner.FieldCount;
            public override bool HasRows => inner.HasRows;
            public override bool IsClosed => inner.IsClosed;
            public override int RecordsAffected => inner.RecordsAffected;
            public override object this[int ordinal] => inner[ordinal];
            public override object this[string name] => inner[name];
            public override bool GetBoolean(int ordinal) => inner.GetBoolean(ordinal);
            public override byte GetByte(int ordinal) => inner.GetByte(ordinal);
            public override long GetBytes(int ordinal, long dataOffset, byte[]? buffer, int bufferOffset, int length)
                => inner.GetBytes(ordinal, dataOffset, buffer, bufferOffset, length);
            public override char GetChar(int ordinal) => inner.GetChar(ordinal);
            public override long GetChars(int ordinal, long dataOffset, char[]? buffer, int bufferOffset, int length)
                => inner.GetChars(ordinal, dataOffset, buffer, bufferOffset, length);
            public override string GetDataTypeName(int ordinal) => inner.GetDataTypeName(ordinal);
            public override DateTime GetDateTime(int ordinal) => inner.GetDateTime(ordinal);
            public override decimal GetDecimal(int ordinal) => inner.GetDecimal(ordinal);
            public override double GetDouble(int ordinal) => inner.GetDouble(ordinal);
            public override Type GetFieldType(int ordinal) => inner.GetFieldType(ordinal);
            public override float GetFloat(int ordinal) => inner.GetFloat(ordinal);
            public override Guid GetGuid(int ordinal) => inner.GetGuid(ordinal);
            public override short GetInt16(int ordinal) => inner.GetInt16(ordinal);
            public override int GetInt32(int ordinal) => inner.GetInt32(ordinal);
            public override long GetInt64(int ordinal) => inner.GetInt64(ordinal);
            public override string GetName(int ordinal) => inner.GetName(ordinal);
            public override int GetOrdinal(string name) => inner.GetOrdinal(name);
            public override string GetString(int ordinal) => inner.GetString(ordinal);
            public override object GetValue(int ordinal) => inner.GetValue(ordinal);
            public override int GetValues(object[] values) => inner.GetValues(values);
            public override bool IsDBNull(int ordinal) => inner.IsDBNull(ordinal);
            public override bool NextResult() => inner.NextResult();
            public override IEnumerator GetEnumerator() => inner.GetEnumerator();
            public override DataTable? GetSchemaTable() => inner.GetSchemaTable();
            public override void Close() => inner.Close();

            protected override void Dispose(bool disposing)
            {
                if (disposing)
                    inner.Dispose();
                base.Dispose(disposing);
            }
        }
    }
}