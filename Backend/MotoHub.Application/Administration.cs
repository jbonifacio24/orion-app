namespace MotoHub.Application;

public static class AdminSecurity
{
    public const string AdminRole = "Admin";
    public const string AdminAccessPolicy = "AdminAccess";

    public static void EnsureAutomaticRoleIsNotAdmin(string role)
    {
        if (string.Equals(role, AdminRole, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("The automatic authentication role cannot be Admin.");
        }
    }
}

public sealed record AuditEntry(
    string Action,
    string EntityType,
    Guid EntityId,
    string? OldValuesJson = null,
    string? NewValuesJson = null);

public interface IAuditService
{
    Task WriteAsync(AuditEntry entry, CancellationToken cancellationToken);
}