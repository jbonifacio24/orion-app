using System.Collections;
using System.Data;
using System.Data.Common;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerRefreshTokenConcurrencyTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task RefreshAsync_WhenSameTokenIsConsumedConcurrently_CharacterizesRowVersionOutcome()
    {
        var setup = await CreateInitialSessionAsync();
        using var synchronization = new RefreshTokenReadBarrier(setup.TokenHash, TimeSpan.FromSeconds(30));
        await using var actorA = CreateActorProvider(synchronization);
        await using var actorB = CreateActorProvider(synchronization);

        var actorTaskA = RefreshAsync(actorA, setup.RawToken, synchronization);
        var actorTaskB = RefreshAsync(actorB, setup.RawToken, synchronization);
        var results = await Task.WhenAll(actorTaskA, actorTaskB);

        Assert.Equal(2, synchronization.Arrivals);
        Assert.Equal(1, results.Count(result => result.Response is not null));
        Assert.Equal(1, results.Count(result => result.Exception is not null));

        var failure = Assert.Single(results, result => result.Exception is not null).Exception!;
        Assert.IsType<DbUpdateConcurrencyException>(failure);

        await using var verification = fixture.CreateContext();
        var tokens = await verification.RefreshTokens
            .Where(token => token.UserId == setup.UserId)
            .ToListAsync();
        var original = Assert.Single(tokens, token => token.Id == setup.TokenId);
        var replacements = tokens.Where(token => token.Id != setup.TokenId).ToList();
        var replacement = Assert.Single(replacements);
        var now = DateTimeOffset.UtcNow;

        Assert.NotNull(original.RevokedAt);
        Assert.Equal("Rotated", original.RevocationReason);
        Assert.False(setup.InitialRowVersion.SequenceEqual(original.RowVersion));
        Assert.Equal(replacement.Id, original.ReplacedByTokenId);
        Assert.Null(replacement.RevokedAt);
        Assert.True(replacement.ExpiresAt > now);
        Assert.Null(replacement.ReplacedByTokenId);

        var winner = Assert.Single(results, result => result.Response is not null).Response!;
        Assert.Equal(replacement.TokenHash, JwtTokenService.HashRefreshToken(winner.RefreshToken));
    }

    private async Task<InitialSession> CreateInitialSessionAsync()
    {
        await using var provider = CreateActorProvider(interceptor: null);
        await using var scope = provider.CreateAsyncScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<MotoHubIdentityUser>>();
        var user = new MotoHubIdentityUser
        {
            Id = Guid.NewGuid(),
            UserName = $"refresh-{Guid.NewGuid():N}",
            Email = $"refresh-{Guid.NewGuid():N}@example.test",
            EmailConfirmed = true
        };
        var identityResult = await userManager.CreateAsync(user, "StrongPassword1!");
        Assert.True(identityResult.Succeeded, string.Join("; ", identityResult.Errors.Select(error => error.Description)));

        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        context.Users.Add(new User(user.Id)
        {
            UserName = user.UserName!,
            NormalizedUserName = user.UserName!.ToUpperInvariant(),
            Email = user.Email!,
            NormalizedEmail = user.Email!.ToUpperInvariant(),
            IsActive = true,
            EmailConfirmed = true
        });
        await context.SaveChangesAsync();

        var authentication = scope.ServiceProvider.GetRequiredService<AuthenticationService>();
        var login = await authentication.LoginAsync(
            new LoginRequest(user.Email!, "StrongPassword1!"),
            "127.0.0.1",
            default);
        var token = await context.RefreshTokens.SingleAsync(refreshToken => refreshToken.UserId == user.Id);

        return new InitialSession(
            user.Id,
            token.Id,
            login.RefreshToken,
            token.TokenHash,
            token.RowVersion.ToArray());
    }

    private ServiceProvider CreateActorProvider(RefreshTokenReadBarrier? interceptor)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddHttpContextAccessor();
        services.AddDataProtection();
        services.AddAuthentication();
        services.AddDbContext<MotoHubDbContext>(options =>
        {
            options.UseSqlServer(fixture.ConnectionString, sql =>
                sql.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName));
            if (interceptor is not null)
            {
                options.AddInterceptors(interceptor);
            }
        });
        services.AddIdentityCore<MotoHubIdentityUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.SignIn.RequireConfirmedEmail = false;
                options.Password.RequiredLength = 12;
                options.Password.RequireDigit = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireLowercase = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
            })
            .AddRoles<MotoHubIdentityRole>()
            .AddEntityFrameworkStores<MotoHubDbContext>()
            .AddSignInManager()
            .AddDefaultTokenProviders();
        services.Configure<JwtOptions>(options =>
        {
            options.Issuer = "MotoHub.Tests";
            options.Audience = "MotoHub.Tests.Client";
            options.SigningKey = "01234567890123456789012345678901";
            options.AccessTokenMinutes = 10;
            options.RefreshTokenDays = 14;
        });
        services.Configure<AuthOptions>(options => options.RequireConfirmedEmail = false);
        services.AddScoped<JwtTokenService>();
        services.AddScoped<ISessionRevocationService, SessionRevocationService>();
        services.AddScoped<AuthenticationService>();
        services.AddSingleton<IEmailSender, NoOpEmailSender>();

        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }

    private static async Task<RefreshResult> RefreshAsync(
        ServiceProvider provider,
        string rawToken,
        RefreshTokenReadBarrier synchronization)
    {
        try
        {
            await using var scope = provider.CreateAsyncScope();
            var authentication = scope.ServiceProvider.GetRequiredService<AuthenticationService>();
            return new RefreshResult(
                await authentication.RefreshAsync(new RefreshTokenRequest(rawToken), "127.0.0.1", default),
                null);
        }
        catch (Exception exception)
        {
            synchronization.Cancel(exception);
            return new RefreshResult(null, exception);
        }
    }

    private sealed record InitialSession(
        Guid UserId,
        Guid TokenId,
        string RawToken,
        string TokenHash,
        byte[] InitialRowVersion);

    private sealed record RefreshResult(AuthResponse? Response, Exception? Exception);

    private sealed class NoOpEmailSender : IEmailSender
    {
        public Task SendAsync(string recipient, string subject, string body, CancellationToken cancellationToken)
            => Task.CompletedTask;
    }

    private sealed class RefreshTokenReadBarrier(string expectedHash, TimeSpan timeout) : DbCommandInterceptor, IDisposable
    {
        private readonly TaskCompletionSource<bool> released = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly CancellationTokenSource timeoutCancellation = new(timeout);
        private int arrivals;

        public int Arrivals => Volatile.Read(ref arrivals);

        public override ValueTask<DbDataReader> ReaderExecutedAsync(
            DbCommand command,
            CommandExecutedEventData eventData,
            DbDataReader result,
            CancellationToken cancellationToken = default)
        {
            if (!IsTargetQuery(command))
            {
                return ValueTask.FromResult(result);
            }

            return ValueTask.FromResult<DbDataReader>(new CoordinatedReader(result, this));
        }

        public override DbDataReader ReaderExecuted(
            DbCommand command,
            CommandExecutedEventData eventData,
            DbDataReader result)
        {
            return IsTargetQuery(command) ? new CoordinatedReader(result, this) : result;
        }

        public async ValueTask WaitForSecondReaderAsync(CancellationToken cancellationToken)
        {
            var arrival = Interlocked.Increment(ref arrivals);
            if (arrival == 2)
            {
                released.TrySetResult(true);
            }

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

        public void Cancel(Exception exception)
        {
            released.TrySetException(exception);
        }

        public void Dispose()
        {
            timeoutCancellation.Dispose();
        }

        private bool IsTargetQuery(DbCommand command)
        {
            return command.CommandType == System.Data.CommandType.Text &&
                command.CommandText.Contains("RefreshTokens", StringComparison.OrdinalIgnoreCase) &&
                command.CommandText.Contains("TokenHash", StringComparison.OrdinalIgnoreCase) &&
                command.Parameters.Cast<DbParameter>().Any(parameter =>
                    string.Equals(parameter.Value?.ToString(), expectedHash, StringComparison.Ordinal));
        }

        private sealed class CoordinatedReader(DbDataReader inner, RefreshTokenReadBarrier barrier) : DbDataReader
        {
            private bool firstRowRead;
            private bool barrierPassed;

            public override bool Read()
            {
                WaitBeforeNextRead();
                var hasRow = inner.Read();
                firstRowRead |= hasRow;
                return hasRow;
            }

            public override async Task<bool> ReadAsync(CancellationToken cancellationToken)
            {
                await WaitBeforeNextReadAsync(cancellationToken);
                var hasRow = await inner.ReadAsync(cancellationToken);
                firstRowRead |= hasRow;
                return hasRow;
            }

            private void WaitBeforeNextRead()
            {
                if (firstRowRead && !barrierPassed)
                {
                    barrier.WaitForSecondReaderAsync(default).AsTask().GetAwaiter().GetResult();
                    barrierPassed = true;
                }
            }

            private async ValueTask WaitBeforeNextReadAsync(CancellationToken cancellationToken)
            {
                if (firstRowRead && !barrierPassed)
                {
                    await barrier.WaitForSecondReaderAsync(cancellationToken);
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
                {
                    inner.Dispose();
                }

                base.Dispose(disposing);
            }
        }
    }
}