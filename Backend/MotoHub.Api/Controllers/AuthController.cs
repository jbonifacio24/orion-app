using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MotoHub.Application;

namespace MotoHub.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(IAuthenticationService authenticationService) : ControllerBase
{
    [HttpPost("register")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request, CancellationToken cancellationToken)
        => Ok(await authenticationService.RegisterAsync(request, ClientIp(), cancellationToken));

    [HttpPost("login")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
        => Ok(await authenticationService.LoginAsync(request, ClientIp(), cancellationToken));

    [HttpPost("refresh")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshTokenRequest request, CancellationToken cancellationToken)
        => Ok(await authenticationService.RefreshAsync(request, ClientIp(), cancellationToken));

    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
    {
        await authenticationService.LogoutAsync(request, ClientIp(), cancellationToken);
        return NoContent();
    }

    [HttpPost("forgot-password")]
    [EnableRateLimiting("auth")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request, CancellationToken cancellationToken)
    {
        await authenticationService.ForgotPasswordAsync(request, cancellationToken);
        return Accepted(new { message = "If the account exists, reset instructions will be sent." });
    }

    [HttpPost("reset-password")]
    [EnableRateLimiting("auth")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        await authenticationService.ResetPasswordAsync(request, cancellationToken);
        return NoContent();
    }

    [Authorize]
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        await authenticationService.ChangePasswordAsync(CurrentUserId(), request, cancellationToken);
        return NoContent();
    }

    [HttpPost("confirm-email")]
    [EnableRateLimiting("auth")]
    public async Task<IActionResult> ConfirmEmail(ConfirmEmailRequest request, CancellationToken cancellationToken)
    {
        await authenticationService.ConfirmEmailAsync(request, cancellationToken);
        return NoContent();
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<AuthUser>> Me(CancellationToken cancellationToken)
        => Ok(await authenticationService.GetCurrentUserAsync(CurrentUserId(), cancellationToken));

    [Authorize(Roles = "User")]
    [HttpGet("role-check")]
    public IActionResult RoleCheck() => Ok(new { authorized = true, role = "User" });

    private Guid CurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        return Guid.TryParse(value, out var userId)
            ? userId
            : throw new AuthenticationException("The access token subject is invalid.", 401);
    }

    private string? ClientIp() => HttpContext.Connection.RemoteIpAddress?.ToString();
}