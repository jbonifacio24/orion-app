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

    [HttpPost("{postId:guid}/likes")]
    public Task<PostLikeStateResponse> Like(Guid postId, CancellationToken cancellationToken)
        => communityService.LikePostAsync(CurrentUserId(), postId, cancellationToken);

    [HttpDelete("{postId:guid}/likes")]
    public Task<PostLikeStateResponse> Unlike(Guid postId, CancellationToken cancellationToken)
        => communityService.UnlikePostAsync(CurrentUserId(), postId, cancellationToken);

    [HttpGet("{postId:guid}/comments")]
    public Task<PagedResponse<PostCommentResponse>> GetComments(
        Guid postId,
        [FromQuery] PostListQueryDto query,
        CancellationToken cancellationToken)
        => communityService.GetCommentsAsync(CurrentUserId(), postId, query, cancellationToken);

    [HttpPost("{postId:guid}/comments")]
    public async Task<IActionResult> CreateComment(
        Guid postId,
        CreatePostCommentRequest request,
        CancellationToken cancellationToken)
    {
        var comment = await communityService.CreateCommentAsync(CurrentUserId(), postId, request, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, comment);
    }

    [HttpDelete("{postId:guid}/comments/{commentId:guid}")]
    public async Task<IActionResult> DeleteComment(Guid postId, Guid commentId, CancellationToken cancellationToken)
    {
        await communityService.DeleteCommentAsync(CurrentUserId(), postId, commentId, cancellationToken);
        return NoContent();
    }
}