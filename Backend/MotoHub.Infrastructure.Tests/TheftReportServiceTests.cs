using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.TheftReports;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.TheftReports;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class TheftReportServiceTests
{
    [Fact]
    public async Task Create_with_owned_motorcycle_copies_server_data_and_masks_vin()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var motorcycle = new Motorcycle
        {
            OwnerUserId = ownerId,
            Brand = "Honda",
            Model = "CB500X",
            Year = 2024,
            Color = "Red",
            LicensePlate = "ABC-123",
            Vin = "1HGCM82633A004352"
        };
        context.Motorcycles.Add(motorcycle);
        await context.SaveChangesAsync();
        var service = new TheftReportService(context);

        var response = await service.CreateAsync(ownerId, Request(motorcycle.Id, brand: "Forged", vin: "FORGED"), default);

        var stored = await context.TheftReports.SingleAsync();
        Assert.Equal(ownerId, stored.ReporterUserId);
        Assert.Equal(TheftReportStatus.Reported, stored.Status);
        Assert.Equal("Honda", stored.Brand);
        Assert.Equal("CB500X", stored.Model);
        Assert.Equal("1HGCM82633A004352", stored.Vin);
        Assert.Equal("*************4352", response.Vin);
    }

    [Fact]
    public async Task Public_list_hides_resolved_reports_and_rejects_resolved_status_filter()
    {
        await using var context = CreateContext();
        context.TheftReports.AddRange(
            Report(TheftReportStatus.Reported),
            Report(TheftReportStatus.Investigating),
            Report(TheftReportStatus.Recovered));
        await context.SaveChangesAsync();
        var service = new TheftReportService(context);

        var active = await service.GetActiveAsync(new TheftReportListQueryDto(Page: 1, PageSize: 20), default);

        Assert.Equal(2, active.TotalCount);
        await Assert.ThrowsAsync<ValidationException>(() => service.GetActiveAsync(
            new TheftReportListQueryDto(Status: TheftReportStatus.Closed), default));
    }

    [Fact]
    public async Task Only_reporter_can_resolve_and_only_terminal_statuses_are_accepted()
    {
        await using var context = CreateContext();
        var reporterId = Guid.NewGuid();
        var report = Report(TheftReportStatus.Reported, reporterId);
        context.TheftReports.Add(report);
        await context.SaveChangesAsync();
        var service = new TheftReportService(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.UpdateStatusAsync(
            Guid.NewGuid(), report.Id, new UpdateTheftReportStatusRequestDto(TheftReportStatus.Closed), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.UpdateStatusAsync(
            reporterId, report.Id, new UpdateTheftReportStatusRequestDto(TheftReportStatus.Investigating), default));

        var resolved = await service.UpdateStatusAsync(
            reporterId, report.Id, new UpdateTheftReportStatusRequestDto(TheftReportStatus.Recovered), default);

        Assert.Equal(TheftReportStatus.Recovered, resolved.Status);
        Assert.NotNull(resolved.ResolvedAt);
    }

    [Fact]
    public async Task Resolve_rejects_a_report_that_is_already_terminal()
    {
        await using var context = CreateContext();
        var reporterId = Guid.NewGuid();
        var report = Report(TheftReportStatus.Recovered, reporterId);
        var resolvedAt = DateTimeOffset.UtcNow.AddMinutes(-5);
        report.ResolvedAt = resolvedAt;
        context.TheftReports.Add(report);
        await context.SaveChangesAsync();
        var service = new TheftReportService(context);

        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateStatusAsync(
            reporterId, report.Id, new UpdateTheftReportStatusRequestDto(TheftReportStatus.Closed), default));

        Assert.Equal(TheftReportStatus.Recovered, report.Status);
        Assert.Equal(resolvedAt, report.ResolvedAt);
    }

    private static CreateTheftReportRequestDto Request(Guid? motorcycleId = null, string? brand = "Yamaha", string? vin = "VIN-123")
        => new(motorcycleId, "Stolen motorcycle", "Description", "XYZ-987", vin, brand, "MT-07", "Blue", DateTimeOffset.UtcNow.AddMinutes(-1), "Madrid", 40.4168m, -3.7038m);

    private static TheftReport Report(TheftReportStatus status, Guid? reporterId = null) => new()
    {
        ReporterUserId = reporterId ?? Guid.NewGuid(),
        Title = "Stolen motorcycle",
        Description = "Description",
        Brand = "Yamaha",
        Model = "MT-07",
        LicensePlate = "XYZ-987",
        TheftDate = DateTimeOffset.UtcNow.AddDays(-1),
        Status = status
    };

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}