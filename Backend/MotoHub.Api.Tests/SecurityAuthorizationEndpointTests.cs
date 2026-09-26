using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using MotoHub.Application;
using MotoHub.Application.Chat;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Moderation;
using MotoHub.Application.TheftReports;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Api.Tests;

public sealed class SecurityAuthorizationEndpointTests : IClassFixture<ApiFactory>
{
    private const string Password = "ValidPassword123";
    private readonly ApiFactory factory;

    public SecurityAuthorizationEndpointTests(ApiFactory factory)
    {
        this.factory = factory;
    }

    [Fact]
    public async Task Authenticated_me_returns_401_for_anonymous_request()
    {
        var response = await factory.CreateClient().GetAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Login_returns_session_for_active_user_and_401_for_invalid_credentials()
    {
        var user = await SeedUserAsync(password: Password);
        var client = factory.CreateClient();

        var valid = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(user.Email, Password));
        var invalid = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(user.Email, "WrongPassword123"));

        Assert.Equal(HttpStatusCode.OK, valid.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, invalid.StatusCode);
        var body = await valid.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(body);
        Assert.NotEmpty(body.AccessToken);
        Assert.NotEmpty(body.RefreshToken);
        Assert.Equal(user.Id, body.User.Id);
    }

    [Fact]
    public async Task Login_rejects_inactive_and_deleted_users()
    {
        var inactive = await SeedUserAsync(active: false, password: Password);
        var deleted = await SeedUserAsync(deleted: true, password: Password);
        var client = factory.CreateClient();

        var inactiveResponse = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(inactive.Email, Password));
        var deletedResponse = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(deleted.Email, Password));

        Assert.Equal(HttpStatusCode.Unauthorized, inactiveResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, deletedResponse.StatusCode);
    }

    [Fact]
    public async Task Refresh_rotates_token_and_reuse_is_rejected()
    {
        var user = await SeedUserAsync(password: Password);
        var client = factory.CreateClient();
        var login = await LoginAsync(client, user.Email, Password);

        var rotated = await client.PostAsJsonAsync("/api/auth/refresh", new RefreshTokenRequest(login.RefreshToken));
        var reuse = await client.PostAsJsonAsync("/api/auth/refresh", new RefreshTokenRequest(login.RefreshToken));

        Assert.Equal(HttpStatusCode.OK, rotated.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, reuse.StatusCode);
        Assert.Equal("application/problem+json", reuse.Content.Headers.ContentType?.MediaType);
    }

    [Theory]
    [InlineData("malformed")]
    [InlineData("expired")]
    [InlineData("invalid-signature")]
    [InlineData("invalid-issuer")]
    [InlineData("invalid-audience")]
    public async Task Invalid_jwt_is_rejected_by_authenticated_endpoint(string tokenKind)
    {
        var user = await SeedUserAsync();
        var token = CreateToken(user.Id, tokenKind);
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Valid_token_is_rejected_after_user_is_deactivated()
    {
        var user = await SeedUserAsync();
        var client = CreateAuthenticatedClient(user.Id);
        await SetUserStateAsync(user.Id, active: false);

        var response = await client.GetAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Valid_token_is_rejected_after_user_is_soft_deleted()
    {
        var user = await SeedUserAsync();
        var client = CreateAuthenticatedClient(user.Id);
        await SetUserStateAsync(user.Id, active: false, deleted: true);

        var response = await client.GetAsync("/api/auth/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Admin_token_is_rejected_after_admin_is_deactivated()
    {
        var admin = await SeedUserAsync(roles: [AdminSecurity.AdminRole]);
        var client = CreateAuthenticatedClient(admin.Id, AdminSecurity.AdminRole);
        await SetUserStateAsync(admin.Id, active: false);

        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Stale_chat_user_cannot_send_message()
    {
        var user = await SeedUserAsync(password: Password);
        var other = await SeedUserAsync();
        var conversation = await SeedConversationAsync(user.Id, other.Id);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, user.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);
        var before = await CountMessagesAsync(conversation.ConversationId);

        await SetUserStateAsync(user.Id, active: false);
        var response = await client.PostAsJsonAsync(
            $"/api/conversations/{conversation.ConversationId}/messages",
            new SendMessageRequest("stale message"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(before, await CountMessagesAsync(conversation.ConversationId));
    }

    [Fact]
    public async Task Stale_marketplace_owner_cannot_delete_product()
    {
        var user = await SeedUserAsync(password: Password);
        var productId = await SeedProductAsync(user.Id);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, user.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await SetUserStateAsync(user.Id, active: false);
        var response = await client.DeleteAsync($"/api/products/{productId}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var product = await context.Products.IgnoreQueryFilters().SingleAsync(item => item.Id == productId);
        Assert.False(product.IsDeleted);
    }

    [Fact]
    public async Task Stale_product_owner_cannot_delete_product_image()
    {
        var user = await SeedUserAsync(password: Password);
        var productId = await SeedProductAsync(user.Id);
        var imageId = await SeedProductImageAsync(productId);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, user.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await SetUserStateAsync(user.Id, active: false);
        var response = await client.DeleteAsync($"/api/products/{productId}/images/{imageId}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        Assert.True(await context.ProductImages.AnyAsync(image => image.Id == imageId));
    }

    [Fact]
    public async Task Stale_theft_report_owner_cannot_change_status()
    {
        var user = await SeedUserAsync(password: Password);
        var reportId = await SeedTheftReportAsync(user.Id);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, user.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await SetUserStateAsync(user.Id, active: false);
        var response = await client.PatchAsJsonAsync(
            $"/api/theft-reports/{reportId}/status",
            new UpdateTheftReportStatusRequestDto(TheftReportStatus.Recovered));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var report = await context.TheftReports.SingleAsync(item => item.Id == reportId);
        Assert.Equal(TheftReportStatus.Reported, report.Status);
    }

    [Fact]
    public async Task Stale_user_cannot_create_moderation_report()
    {
        var user = await SeedUserAsync(password: Password);
        var target = await SeedUserAsync();
        var client = factory.CreateClient();
        var session = await LoginAsync(client, user.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await SetUserStateAsync(user.Id, active: false);
        var response = await client.PostAsJsonAsync(
            "/api/reports",
            new CreateModerationReportRequest(ModerationReportTargetType.User, target.Id, "spam", null));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        Assert.Empty(await context.UserReports.Where(report => report.ReporterUserId == user.Id).ToListAsync());
    }

    [Fact]
    public async Task Stale_user_cannot_read_notifications()
    {
        var user = await SeedUserAsync(password: Password);
        await SeedNotificationAsync(user.Id);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, user.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await SetUserStateAsync(user.Id, active: false);
        var response = await client.GetAsync("/api/notifications");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Stale_admin_cannot_list_or_get_users()
    {
        var admin = await SeedUserAsync(password: Password, roles: [AdminSecurity.AdminRole]);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, admin.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await SetUserStateAsync(admin.Id, active: false);
        var list = await client.GetAsync("/api/admin/users");
        var detail = await client.GetAsync($"/api/admin/users/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Forbidden, list.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, detail.StatusCode);
    }

    [Fact]
    public async Task Admin_access_role_revoked_after_token_issued_returns_forbidden()
    {
        var admin = await SeedUserAsync(password: Password, roles: [AdminSecurity.AdminRole]);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, admin.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await RevokeAdminRoleAsync(admin.Id);
        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_users_list_role_revoked_after_token_issued_returns_forbidden()
    {
        var admin = await SeedUserAsync(password: Password, roles: [AdminSecurity.AdminRole]);
        var client = factory.CreateClient();
        var session = await LoginAsync(client, admin.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await RevokeAdminRoleAsync(admin.Id);
        var response = await client.GetAsync("/api/admin/users");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.DoesNotContain(admin.Email, body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Admin_users_detail_role_revoked_after_token_issued_returns_forbidden()
    {
        var admin = await SeedUserAsync(password: Password, roles: [AdminSecurity.AdminRole]);
        var target = await SeedUserAsync();
        var client = factory.CreateClient();
        var session = await LoginAsync(client, admin.Email, Password);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);

        await RevokeAdminRoleAsync(admin.Id);
        var response = await client.GetAsync($"/api/admin/users/{target.Id}");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.DoesNotContain(target.Email, body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Chat_participant_can_read_but_foreign_user_cannot_read_send_or_mark_read()
    {
        var participant = await SeedUserAsync();
        var otherParticipant = await SeedUserAsync();
        var stranger = await SeedUserAsync();
        var conversation = await SeedConversationAsync(participant.Id, otherParticipant.Id);

        var participantClient = CreateAuthenticatedClient(participant.Id);
        var strangerClient = CreateAuthenticatedClient(stranger.Id);
        var read = await participantClient.GetAsync($"/api/conversations/{conversation.ConversationId}/messages");
        var foreignRead = await strangerClient.GetAsync($"/api/conversations/{conversation.ConversationId}/messages");
        var foreignSend = await strangerClient.PostAsJsonAsync(
            $"/api/conversations/{conversation.ConversationId}/messages", new SendMessageRequest("intrusion"));
        var foreignMarkRead = await strangerClient.PatchAsync($"/api/conversations/{conversation.ConversationId}/read", null);

        Assert.Equal(HttpStatusCode.OK, read.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreignRead.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreignSend.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreignMarkRead.StatusCode);
        Assert.DoesNotContain(conversation.MessageId.ToString(), await foreignRead.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Moderation_message_report_requires_participation_and_does_not_expose_private_content()
    {
        var reporter = await SeedUserAsync();
        var otherParticipant = await SeedUserAsync();
        var stranger = await SeedUserAsync();
        var conversation = await SeedConversationAsync(reporter.Id, otherParticipant.Id, "private-content");

        var reporterClient = CreateAuthenticatedClient(reporter.Id);
        var strangerClient = CreateAuthenticatedClient(stranger.Id);
        var request = new CreateModerationReportRequest(
            ModerationReportTargetType.Message, conversation.MessageId, "abuse", "details");

        var created = await reporterClient.PostAsJsonAsync("/api/reports", request);
        var duplicate = await reporterClient.PostAsJsonAsync("/api/reports", request);
        var foreign = await strangerClient.PostAsJsonAsync("/api/reports", request);
        var missing = await reporterClient.PostAsJsonAsync(
            "/api/reports", request with { TargetId = Guid.NewGuid() });
        var body = await created.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.DoesNotContain("private-content", body, StringComparison.Ordinal);
        Assert.DoesNotContain("conversation", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("participants", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("storageKey", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("rowVersion", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Moderation_request_validates_anonymous_invalid_and_inactive_reporters()
    {
        var reporter = await SeedUserAsync();
        var target = await SeedUserAsync();
        var inactive = await SeedUserAsync(active: false);
        var request = new CreateModerationReportRequest(
            ModerationReportTargetType.User, target.Id, "spam", null);

        var anonymous = await factory.CreateClient().PostAsJsonAsync("/api/reports", request);
        var invalid = await CreateAuthenticatedClient(reporter.Id).PostAsJsonAsync(
            "/api/reports", request with { Reason = "" });
        var inactiveResponse = await CreateAuthenticatedClient(inactive.Id).PostAsJsonAsync(
            "/api/reports", request);

        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, inactiveResponse.StatusCode);
    }

    [Fact]
    public async Task Moderation_does_not_report_soft_deleted_user()
    {
        var reporter = await SeedUserAsync();
        var target = await SeedUserAsync(deleted: true);
        var client = CreateAuthenticatedClient(reporter.Id);

        var response = await client.PostAsJsonAsync(
            "/api/reports",
            new CreateModerationReportRequest(ModerationReportTargetType.User, target.Id, "spam", null));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Marketplace_product_delete_is_not_available_to_foreign_user()
    {
        var owner = await SeedUserAsync();
        var foreign = await SeedUserAsync();
        var productId = await SeedProductAsync(owner.Id);

        var response = await CreateAuthenticatedClient(foreign.Id).DeleteAsync($"/api/products/{productId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Product_image_delete_is_not_available_to_foreign_user()
    {
        var owner = await SeedUserAsync();
        var foreign = await SeedUserAsync();
        var productId = await SeedProductAsync(owner.Id);
        var imageId = Guid.NewGuid();
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            context.ProductImages.Add(new ProductImage
            {
                ProductId = productId,
                StorageKey = "private-key",
                Url = "/private-image.jpg",
                DisplayOrder = 0,
                IsPrimary = true
            });
            imageId = context.ProductImages.Local.Single().Id;
            await context.SaveChangesAsync();
        }

        var response = await CreateAuthenticatedClient(foreign.Id)
            .DeleteAsync($"/api/products/{productId}/images/{imageId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Theft_report_status_update_is_not_available_to_foreign_user()
    {
        var owner = await SeedUserAsync();
        var foreign = await SeedUserAsync();
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            var report = new TheftReport
            {
                ReporterUserId = owner.Id,
                Title = "stolen",
                Description = "description",
                Brand = "Honda",
                Model = "CB500",
                Status = TheftReportStatus.Reported,
                TheftDate = DateTimeOffset.UtcNow.AddDays(-1)
            };
            context.TheftReports.Add(report);
            await context.SaveChangesAsync();

            var response = await CreateAuthenticatedClient(foreign.Id).PatchAsJsonAsync(
                $"/api/theft-reports/{report.Id}/status",
                new UpdateTheftReportStatusRequestDto(TheftReportStatus.Recovered));

            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }
    }

    [Fact]
    public async Task Notifications_are_isolated_between_users()
    {
        var owner = await SeedUserAsync();
        var foreign = await SeedUserAsync();
        await using (var scope = factory.Services.CreateAsyncScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            var notification = new Notification
            {
                RecipientUserId = owner.Id,
                Type = NotificationType.System,
                Title = "private title",
                Body = "private body"
            };
            context.Notifications.Add(notification);
            await context.SaveChangesAsync();

            var client = CreateAuthenticatedClient(foreign.Id);
            var list = await client.GetAsync("/api/notifications");
            var markRead = await client.PatchAsync($"/api/notifications/{notification.Id}/read", null);

            Assert.Equal(HttpStatusCode.OK, list.StatusCode);
            Assert.DoesNotContain("private title", await list.Content.ReadAsStringAsync(), StringComparison.Ordinal);
            Assert.Equal(HttpStatusCode.NotFound, markRead.StatusCode);
        }
    }

    [Fact]
    public async Task Configured_cors_policy_allows_only_the_frontend_origin()
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "/health");
        request.Headers.Add("Origin", "http://localhost:3000");
        var response = await factory.CreateClient().SendAsync(request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("http://localhost:3000", response.Headers.GetValues("Access-Control-Allow-Origin").Single());
    }

    [Fact]
    public async Task Auth_rate_limiter_returns_429_after_the_configured_limit()
    {
        await using var isolatedFactory = new RateLimitedApiFactory();
        var client = isolatedFactory.CreateClient();
        var responses = new List<HttpResponseMessage>();
        try
        {
            for (var index = 0; index < 11; index++)
            {
                responses.Add(await client.PostAsJsonAsync(
                    "/api/auth/forgot-password",
                    new ForgotPasswordRequest($"rate-limit-{Guid.NewGuid():N}@example.com")));
            }

            Assert.All(responses.Take(10), response => Assert.NotEqual(HttpStatusCode.TooManyRequests, response.StatusCode));
            Assert.Equal(HttpStatusCode.TooManyRequests, responses[10].StatusCode);
        }
        finally
        {
            foreach (var response in responses)
            {
                response.Dispose();
            }
        }
    }

    private HttpClient CreateAuthenticatedClient(Guid userId, params string[] roles)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", CreateToken(userId, "valid", roles));
        return client;
    }

    private async Task<AuthResponse> LoginAsync(HttpClient client, string email, string password)
    {
        var response = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(email, password));
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    private async Task RevokeAdminRoleAsync(Guid userId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<MotoHubIdentityUser>>();
        var identityUser = await userManager.FindByIdAsync(userId.ToString());
        Assert.NotNull(identityUser);
        var result = await userManager.RemoveFromRoleAsync(identityUser, AdminSecurity.AdminRole);
        Assert.True(result.Succeeded, string.Join("; ", result.Errors.Select(error => error.Description)));
    }

    private sealed class RateLimitedApiFactory : ApiFactory
    {
        protected override int AuthPermitLimit => 10;
    }

    private async Task<ApiUserSeed> SeedUserAsync(
        bool active = true,
        bool deleted = false,
        string? password = null,
        params string[] roles)
    {
        var id = Guid.NewGuid();
        var userName = $"api-security-{id:N}";
        var email = $"{userName}@example.com";
        await using var scope = factory.Services.CreateAsyncScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<MotoHubIdentityUser>>();
        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<MotoHubIdentityRole>>();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var identityUser = new MotoHubIdentityUser
        {
            Id = id,
            UserName = userName,
            Email = email,
            EmailConfirmed = true,
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString()
        };
        var result = password is null
            ? await userManager.CreateAsync(identityUser)
            : await userManager.CreateAsync(identityUser, password);
        Assert.True(result.Succeeded, string.Join("; ", result.Errors.Select(error => error.Description)));
        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                var createRoleResult = await roleManager.CreateAsync(new MotoHubIdentityRole { Name = role });
                Assert.True(createRoleResult.Succeeded);
            }

            var roleResult = await userManager.AddToRoleAsync(identityUser, role);
            Assert.True(roleResult.Succeeded);
        }

        context.Users.Add(new User(id)
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            IsActive = active,
            IsDeleted = deleted,
            EmailConfirmed = true
        });
        await context.SaveChangesAsync();
        return new ApiUserSeed(id, email);
    }

    private async Task SetUserStateAsync(Guid userId, bool active, bool deleted = false)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var user = await context.Users.IgnoreQueryFilters().SingleAsync(item => item.Id == userId);
        user.IsActive = active;
        user.IsDeleted = deleted;
        await context.SaveChangesAsync();
    }

    private async Task<int> CountMessagesAsync(Guid conversationId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        return await context.Messages.CountAsync(message => message.ConversationId == conversationId);
    }

    private async Task<Guid> SeedProductImageAsync(Guid productId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var image = new ProductImage
        {
            ProductId = productId,
            StorageKey = "stale-user-image",
            Url = "/stale-user-image.jpg",
            DisplayOrder = 0,
            IsPrimary = true
        };
        context.ProductImages.Add(image);
        await context.SaveChangesAsync();
        return image.Id;
    }

    private async Task<Guid> SeedTheftReportAsync(Guid reporterUserId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var report = new TheftReport
        {
            ReporterUserId = reporterUserId,
            Title = "stale-user theft report",
            Description = "description",
            Brand = "Honda",
            Model = "CB500",
            LicensePlate = "STALE-1",
            Status = TheftReportStatus.Reported,
            TheftDate = DateTimeOffset.UtcNow.AddDays(-1)
        };
        context.TheftReports.Add(report);
        await context.SaveChangesAsync();
        return report.Id;
    }

    private async Task SeedNotificationAsync(Guid recipientUserId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        context.Notifications.Add(new Notification
        {
            RecipientUserId = recipientUserId,
            Type = NotificationType.System,
            Title = "stale-user notification",
            Body = "private body"
        });
        await context.SaveChangesAsync();
    }

    private async Task<(Guid ConversationId, Guid MessageId)> SeedConversationAsync(
        Guid participantId,
        Guid otherParticipantId,
        string content = "private message")
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var conversation = new Conversation { Type = ConversationType.Direct };
        var conversationId = conversation.Id;
        conversation.Participants.Add(new ConversationParticipant
        {
            ConversationId = conversationId,
            UserId = participantId,
            JoinedAt = DateTimeOffset.UtcNow
        });
        conversation.Participants.Add(new ConversationParticipant
        {
            ConversationId = conversationId,
            UserId = otherParticipantId,
            JoinedAt = DateTimeOffset.UtcNow
        });
        context.Conversations.Add(conversation);
        var message = new Message
        {
            ConversationId = conversationId,
            SenderUserId = otherParticipantId,
            Content = content,
            MessageType = MessageType.Text,
            SentAt = DateTimeOffset.UtcNow
        };
        context.Messages.Add(message);
        await context.SaveChangesAsync();
        return (conversation.Id, message.Id);
    }

    private async Task<Guid> SeedProductAsync(Guid ownerId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var category = new ProductCategory
        {
            Name = "Parts",
            Slug = $"parts-{Guid.NewGuid():N}",
            IsActive = true
        };
        context.ProductCategories.Add(category);
        var product = new Product
        {
            SellerUserId = ownerId,
            CategoryId = category.Id,
            Name = "Private part",
            Description = "Private description",
            Status = ProductStatus.Active,
            Condition = ProductCondition.Used
        };
        context.Products.Add(product);
        await context.SaveChangesAsync();
        return product.Id;
    }

    private string CreateToken(Guid userId, string tokenKind, params string[] roles)
    {
        if (tokenKind == "malformed") return "not-a-jwt";
        var options = new JwtOptions
        {
            Issuer = tokenKind == "invalid-issuer" ? "wrong-issuer" : ApiFactory.Issuer,
            Audience = tokenKind == "invalid-audience" ? "wrong-audience" : ApiFactory.Audience,
            SigningKey = tokenKind == "invalid-signature"
                ? "98765432109876543210987654321098"
                : ApiFactory.SigningKey,
            AccessTokenMinutes = tokenKind == "expired" ? -10 : 10
        };
        var service = new JwtTokenService(Options.Create(options));
        return service.Create(
            new MotoHubIdentityUser
            {
                Id = userId,
                UserName = "api-security-user",
                Email = "api-security@example.com"
            },
            roles.Length == 0 ? ["User"] : roles).Token;
    }

    private sealed record ApiUserSeed(Guid Id, string Email);
}
