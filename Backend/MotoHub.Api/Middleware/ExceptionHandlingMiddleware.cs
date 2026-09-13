using System.Text.Json;
using MotoHub.Application;
using MotoHub.Application.Errors;

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
            await WriteProblemAsync(context, exception.StatusCode,
                exception.StatusCode == 401 ? "Unauthorized" : "Authentication error", exception.Message);
        }
        catch (MotoHub.Application.Errors.ApplicationException exception)
        {
            await WriteProblemAsync(context, exception.StatusCode, exception.GetType().Name, exception.Message);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unhandled request error.");
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/problem+json";
            await context.Response.WriteAsync("{\"title\":\"Internal server error\",\"status\":500}");
        }
    }

    private static async Task WriteProblemAsync(HttpContext context, int statusCode, string title, string detail)
    {
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/problem+json";
        await context.Response.WriteAsync(JsonSerializer.Serialize(new
        {
            type = "https://httpstatuses.com/" + statusCode,
            title,
            status = statusCode,
            detail
        }));
    }
}