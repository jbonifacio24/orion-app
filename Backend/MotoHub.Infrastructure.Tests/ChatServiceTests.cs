using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Chat;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Chat;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class ChatServiceTests
{
    [Fact]
    public async Task Get_conversations_returns_only_active_direct_memberships_and_private_data_is_not_exposed()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current", "Current", "User", "current@example.com");
        var other = AddUser(context, "other", "Other", "User", "private@example.com", "/other.png");
        var left = AddUser(context, "left", "Left", "User", "left@example.com");
        var active = AddConversation(context, current, other);
        AddConversation(context, current, left, leftAtForCurrent: DateTimeOffset.UtcNow);
        await context.SaveChangesAsync();

        var response = await Service(context).GetConversationsAsync(current.Id, default);

        var item = Assert.Single(response);
        Assert.Equal(active.Id, item.Id);
        Assert.Equal(other.Id, item.Participant.UserId);
        Assert.Equal("Other User", item.Participant.DisplayName);
        Assert.Equal("/other.png", item.Participant.ProfileImageUrl);
    }

    [Fact]
    public async Task Get_or_create_direct_creates_then_reuses_existing_conversation()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var recipient = AddUser(context, "recipient");
        await context.SaveChangesAsync();
        var service = Service(context);

        var first = await service.GetOrCreateDirectAsync(current.Id, new(recipient.Id), default);
        var second = await service.GetOrCreateDirectAsync(current.Id, new(recipient.Id), default);

        Assert.Equal(first.Id, second.Id);
        Assert.Equal(1, await context.Conversations.CountAsync());
        Assert.Equal(2, await context.ConversationParticipants.CountAsync());
    }

    [Fact]
    public async Task Get_or_create_direct_rejects_self_and_unknown_recipient()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.GetOrCreateDirectAsync(current.Id, new(current.Id), default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetOrCreateDirectAsync(current.Id, new(Guid.NewGuid()), default));
    }

    [Fact]
    public async Task Get_messages_allows_active_participant_with_deterministic_paging()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var other = AddUser(context, "other");
        var conversation = AddConversation(context, current, other);
        var baseTime = DateTimeOffset.UtcNow.AddMinutes(-3);
        AddMessage(context, conversation, other, "one", baseTime);
        AddMessage(context, conversation, other, "two", baseTime.AddMinutes(1));
        AddMessage(context, conversation, current, "three", baseTime.AddMinutes(2));
        await context.SaveChangesAsync();

        var response = await Service(context).GetMessagesAsync(current.Id, conversation.Id, new(Page: 1, PageSize: 2), default);

        Assert.Equal(3, response.TotalCount);
        Assert.Equal(2, response.TotalPages);
        Assert.Equal(new[] { "three", "two" }, response.Items.Select(x => x.Content).ToArray());
        Assert.All(response.Items, item => Assert.Equal(MessageType.Text, item.MessageType));
    }

    [Fact]
    public async Task Get_messages_rejects_non_participant()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var other = AddUser(context, "other");
        var stranger = AddUser(context, "stranger");
        var conversation = AddConversation(context, current, other);
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => Service(context).GetMessagesAsync(stranger.Id, conversation.Id, new(), default));
    }

    [Fact]
    public async Task Send_message_persists_text_with_authenticated_sender_and_updates_last_message()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current", "Current", "User");
        var other = AddUser(context, "other");
        var conversation = AddConversation(context, current, other);
        await context.SaveChangesAsync();

        var response = await Service(context).SendMessageAsync(current.Id, conversation.Id, new("  hello  "), default);
        var stored = await context.Messages.SingleAsync();
        var savedConversation = await context.Conversations.SingleAsync();

        Assert.Equal("hello", response.Content);
        Assert.Equal("hello", stored.Content);
        Assert.Equal(current.Id, response.SenderUserId);
        Assert.Equal(current.Id, stored.SenderUserId);
        Assert.Equal(MessageType.Text, stored.MessageType);
        Assert.Equal(stored.SentAt, savedConversation.LastMessageAt);
    }

    [Fact]
    public async Task Send_message_rejects_non_participant_and_invalid_content()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var other = AddUser(context, "other");
        var stranger = AddUser(context, "stranger");
        var conversation = AddConversation(context, current, other);
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.SendMessageAsync(stranger.Id, conversation.Id, new("valid"), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.SendMessageAsync(current.Id, conversation.Id, new("   "), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.SendMessageAsync(current.Id, conversation.Id, new(new string('x', 10001)), default));
        Assert.Empty(await context.Messages.ToListAsync());
    }

    [Fact]
    public async Task Mark_read_updates_active_participant_and_is_idempotent()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var other = AddUser(context, "other");
        var conversation = AddConversation(context, current, other);
        await context.SaveChangesAsync();
        var service = Service(context);

        await service.MarkReadAsync(current.Id, conversation.Id, default);
        var firstReadAt = await context.ConversationParticipants
            .Where(x => x.ConversationId == conversation.Id && x.UserId == current.Id)
            .Select(x => x.LastReadAt)
            .SingleAsync();
        await service.MarkReadAsync(current.Id, conversation.Id, default);
        var secondReadAt = await context.ConversationParticipants
            .Where(x => x.ConversationId == conversation.Id && x.UserId == current.Id)
            .Select(x => x.LastReadAt)
            .SingleAsync();

        Assert.NotNull(firstReadAt);
        Assert.NotNull(secondReadAt);
    }

    [Fact]
    public async Task Mark_read_rejects_non_participant()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var other = AddUser(context, "other");
        var stranger = AddUser(context, "stranger");
        var conversation = AddConversation(context, current, other);
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => Service(context).MarkReadAsync(stranger.Id, conversation.Id, default));
    }

    [Fact]
    public async Task Get_conversations_counts_only_received_messages_after_last_read()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current");
        var other = AddUser(context, "other");
        var conversation = AddConversation(context, current, other);
        var joinedAt = conversation.Participants.Single(x => x.UserId == current.Id).JoinedAt;
        var lastReadAt = joinedAt.AddMinutes(2);
        conversation.Participants.Single(x => x.UserId == current.Id).LastReadAt = lastReadAt;
        AddMessage(context, conversation, other, "old", joinedAt.AddMinutes(1));
        AddMessage(context, conversation, other, "new", lastReadAt.AddMinutes(1));
        AddMessage(context, conversation, current, "own", lastReadAt.AddMinutes(2));
        await context.SaveChangesAsync();

        var response = await Service(context).GetConversationsAsync(current.Id, default);

        Assert.Equal(1, Assert.Single(response).UnreadCount);
    }

    private static ChatService Service(MotoHubDbContext context) => new(context);

    private static User AddUser(MotoHubDbContext context, string userName, string? firstName = null, string? lastName = null, string? email = null, string? image = null)
    {
        var user = new User
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email ?? $"{userName}@example.com",
            NormalizedEmail = (email ?? $"{userName}@example.com").ToUpperInvariant(),
            FirstName = firstName,
            LastName = lastName,
            ProfileImageUrl = image
        };
        context.Users.Add(user);
        return user;
    }

    private static Conversation AddConversation(MotoHubDbContext context, User current, User other, DateTimeOffset? leftAtForCurrent = null)
    {
        var conversation = new Conversation { Type = ConversationType.Direct };
        conversation.Participants.Add(new ConversationParticipant
        {
            ConversationId = conversation.Id,
            UserId = current.Id,
            JoinedAt = DateTimeOffset.UtcNow.AddMinutes(-5),
            LeftAt = leftAtForCurrent,
            User = current
        });
        conversation.Participants.Add(new ConversationParticipant
        {
            ConversationId = conversation.Id,
            UserId = other.Id,
            JoinedAt = DateTimeOffset.UtcNow.AddMinutes(-5),
            User = other
        });
        context.Conversations.Add(conversation);
        return conversation;
    }

    private static Message AddMessage(MotoHubDbContext context, Conversation conversation, User sender, string content, DateTimeOffset sentAt)
    {
        var message = new Message
        {
            ConversationId = conversation.Id,
            SenderUserId = sender.Id,
            Sender = sender,
            Content = content,
            MessageType = MessageType.Text,
            SentAt = sentAt
        };
        context.Messages.Add(message);
        return message;
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}
