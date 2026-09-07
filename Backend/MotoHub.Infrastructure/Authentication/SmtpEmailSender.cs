using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;
using MotoHub.Application;

namespace MotoHub.Infrastructure.Authentication;

public sealed class SmtpEmailSender(IOptions<EmailOptions> options) : IEmailSender
{
    public async Task SendAsync(string recipient, string subject, string body, CancellationToken cancellationToken)
    {
        var settings = options.Value;
        if (!settings.Enabled) return;
        if (string.IsNullOrWhiteSpace(settings.Host) || string.IsNullOrWhiteSpace(settings.FromAddress))
        {
            throw new InvalidOperationException("Email configuration is incomplete.");
        }

        using var message = new MailMessage(settings.FromAddress, recipient, subject, body);
        using var client = new SmtpClient(settings.Host, settings.Port)
        {
            EnableSsl = settings.EnableSsl,
            Credentials = string.IsNullOrWhiteSpace(settings.UserName)
                ? CredentialCache.DefaultNetworkCredentials
                : new NetworkCredential(settings.UserName, settings.Password)
        };
        await client.SendMailAsync(message, cancellationToken);
    }
}