using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Profile;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/users")]
public sealed class UsersController(IProfileService profileService) : CurrentUserControllerBase
{
    [HttpGet("me")]
    public Task<ProfileResponseDto> GetCurrent(CancellationToken cancellationToken)
        => profileService.GetCurrentAsync(CurrentUserId(), cancellationToken);

    [HttpPut("me")]
    public Task<ProfileResponseDto> Update(UpdateProfileRequestDto request, CancellationToken cancellationToken)
        => profileService.UpdateAsync(CurrentUserId(), request, cancellationToken);
}
