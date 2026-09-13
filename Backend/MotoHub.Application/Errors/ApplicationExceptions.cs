namespace MotoHub.Application.Errors;

public abstract class ApplicationException(string message, int statusCode) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}

public sealed class ValidationException(string message)
    : ApplicationException(message, 400);

public sealed class ResourceNotFoundException(string message)
    : ApplicationException(message, 404);

public sealed class ConflictException(string message)
    : ApplicationException(message, 409);
