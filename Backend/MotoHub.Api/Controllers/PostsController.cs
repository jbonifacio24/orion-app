using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Community;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/posts")]
public sealed class PostsController(ICommunityService communityService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<PagedResponse<PostSummaryResponse>> Get(
        [FromQuery] PostListQueryDto query,
        CancellationToken cancellationToken)
        => communityService.GetFeedAsync(CurrentUserId(), query, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<PostDetailResponse> GetById(Guid id, CancellationToken cancellationToken)
        => communityService.GetByIdAsync(CurrentUserId(), id, cancellationToken);

    [HttpPost]
    public async Task<IActionResult> Create(CreatePostRequest request, CancellationToken cancellationToken)
    {
        var post = await communityService.CreateAsync(CurrentUserId(), request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = post.Id }, post);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await communityService.DeleteAsync(CurrentUserId(), id, cancellationToken);
        return NoContent();
    }
}