namespace MotoHub.Application;

public interface IPushTokenProtector
{
	string Protect(string token);
	string Unprotect(string protectedToken);
}

public sealed record FoundationApplicationMarker;
