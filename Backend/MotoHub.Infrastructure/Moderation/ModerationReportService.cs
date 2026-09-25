using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application;
using MotoHub.Application.Errors;
using MotoHub.Application.Moderation;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Moderation;

public sealed class ModerationReportService(MotoHubDbContext dbContext) : IModerationReportService
{
    private const int MaxDescriptionLength = 5000;

    public async Task<ModerationReportResponse> CreateAsync(
        Guid reporterUserId,
        CreateModerationReportRequest request,
        CancellationToken cancellationToken)
    {
        var reporter = await dbContext.Users
            .IgnoreQueryFilters()
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == reporterUserId, cancellationToken);
        if (reporter is not { IsActive: true, IsDeleted: false })
        {
            throw new AuthenticationException("El usuario autenticado ya no está operativo.", 403);
        }

        if (request.TargetId == Guid.Empty)
        {
            throw new ValidationException("TargetId debe ser un identificador válido.");
        }

        var reason = request.Reason?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(reason) || reason.Length > 100)
        {
            throw new ValidationException("Reason es obligatorio y debe tener como máximo 100 caracteres.");
        }

        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        if (description?.Length > MaxDescriptionLength)
        {
            throw new ValidationException($"Description no puede superar {MaxDescriptionLength} caracteres.");
        }

        ModerationReport report;
        switch (request.TargetType)
        {
            case ModerationReportTargetType.User:
                report = await CreateUserReportAsync(reporterUserId, request.TargetId, reason, description, cancellationToken);
                break;
            case ModerationReportTargetType.Post:
                report = await CreatePostReportAsync(reporterUserId, request.TargetId, reason, description, cancellationToken);
                break;
            case ModerationReportTargetType.PostComment:
                report = await CreateCommentReportAsync(reporterUserId, request.TargetId, reason, description, cancellationToken);
                break;
            case ModerationReportTargetType.Product:
                report = await CreateProductReportAsync(reporterUserId, request.TargetId, reason, description, cancellationToken);
                break;
            case ModerationReportTargetType.Message:
                report = await CreateMessageReportAsync(reporterUserId, request.TargetId, reason, description, cancellationToken);
                break;
            default:
                throw new ValidationException("TargetType no es válido.");
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return new ModerationReportResponse(report.Id, request.TargetType, request.TargetId, report.Reason, report.Description, report.Status, report.CreatedAt);
    }

    private async Task<UserReport> CreateUserReportAsync(Guid reporterUserId, Guid targetId, string reason, string? description, CancellationToken cancellationToken)
    {
        if (reporterUserId == targetId) throw new ValidationException("No puedes reportarte a ti mismo.");
        if (!await dbContext.Users.AnyAsync(x => x.Id == targetId, cancellationToken)) throw new ResourceNotFoundException("El usuario reportado no existe.");
        await EnsureNoActiveDuplicateAsync(dbContext.UserReports, reporterUserId, x => x.ReportedUserId == targetId, cancellationToken);
        var report = new UserReport { ReporterUserId = reporterUserId, ReportedUserId = targetId, Reason = reason, Description = description, Status = ModerationReportStatus.Pending };
        dbContext.UserReports.Add(report);
        return report;
    }

    private async Task<PostReport> CreatePostReportAsync(Guid reporterUserId, Guid targetId, string reason, string? description, CancellationToken cancellationToken)
    {
        if (!await dbContext.Posts.AnyAsync(x => x.Id == targetId && x.Status == PostStatus.Published, cancellationToken)) throw new ResourceNotFoundException("La publicación no existe.");
        await EnsureNoActiveDuplicateAsync(dbContext.PostReports, reporterUserId, x => x.PostId == targetId, cancellationToken);
        var report = new PostReport { ReporterUserId = reporterUserId, PostId = targetId, Reason = reason, Description = description, Status = ModerationReportStatus.Pending };
        dbContext.PostReports.Add(report);
        return report;
    }

    private async Task<CommentReport> CreateCommentReportAsync(Guid reporterUserId, Guid targetId, string reason, string? description, CancellationToken cancellationToken)
    {
        if (!await dbContext.PostComments.AnyAsync(x => x.Id == targetId && x.Post.Status == PostStatus.Published, cancellationToken)) throw new ResourceNotFoundException("El comentario no existe.");
        await EnsureNoActiveDuplicateAsync(dbContext.CommentReports, reporterUserId, x => x.PostCommentId == targetId, cancellationToken);
        var report = new CommentReport { ReporterUserId = reporterUserId, PostCommentId = targetId, Reason = reason, Description = description, Status = ModerationReportStatus.Pending };
        dbContext.CommentReports.Add(report);
        return report;
    }

    private async Task<ProductReport> CreateProductReportAsync(Guid reporterUserId, Guid targetId, string reason, string? description, CancellationToken cancellationToken)
    {
        if (!await dbContext.Products.AnyAsync(x => x.Id == targetId && x.Status == ProductStatus.Active && x.Category.IsActive, cancellationToken)) throw new ResourceNotFoundException("El producto no existe.");
        await EnsureNoActiveDuplicateAsync(dbContext.ProductReports, reporterUserId, x => x.ProductId == targetId, cancellationToken);
        var report = new ProductReport { ReporterUserId = reporterUserId, ProductId = targetId, Reason = reason, Description = description, Status = ModerationReportStatus.Pending };
        dbContext.ProductReports.Add(report);
        return report;
    }

    private async Task<MessageReport> CreateMessageReportAsync(Guid reporterUserId, Guid targetId, string reason, string? description, CancellationToken cancellationToken)
    {
        var canAccess = await dbContext.Messages.AnyAsync(
            x => x.Id == targetId && x.Conversation.Type == ConversationType.Direct &&
                 x.Conversation.Participants.Any(participant => participant.UserId == reporterUserId && participant.LeftAt == null),
            cancellationToken);
        if (!canAccess) throw new ResourceNotFoundException("El mensaje no existe.");
        await EnsureNoActiveDuplicateAsync(dbContext.MessageReports, reporterUserId, x => x.MessageId == targetId, cancellationToken);
        var report = new MessageReport { ReporterUserId = reporterUserId, MessageId = targetId, Reason = reason, Description = description, Status = ModerationReportStatus.Pending };
        dbContext.MessageReports.Add(report);
        return report;
    }

    private static async Task EnsureNoActiveDuplicateAsync<TReport>(
        IQueryable<TReport> reports,
        Guid reporterUserId,
        Expression<Func<TReport, bool>> targetPredicate,
        CancellationToken cancellationToken)
        where TReport : ModerationReport
    {
        var exists = await reports
            .Where(x => x.ReporterUserId == reporterUserId && (x.Status == ModerationReportStatus.Pending || x.Status == ModerationReportStatus.Reviewing))
            .Where(targetPredicate)
            .AnyAsync(cancellationToken);
        if (exists) throw new ConflictException("Ya existe un reporte activo para este objetivo.");
    }
}