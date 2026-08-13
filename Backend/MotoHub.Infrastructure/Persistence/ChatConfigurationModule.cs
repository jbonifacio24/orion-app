using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class ChatConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<Conversation>(e => { EntityConfigurationHelper.ConfigureEntity(e, "Conversations"); e.Property(x => x.Type).HasConversion<string>().HasMaxLength(40).IsRequired(); e.HasIndex(x => x.LastMessageAt); e.HasQueryFilter(x => !x.IsDeleted); });
        builder.Entity<ConversationParticipant>(e => { e.HasKey(x => new { x.ConversationId, x.UserId }); e.ToTable("ConversationParticipants"); e.HasIndex(x => new { x.UserId, x.LeftAt }); e.HasOne(x => x.Conversation).WithMany(x => x.Participants).HasForeignKey(x => x.ConversationId).OnDelete(DeleteBehavior.Cascade); e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict); });
        builder.Entity<Message>(e => { EntityConfigurationHelper.ConfigureEntity(e, "Messages"); e.Property(x => x.Content).HasMaxLength(10000).IsRequired(); e.Property(x => x.MessageType).HasConversion<string>().HasMaxLength(40).IsRequired(); e.HasIndex(x => new { x.ConversationId, x.SentAt }); e.HasOne(x => x.Conversation).WithMany(x => x.Messages).HasForeignKey(x => x.ConversationId).OnDelete(DeleteBehavior.Cascade); e.HasOne(x => x.Sender).WithMany().HasForeignKey(x => x.SenderUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.ReplyToMessage).WithMany().HasForeignKey(x => x.ReplyToMessageId).OnDelete(DeleteBehavior.NoAction); e.HasQueryFilter(x => !x.IsDeleted); });
        builder.Entity<MessageAttachment>(e => { EntityConfigurationHelper.ConfigureEntity(e, "MessageAttachments", false); e.Property(x => x.StorageKey).HasMaxLength(500).IsRequired(); e.Property(x => x.FileName).HasMaxLength(255).IsRequired(); e.Property(x => x.ContentType).HasMaxLength(150).IsRequired(); e.HasIndex(x => x.MessageId); e.HasOne(x => x.Message).WithMany(x => x.Attachments).HasForeignKey(x => x.MessageId).OnDelete(DeleteBehavior.Cascade); });
    }
}