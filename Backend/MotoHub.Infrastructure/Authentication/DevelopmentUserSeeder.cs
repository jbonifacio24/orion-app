using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Authentication;

public sealed class DevelopmentUserSeeder(
    MotoHubDbContext dbContext,
    UserManager<MotoHubIdentityUser> userManager,
    RoleManager<MotoHubIdentityRole> roleManager,
    IOptions<AuthOptions> authOptions)
{
    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var options = authOptions.Value;
        AdminSecurity.EnsureAutomaticRoleIsNotAdmin(options.DefaultRole);
        var identityUser = await userManager.FindByEmailAsync(options.DevelopmentUserEmail);

        if (identityUser is null)
        {
            identityUser = new MotoHubIdentityUser
            {
                Id = Guid.NewGuid(),
                UserName = options.DevelopmentUserName,
                Email = options.DevelopmentUserEmail,
                EmailConfirmed = true
            };

            var result = await userManager.CreateAsync(identityUser, options.DevelopmentUserPassword);
            EnsureSuccess(result);
        }
        else if (!identityUser.EmailConfirmed)
        {
            identityUser.EmailConfirmed = true;
            EnsureSuccess(await userManager.UpdateAsync(identityUser));
        }

        if (!await roleManager.RoleExistsAsync(options.DefaultRole))
        {
            EnsureSuccess(await roleManager.CreateAsync(new MotoHubIdentityRole { Name = options.DefaultRole }));
        }

        if (!await userManager.IsInRoleAsync(identityUser, options.DefaultRole))
        {
            EnsureSuccess(await userManager.AddToRoleAsync(identityUser, options.DefaultRole));
        }

        var domainUser = await dbContext.Users.IgnoreQueryFilters().SingleOrDefaultAsync(user => user.Id == identityUser.Id, cancellationToken);
        if (domainUser is null)
        {
            dbContext.Users.Add(new User(identityUser.Id)
            {
                UserName = identityUser.UserName ?? options.DevelopmentUserName,
                NormalizedUserName = userManager.NormalizeName(identityUser.UserName)!,
                Email = identityUser.Email ?? options.DevelopmentUserEmail,
                NormalizedEmail = userManager.NormalizeEmail(identityUser.Email)!,
                FirstName = "Usuario",
                LastName = "Demo",
                EmailConfirmed = true
            });
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private static void EnsureSuccess(IdentityResult result)
    {
        if (!result.Succeeded)
        {
            throw new InvalidOperationException(string.Join("; ", result.Errors.Select(error => error.Description)));
        }
    }
}