namespace MotoHub.Application;

public interface IPushTokenProtector
{
	string Protect(string token);
	string Unprotect(string protectedToken);
}

public sealed record FoundationApplicationMarker;

public sealed record RegisterRequest(
	string Email,
	string UserName,
	string Password,
	string ConfirmPassword,
	string? FirstName,
	string? LastName);

public sealed record LoginRequest(string EmailOrUserName, string Password);
public sealed record RefreshTokenRequest(string RefreshToken);
public sealed record LogoutRequest(string RefreshToken);
public sealed record ForgotPasswordRequest(string Email);
public sealed record ResetPasswordRequest(string Email, string Token, string NewPassword, string ConfirmPassword);
public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword, string ConfirmPassword);
public sealed record ConfirmEmailRequest(Guid UserId, string Token);
public sealed record AuthUser(Guid Id, string Email, string UserName, string? FirstName, string? LastName, bool EmailConfirmed, IReadOnlyCollection<string> Roles);
public sealed record AuthResponse(string AccessToken, string RefreshToken, DateTimeOffset AccessTokenExpiresAt, AuthUser User);

public interface IAuthenticationService
{
	Task<AuthResponse> RegisterAsync(RegisterRequest request, string? ipAddress, CancellationToken cancellationToken);
	Task<AuthResponse> LoginAsync(LoginRequest request, string? ipAddress, CancellationToken cancellationToken);
	Task<AuthResponse> RefreshAsync(RefreshTokenRequest request, string? ipAddress, CancellationToken cancellationToken);
	Task LogoutAsync(LogoutRequest request, string? ipAddress, CancellationToken cancellationToken);
	Task ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken cancellationToken);
	Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken);
	Task ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken);
	Task ConfirmEmailAsync(ConfirmEmailRequest request, CancellationToken cancellationToken);
	Task<AuthUser> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken);
}
