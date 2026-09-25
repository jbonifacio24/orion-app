namespace MotoHub.Application.Admin;

public sealed record AdminPagedResponse<T>(
    IReadOnlyCollection<T> Items,
    int Page,
    int PageSize,
    int TotalCount,
    int TotalPages);

public sealed record AdminUserListQuery(
    string? Search = null,
    bool? IsActive = null,
    bool? EmailConfirmed = null,
    string? Role = null,
    bool IncludeDeleted = false,
    int Page = 1,
    int PageSize = 20);

public sealed record AdminUserStatusRequest(
    bool IsActive,
    string? ConcurrencyToken);

public sealed record AdminUserStatusResponse(
    Guid UserId,
    bool IsActive,
    string ConcurrencyToken);

public sealed record AdminSessionRevocationResponse(
    Guid UserId,
    int RevokedCount);

public sealed record AdminUserRolesRequest(
    IReadOnlyCollection<string>? Roles,
    string? ConcurrencyToken);

public sealed record AdminUserRolesResponse(
    Guid UserId,
    IReadOnlyCollection<string> Roles,
    string ConcurrencyToken);

public sealed record AdminUserListItemDto(
    Guid Id,
    string UserName,
    string Email,
    bool EmailConfirmed,
    bool IsActive,
    bool IsDeleted,
    bool ProfileMissing,
    IReadOnlyCollection<string> Roles,
    DateTimeOffset? LastLoginAt,
    DateTimeOffset? CreatedAt,
    DateTimeOffset? UpdatedAt,
    string? ConcurrencyToken);

public sealed record AdminUserDetailDto(
    Guid Id,
    string UserName,
    string Email,
    bool EmailConfirmed,
    bool IsActive,
    bool IsDeleted,
    bool ProfileMissing,
    IReadOnlyCollection<string> Roles,
    string? FirstName,
    string? LastName,
    string? PhoneNumber,
    string? Bio,
    string? ProfileImageUrl,
    DateTimeOffset? LastLoginAt,
    DateTimeOffset? CreatedAt,
    DateTimeOffset? UpdatedAt,
    DateTimeOffset? LockoutEnd,
    string? ConcurrencyToken);

public interface IAdminUserService
{
    Task<AdminPagedResponse<AdminUserListItemDto>> ListAsync(AdminUserListQuery query, CancellationToken cancellationToken);
    Task<AdminUserDetailDto> GetAsync(Guid userId, CancellationToken cancellationToken);
    Task<AdminUserStatusResponse> UpdateStatusAsync(
        Guid actorUserId,
        Guid userId,
        AdminUserStatusRequest request,
        string? ipAddress,
        CancellationToken cancellationToken);
    Task<AdminSessionRevocationResponse> RevokeSessionsAsync(
        Guid actorUserId,
        Guid userId,
        string? ipAddress,
        CancellationToken cancellationToken);
    Task<AdminUserRolesResponse> ReplaceRolesAsync(
        Guid actorUserId,
        Guid userId,
        AdminUserRolesRequest request,
        string? ipAddress,
        CancellationToken cancellationToken);
}
