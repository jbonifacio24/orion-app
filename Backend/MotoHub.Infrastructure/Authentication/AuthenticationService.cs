using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Authentication;

public sealed class AuthenticationService(
    MotoHubDbContext dbContext,
    UserManager<MotoHubIdentityUser> userManager,
    RoleManager<MotoHubIdentityRole> roleManager,
    SignInManager<MotoHubIdentityUser> signInManager,
    JwtTokenService jwtTokenService,
    IEmailSender emailSender,
    IOptions<JwtOptions> jwtOptions,
    IOptions<AuthOptions> authOptions,
    ISessionRevocationService sessionRevocationService) : IAuthenticationService
{
    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, string? ipAddress, CancellationToken cancellationToken)
    {
        ValidatePassword(request.Password, request.ConfirmPassword);
        if (!string.Equals(request.Email, request.Email.Trim(), StringComparison.Ordinal) || string.IsNullOrWhiteSpace(request.Email))
        {
            throw new AuthenticationException("Email is invalid.");
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var identityUser = new MotoHubIdentityUser
        {
            Id = Guid.NewGuid(),
            UserName = request.UserName.Trim(),
            Email = request.Email.Trim()
        };
        var result = await userManager.CreateAsync(identityUser, request.Password);
        EnsureSuccess(result, 409);

        var domainUser = new User(identityUser.Id)
        {
            UserName = identityUser.UserName!,
            NormalizedUserName = userManager.NormalizeName(identityUser.UserName)!,
            Email = identityUser.Email!,
            NormalizedEmail = userManager.NormalizeEmail(identityUser.Email)!,
            FirstName = request.FirstName,
            LastName = request.LastName,
            EmailConfirmed = false
        };
        dbContext.Users.Add(domainUser);
        await dbContext.SaveChangesAsync(cancellationToken);
        await EnsureRoleAsync(authOptions.Value.DefaultRole, cancellationToken);
        EnsureSuccess(await userManager.AddToRoleAsync(identityUser, authOptions.Value.DefaultRole));

        var confirmationToken = await userManager.GenerateEmailConfirmationTokenAsync(identityUser);
        await emailSender.SendAsync(identityUser.Email!, "Confirm your MotoHub email", confirmationToken, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return await IssueSessionAsync(identityUser, ipAddress, cancellationToken);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, string? ipAddress, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByEmailAsync(request.EmailOrUserName)
            ?? await userManager.FindByNameAsync(request.EmailOrUserName);
        if (user is null || !(await signInManager.CheckPasswordSignInAsync(user, request.Password, true)).Succeeded)
        {
            throw new AuthenticationException("Invalid credentials.", 401);
        }
        if (!await IsActiveAsync(user.Id, cancellationToken))
        {
            await sessionRevocationService.RevokeAllAsync(user.Id, "Inactive user", ipAddress, cancellationToken);
            throw new AuthenticationException("Invalid credentials.", 401);
        }
        if (authOptions.Value.RequireConfirmedEmail && !await userManager.IsEmailConfirmedAsync(user))
        {
            throw new AuthenticationException("Email confirmation is required.", 403);
        }
        return await IssueSessionAsync(user, ipAddress, cancellationToken);
    }

    public async Task<AuthResponse> RefreshAsync(RefreshTokenRequest request, string? ipAddress, CancellationToken cancellationToken)
    {
        var hash = JwtTokenService.HashRefreshToken(request.RefreshToken);
        var stored = await dbContext.RefreshTokens.SingleOrDefaultAsync(x => x.TokenHash == hash, cancellationToken)
            ?? throw new AuthenticationException("Invalid refresh token.", 401);
        if (stored.RevokedAt is not null)
        {
            await RevokeAllAsync(stored.UserId, "Refresh token reuse detected", cancellationToken);
            throw new AuthenticationException("Refresh token is expired or revoked.", 401);
        }
        if (stored.ExpiresAt <= DateTimeOffset.UtcNow)
        {
            throw new AuthenticationException("Refresh token is expired or revoked.", 401);
        }

        var user = await userManager.FindByIdAsync(stored.UserId.ToString())
            ?? throw new AuthenticationException("User is not available.", 401);
        if (!await IsActiveAsync(user.Id, cancellationToken))
        {
            await sessionRevocationService.RevokeAllAsync(user.Id, "Inactive user", ipAddress, cancellationToken);
            throw new AuthenticationException("Invalid refresh token.", 401);
        }
        stored.RevokedAt = DateTimeOffset.UtcNow;
        stored.RevokedByIp = ipAddress;
        stored.RevocationReason = "Rotated";
        await dbContext.SaveChangesAsync(cancellationToken);
        return await IssueSessionAsync(user, ipAddress, cancellationToken, stored);
    }

    public async Task LogoutAsync(LogoutRequest request, string? ipAddress, CancellationToken cancellationToken)
    {
        var hash = JwtTokenService.HashRefreshToken(request.RefreshToken);
        var stored = await dbContext.RefreshTokens.SingleOrDefaultAsync(x => x.TokenHash == hash, cancellationToken);
        if (stored is null) return;
        stored.RevokedAt ??= DateTimeOffset.UtcNow;
        stored.RevokedByIp = ipAddress;
        stored.RevocationReason = "Logout";
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByEmailAsync(request.Email);
        if (user is null || string.IsNullOrWhiteSpace(user.Email)) return;
        var token = await userManager.GeneratePasswordResetTokenAsync(user);
        await emailSender.SendAsync(user.Email, "Reset your MotoHub password", token, cancellationToken);
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        ValidatePassword(request.NewPassword, request.ConfirmPassword);
        var user = await userManager.FindByEmailAsync(request.Email)
            ?? throw new AuthenticationException("Invalid reset request.");
        EnsureSuccess(await userManager.ResetPasswordAsync(user, request.Token, request.NewPassword));
        await RevokeAllAsync(user.Id, "Password reset", cancellationToken);
    }

    public async Task ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        ValidatePassword(request.NewPassword, request.ConfirmPassword);
        var user = await userManager.FindByIdAsync(userId.ToString())
            ?? throw new AuthenticationException("User is not available.", 401);
        EnsureSuccess(await userManager.ChangePasswordAsync(user, request.CurrentPassword, request.NewPassword), 400);
        await RevokeAllAsync(userId, "Password changed", cancellationToken);
    }

    public async Task ConfirmEmailAsync(ConfirmEmailRequest request, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(request.UserId.ToString())
            ?? throw new AuthenticationException("Invalid confirmation request.");
        EnsureSuccess(await userManager.ConfirmEmailAsync(user, request.Token));
        var domainUser = await dbContext.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == request.UserId, cancellationToken);
        domainUser.EmailConfirmed = true;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<AuthUser> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString())
            ?? throw new AuthenticationException("User is not available.", 401);
        if (!await IsActiveAsync(user.Id, cancellationToken))
        {
            throw new AuthenticationException("User is not available.", 401);
        }
        return await MapUserAsync(user, cancellationToken);
    }

    private async Task<AuthResponse> IssueSessionAsync(MotoHubIdentityUser identityUser, string? ipAddress, CancellationToken cancellationToken, RefreshToken? replaced = null)
    {
        if (!await IsActiveAsync(identityUser.Id, cancellationToken))
        {
            await sessionRevocationService.RevokeAllAsync(identityUser.Id, "Inactive user", ipAddress, cancellationToken);
            throw new AuthenticationException("User is not available.", 401);
        }
        var roles = await userManager.GetRolesAsync(identityUser);
        var (accessToken, expiresAt) = jwtTokenService.Create(identityUser, roles);
        var refreshToken = JwtTokenService.CreateRefreshToken();
        var profile = await dbContext.Users.IgnoreQueryFilters().SingleOrDefaultAsync(x => x.Id == identityUser.Id, cancellationToken);
        if (profile is not null)
        {
            profile.LastLoginAt = DateTimeOffset.UtcNow;
        }
        var storedToken = new RefreshToken
        {
            UserId = identityUser.Id,
            TokenHash = JwtTokenService.HashRefreshToken(refreshToken),
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(jwtOptions.Value.RefreshTokenDays),
            CreatedByIp = ipAddress
        };
        dbContext.RefreshTokens.Add(storedToken);
        if (replaced is not null)
        {
            replaced.ReplacedByTokenId = storedToken.Id;
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        return new AuthResponse(accessToken, refreshToken, expiresAt, await MapUserAsync(identityUser, cancellationToken));
    }

    private async Task<AuthUser> MapUserAsync(MotoHubIdentityUser identityUser, CancellationToken cancellationToken)
    {
        var roles = await userManager.GetRolesAsync(identityUser);
        var profile = await dbContext.Users.IgnoreQueryFilters().SingleOrDefaultAsync(x => x.Id == identityUser.Id, cancellationToken)
            ?? throw new AuthenticationException("User profile is not available.", 401);
        if (!profile.IsActive || profile.IsDeleted)
        {
            throw new AuthenticationException("User is not available.", 401);
        }
        return new AuthUser(profile.Id, identityUser.Email!, identityUser.UserName!, profile.FirstName, profile.LastName, identityUser.EmailConfirmed, roles.ToArray());
    }

    private async Task EnsureRoleAsync(string role, CancellationToken cancellationToken)
    {
        AdminSecurity.EnsureAutomaticRoleIsNotAdmin(role);
        if (await roleManager.RoleExistsAsync(role)) return;
        EnsureSuccess(await roleManager.CreateAsync(new MotoHubIdentityRole { Name = role }));
    }

    private Task<int> RevokeAllAsync(Guid userId, string reason, CancellationToken cancellationToken)
        => sessionRevocationService.RevokeAllAsync(userId, reason, null, cancellationToken);

    private async Task<bool> IsActiveAsync(Guid userId, CancellationToken cancellationToken)
    {
        var profile = await dbContext.Users
            .IgnoreQueryFilters()
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);
        return profile is { IsActive: true, IsDeleted: false };
    }

    private static void ValidatePassword(string password, string confirmation)
    {
        if (password != confirmation || password.Length < 12 || !password.Any(char.IsUpper) || !password.Any(char.IsLower) || !password.Any(char.IsDigit))
        {
            throw new AuthenticationException("Password must be at least 12 characters and contain upper, lower and numeric characters.");
        }
    }

    private static void EnsureSuccess(IdentityResult result, int statusCode = 400)
    {
        if (result.Succeeded) return;
        throw new AuthenticationException(string.Join("; ", result.Errors.Select(x => x.Description)), statusCode);
    }
}