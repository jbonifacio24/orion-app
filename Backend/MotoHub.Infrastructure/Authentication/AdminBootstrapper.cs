using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MotoHub.Application;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Authentication;

public sealed class AdminBootstrapper(
    MotoHubDbContext dbContext,
    UserManager<MotoHubIdentityUser> userManager,
    RoleManager<MotoHubIdentityRole> roleManager,
    IOptions<AdminBootstrapOptions> options,
    IAuditService auditService,
    ILogger<AdminBootstrapper> logger)
{
    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var role = await roleManager.FindByNameAsync(AdminSecurity.AdminRole);
        if (role is null)
        {
            role = new MotoHubIdentityRole { Name = AdminSecurity.AdminRole };
            EnsureSuccess(await roleManager.CreateAsync(role));
            await auditService.WriteAsync(
                new AuditEntry(
                    "AdminRoleCreated",
                    nameof(MotoHubIdentityRole),
                    role.Id,
                    NewValuesJson: JsonSerializer.Serialize(new { role = AdminSecurity.AdminRole })),
                cancellationToken);
        }

        var configuredEmail = options.Value.UserEmail?.Trim();
        if (string.IsNullOrWhiteSpace(configuredEmail))
        {
            await transaction.CommitAsync(cancellationToken);
            return;
        }

        var user = await userManager.FindByEmailAsync(configuredEmail);
        if (user is null)
        {
            logger.LogWarning("Admin bootstrap user was not found; no account was created or elevated.");
            await transaction.CommitAsync(cancellationToken);
            return;
        }

        if (!await userManager.IsInRoleAsync(user, AdminSecurity.AdminRole))
        {
            EnsureSuccess(await userManager.AddToRoleAsync(user, AdminSecurity.AdminRole));
            await auditService.WriteAsync(
                new AuditEntry(
                    "AdminRoleAssigned",
                    nameof(MotoHubIdentityUser),
                    user.Id,
                    NewValuesJson: JsonSerializer.Serialize(new { role = AdminSecurity.AdminRole })),
                cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
    }

    private static void EnsureSuccess(IdentityResult result)
    {
        if (!result.Succeeded)
        {
            throw new InvalidOperationException(string.Join("; ", result.Errors.Select(error => error.Description)));
        }
    }
}