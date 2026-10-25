using Google.Apis.Auth;
using Microsoft.Extensions.Options;
using MotoHub.Application;

namespace MotoHub.Infrastructure.Authentication;

public sealed class GoogleIdentityTokenValidator(IOptions<GoogleAuthOptions> options) : IGoogleIdentityTokenValidator
{
    public async Task<GoogleIdentity> ValidateAsync(string idToken, CancellationToken cancellationToken)
    {
        var clientId = options.Value.ClientId;
        if (string.IsNullOrWhiteSpace(clientId))
        {
            throw new AuthenticationException("Google sign-in is not configured.", 503);
        }

        if (string.IsNullOrWhiteSpace(idToken))
        {
            throw new AuthenticationException("Google ID token is required.", 401);
        }

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(
                idToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = [clientId] });
        }
        catch (InvalidJwtException)
        {
            throw new AuthenticationException("Google ID token is invalid or expired.", 401);
        }
        catch (HttpRequestException)
        {
            throw new AuthenticationException("Google identity validation is temporarily unavailable.", 503);
        }

        if (string.IsNullOrWhiteSpace(payload.Subject) || string.IsNullOrWhiteSpace(payload.Email))
        {
            throw new AuthenticationException("Google account does not contain a usable identity.", 401);
        }

        return new GoogleIdentity(
            payload.Subject,
            payload.Email,
            payload.EmailVerified == true,
            payload.GivenName,
            payload.FamilyName);
    }
}