using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[EnableRateLimiting("nominatim-geocoding")]
[Route("api/geocoding")]
public sealed class GeocodingController(
    IHttpClientFactory httpClientFactory,
    ILogger<GeocodingController> logger) : ControllerBase
{
    [HttpGet("search")]
    [ProducesResponseType(typeof(IReadOnlyList<LocationSearchResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<IReadOnlyList<LocationSearchResponse>>> Search(
        [FromQuery, Required, StringLength(120, MinimumLength = 2)] string query,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query))
            return BadRequest(new ProblemDetails { Title = "Escribe una ubicación para buscar." });

        var uri = Microsoft.AspNetCore.WebUtilities.QueryHelpers.AddQueryString(
            "search",
            new Dictionary<string, string?>
            {
                ["format"] = "jsonv2",
                ["limit"] = "5",
                ["accept-language"] = "es",
                ["q"] = query.Trim()
            });

        try
        {
            var client = httpClientFactory.CreateClient("Nominatim");
            using var response = await client.GetAsync(uri, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Nominatim returned status code {StatusCode}.", response.StatusCode);
                return Problem(
                    statusCode: StatusCodes.Status502BadGateway,
                    title: "El servicio de búsqueda de ubicaciones no está disponible.");
            }

            var places = await response.Content.ReadFromJsonAsync<List<NominatimPlace>>(
                cancellationToken: cancellationToken) ?? [];

            var results = places
                .Select(place => TryCreateResponse(place))
                .Where(place => place is not null)
                .Select(place => place!)
                .ToArray();

            return Ok(results);
        }
        catch (HttpRequestException exception)
        {
            logger.LogWarning(exception, "The Nominatim geocoding request failed.");
            return Problem(
                statusCode: StatusCodes.Status502BadGateway,
                title: "El servicio de búsqueda de ubicaciones no está disponible.");
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Problem(
                statusCode: StatusCodes.Status502BadGateway,
                title: "El servicio de búsqueda de ubicaciones tardó demasiado.");
        }
    }

    private static LocationSearchResponse? TryCreateResponse(NominatimPlace place)
    {
        if (!double.TryParse(place.Latitude, NumberStyles.Float, CultureInfo.InvariantCulture, out var latitude) ||
            !double.TryParse(place.Longitude, NumberStyles.Float, CultureInfo.InvariantCulture, out var longitude))
        {
            return null;
        }

        return new LocationSearchResponse(place.DisplayName, latitude, longitude);
    }

    private sealed record NominatimPlace(
        [property: JsonPropertyName("display_name")] string DisplayName,
        [property: JsonPropertyName("lat")] string Latitude,
        [property: JsonPropertyName("lon")] string Longitude);
}

/// <summary>Location search result returned by the geocoding endpoint.</summary>
public sealed record LocationSearchResponse(string Label, double Latitude, double Longitude);