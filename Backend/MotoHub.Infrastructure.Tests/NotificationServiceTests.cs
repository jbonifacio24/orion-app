using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using MotoHub.Application.Errors;
using MotoHub.Application.Notifications;
using MotoHub.Domain;
using MotoHub.Infrastructure.Notifications;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class NotificationServiceTests
{
    [Fact]
    public async Task Get_returns_only_active_notifications_for_the_recipient_in_deterministic_order()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var createdAt = DateTimeOffset.UtcNow.AddMinutes(-1);
        var older = AddNotification(context, ownerId, NotificationType.System, createdAt: createdAt);
        var newer = AddNotification(context, ownerId, NotificationType.Security, createdAt: createdAt);
        AddNotification(context, otherUserId, NotificationType.System, createdAt: DateTimeOffset.UtcNow);
        AddNotification(context, ownerId, NotificationType.Message, expiresAt: DateTimeOffset.UtcNow.AddMinutes(-1));
        await context.SaveChangesAsync();

        var response = await Service(context).GetAsync(ownerId, new(Page: 1, PageSize: 1), default);
        var expectedOrder = new[] { older, newer }.OrderByDescending(notification => notification.Id).ToArray();

        Assert.Equal(2, response.TotalCount);
        Assert.Equal(2, response.TotalPages);
        Assert.Equal(expectedOrder[0].Id, response.Items.Single().Id);
        Assert.DoesNotContain(response.Items, item => item.Id == expectedOrder[1].Id);
    }

    [Fact]
    public async Task Get_applies_unread_type_and_pagination_filters()
    {
        await using var context = CreateContext();
        var userId = Guid.NewGuid();
        var first = AddNotification(context, userId, NotificationType.Theft, createdAt: DateTimeOffset.UtcNow.AddMinutes(-2));
        first.ReadAt = DateTimeOffset.UtcNow.AddMinutes(-1);
        AddNotification(context, userId, NotificationType.Theft, createdAt: DateTimeOffset.UtcNow.AddMinutes(-1));
        AddNotification(context, userId, NotificationType.System, createdAt: DateTimeOffset.UtcNow);
        await context.SaveChangesAsync();

        var response = await Service(context).GetAsync(
            userId,
            new(Page: 1, PageSize: 1, UnreadOnly: true, Type: NotificationType.Theft),
            default);

        Assert.Equal(1, response.TotalCount);
        Assert.Equal(NotificationType.Theft, response.Items.Single().Type);
        Assert.False(response.Items.Single().IsRead);
    }

    [Fact]
    public async Task Unread_count_ignores_other_users_read_and_expired_notifications()
    {
        await using var context = CreateContext();
        var userId = Guid.NewGuid();
        AddNotification(context, userId, NotificationType.System);
        var read = AddNotification(context, userId, NotificationType.System);
        read.ReadAt = DateTimeOffset.UtcNow;
        AddNotification(context, userId, NotificationType.System, expiresAt: DateTimeOffset.UtcNow.AddMinutes(-1));
        AddNotification(context, Guid.NewGuid(), NotificationType.System);
        await context.SaveChangesAsync();

        var response = await Service(context).GetUnreadCountAsync(userId, default);

        Assert.Equal(1, response.Count);
    }

    [Fact]
    public async Task Mark_read_is_idempotent_and_cannot_mark_another_users_notification()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var notification = AddNotification(context, ownerId, NotificationType.System);
        var otherNotification = AddNotification(context, otherUserId, NotificationType.System);
        await context.SaveChangesAsync();

        var service = Service(context);
        await service.MarkReadAsync(ownerId, notification.Id, default);
        var readAt = notification.ReadAt;
        await service.MarkReadAsync(ownerId, notification.Id, default);

        Assert.Equal(readAt, notification.ReadAt);
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.MarkReadAsync(ownerId, otherNotification.Id, default));
    }

    [Fact]
    public async Task Mark_all_read_affects_only_active_unread_notifications_of_the_user()
    {
        await using var context = CreateContext();
        var userId = Guid.NewGuid();
        var active = AddNotification(context, userId, NotificationType.System);
        var expired = AddNotification(context, userId, NotificationType.System, expiresAt: DateTimeOffset.UtcNow.AddMinutes(-1));
        var other = AddNotification(context, Guid.NewGuid(), NotificationType.System);
        await context.SaveChangesAsync();

        await Service(context).MarkAllReadAsync(userId, default);

        Assert.NotNull(active.ReadAt);
        Assert.Null(expired.ReadAt);
        Assert.Null(other.ReadAt);
        await Service(context).MarkAllReadAsync(userId, default);
    }

    [Fact]
    public async Task Mark_all_read_retries_after_a_concurrency_conflict_without_leaving_eligible_notifications_unread()
    {
        var databaseName = Guid.NewGuid().ToString();
        var userId = Guid.NewGuid();
        await using (var seedContext = CreateContext(databaseName))
        {
            AddNotification(seedContext, userId, NotificationType.System);
            var alreadyRead = AddNotification(seedContext, userId, NotificationType.System);
            alreadyRead.ReadAt = DateTimeOffset.UtcNow.AddMinutes(-1);
            AddNotification(seedContext, userId, NotificationType.System, expiresAt: DateTimeOffset.UtcNow.AddMinutes(-1));
            AddNotification(seedContext, Guid.NewGuid(), NotificationType.System);
            await seedContext.SaveChangesAsync();
        }

        await using var context = CreateContext(databaseName, new FailOnceConcurrencyInterceptor());

        await Service(context).MarkAllReadAsync(userId, default);

        var stored = await context.Notifications
            .Where(notification => notification.RecipientUserId == userId)
            .ToListAsync();
        Assert.Equal(2, stored.Count(notification => notification.ReadAt is not null));
        Assert.Single(stored, notification => notification.ExpiresAt is not null && notification.ReadAt is null);
    }

    [Fact]
    public async Task Valid_target_is_exposed_but_invalid_json_or_resource_is_ignored()
    {
        await using var context = CreateContext();
        var userId = Guid.NewGuid();
        var valid = AddNotification(context, userId, NotificationType.Theft, dataJson: JsonSerializer.Serialize(new
        {
            resourceType = "TheftReport",
            resourceId = Guid.NewGuid()
        }));
        var invalidJson = AddNotification(context, userId, NotificationType.System, dataJson: "not-json");
        var unknownType = AddNotification(context, userId, NotificationType.System, dataJson: JsonSerializer.Serialize(new
        {
            resourceType = "Message",
            resourceId = Guid.NewGuid()
        }));
        var emptyId = AddNotification(context, userId, NotificationType.System, dataJson: JsonSerializer.Serialize(new
        {
            resourceType = "TheftReport",
            resourceId = Guid.Empty
        }));
        await context.SaveChangesAsync();

        var response = await Service(context).GetAsync(userId, new(PageSize: 50), default);

        Assert.NotNull(response.Items.Single(item => item.Id == valid.Id).Target);
        Assert.Null(response.Items.Single(item => item.Id == invalidJson.Id).Target);
        Assert.Null(response.Items.Single(item => item.Id == unknownType.Id).Target);
        Assert.Null(response.Items.Single(item => item.Id == emptyId.Id).Target);
    }

    [Fact]
    public async Task Create_validates_limits_and_persists_a_safe_target_without_exposing_authority_fields()
    {
        await using var context = CreateContext();
        var userId = Guid.NewGuid();
        var service = Service(context);
        var targetId = Guid.NewGuid();

        var id = await service.CreateAsync(new(
            userId,
            null,
            NotificationType.Theft,
            "  Aviso  ",
            "  Se encontró una coincidencia.  ",
            new NotificationTargetDto("TheftReport", targetId)), default);

        var stored = await context.Notifications.SingleAsync(notification => notification.Id == id);
        Assert.Equal("Aviso", stored.Title);
        Assert.Equal("Se encontró una coincidencia.", stored.Body);
        Assert.Contains("TheftReport", stored.DataJson);
        Assert.Equal(NotificationType.Theft, stored.Type);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(new(
            userId, null, NotificationType.System, new string('x', 201), "body"), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(new(
            userId, null, NotificationType.System, "title", new string('x', 2001)), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(new(
            userId, null, NotificationType.System, "title", "body",
            new NotificationTargetDto("Message", targetId)), default));
    }

    [Fact]
    public async Task Create_rejects_an_undefined_notification_type_without_persisting()
    {
        await using var context = CreateContext();
        var service = Service(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(new(
            Guid.NewGuid(), null, (NotificationType)999, "title", "body"), default));

        Assert.Equal(0, await context.Notifications.CountAsync());
    }

    [Fact]
    public async Task Query_rejects_invalid_paging_and_type()
    {
        await using var context = CreateContext();
        var service = Service(context);
        var userId = Guid.NewGuid();

        await Assert.ThrowsAsync<ValidationException>(() => service.GetAsync(userId, new(Page: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetAsync(userId, new(PageSize: 51), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetAsync(userId, new(Type: (NotificationType)999), default));
    }

    private static NotificationService Service(MotoHubDbContext context) => new(context);

    private static Notification AddNotification(
        MotoHubDbContext context,
        Guid recipientUserId,
        NotificationType type,
        DateTimeOffset? createdAt = null,
        DateTimeOffset? expiresAt = null,
        string? dataJson = null)
    {
        var notification = new Notification
        {
            RecipientUserId = recipientUserId,
            Type = type,
            Title = "Title",
            Body = "Body",
            ExpiresAt = expiresAt,
            DataJson = dataJson,
            CreatedAt = createdAt ?? DateTimeOffset.UtcNow
        };
        context.Notifications.Add(notification);
        return notification;
    }

    private static MotoHubDbContext CreateContext(
        string? databaseName = null,
        SaveChangesInterceptor? interceptor = null)
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(databaseName ?? Guid.NewGuid().ToString())
            .AddInterceptors(interceptor is null ? [] : [interceptor])
            .Options;
        return new MotoHubDbContext(options);
    }

    private sealed class FailOnceConcurrencyInterceptor : SaveChangesInterceptor
    {
        private bool _hasFailed;

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (!_hasFailed)
            {
                _hasFailed = true;
                return ValueTask.FromException<InterceptionResult<int>>(
                    new DbUpdateConcurrencyException("Simulated concurrency conflict."));
            }

            return ValueTask.FromResult(result);
        }
    }
}