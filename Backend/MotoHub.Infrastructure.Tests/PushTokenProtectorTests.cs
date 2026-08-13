using Microsoft.Extensions.Options;
using MotoHub.Infrastructure.Security;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class PushTokenProtectorTests
{
    [Fact]
    public void Protect_and_unprotect_round_trip_the_original_token()
    {
        var key = Convert.ToBase64String(new byte[32]);
        var protector = new AesGcmPushTokenProtector(
            Options.Create(new PushTokenEncryptionOptions { PushTokenEncryptionKey = key }));

        var protectedToken = protector.Protect("push-token-value");

        Assert.NotEqual("push-token-value", protectedToken);
        Assert.Equal("push-token-value", protector.Unprotect(protectedToken));
    }

    [Fact]
    public void Missing_key_is_rejected()
    {
        var protector = new AesGcmPushTokenProtector(
            Options.Create(new PushTokenEncryptionOptions()));

        Assert.Throws<InvalidOperationException>(() => protector.Protect("push-token-value"));
    }
}
