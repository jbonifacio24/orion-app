using System.Text.Json;
using MotoHub.Application;

namespace MotoHub.Api.Middleware;

public sealed class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (AuthenticationException exception)
        {
            context.Response.StatusCode = exception.StatusCode;
            context.Response.ContentType = "application/problem+json";
            await context.Response.WriteAsync(JsonSerializer.Serialize(new
            {
                type = "https://httpstatuses.com/" + exception.StatusCode,
                title = exception.StatusCode == 401 ? "Unauthorized" : "Authentication error",
                status = exception.StatusCode,
                detail = exception.Message
            }));
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unhandled request error.");
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/problem+json";
            await context.Response.WriteAsync("{\"title\":\"Internal server error\",\"status\":500}");
        }
    }
}