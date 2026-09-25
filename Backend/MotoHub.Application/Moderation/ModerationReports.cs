using MotoHub.Domain;

namespace MotoHub.Application.Moderation;

public enum ModerationReportTargetType
{
    User,
    Post,
    PostComment,
    Product,
    Message
}

public sealed record CreateModerationReportRequest(
    ModerationReportTargetType TargetType,
    Guid TargetId,
    string? Reason,
    string? Description);

public sealed record ModerationReportResponse(
    Guid Id,
    ModerationReportTargetType TargetType,
    Guid TargetId,
    string Reason,
    string? Description,
    ModerationReportStatus Status,
    DateTimeOffset CreatedAt);

public interface IModerationReportService
{
    Task<ModerationReportResponse> CreateAsync(
        Guid reporterUserId,
        CreateModerationReportRequest request,
        CancellationToken cancellationToken);
}