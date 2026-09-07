namespace MotoHub.Application;

public interface IEmailSender
{
    Task SendAsync(string recipient, string subject, string body, CancellationToken cancellationToken);
}

public sealed class AuthenticationException(string message, int statusCode = 400) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}