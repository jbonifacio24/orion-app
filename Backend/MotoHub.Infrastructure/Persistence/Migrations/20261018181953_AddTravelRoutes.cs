using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MotoHub.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddTravelRoutes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Deliveries_DriverCoordinates",
                table: "Deliveries");

            migrationBuilder.CreateTable(
                name: "TravelRoutes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(max)", maxLength: 5000, nullable: true),
                    StartName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    EndName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    StartLatitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    StartLongitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    EndLatitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    EndLongitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    PathJson = table.Column<string>(type: "nvarchar(max)", maxLength: 20000, nullable: false),
                    DepartureAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    IsPublished = table.Column<bool>(type: "bit", nullable: false),
                    ConversationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    DeletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TravelRoutes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TravelRoutes_Conversations_ConversationId",
                        column: x => x.ConversationId,
                        principalTable: "Conversations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TravelRoutes_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_Deliveries_DriverCoordinates",
                table: "Deliveries",
                sql: "([DriverLatitude] IS NULL AND [DriverLongitude] IS NULL) OR ([DriverLatitude] >= -90 AND [DriverLatitude] <= 90 AND [DriverLongitude] >= -180 AND [DriverLongitude] <= 180)");

            migrationBuilder.CreateIndex(
                name: "IX_TravelRoutes_ConversationId",
                table: "TravelRoutes",
                column: "ConversationId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TravelRoutes_CreatedByUserId",
                table: "TravelRoutes",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TravelRoutes_IsPublished_DepartureAt",
                table: "TravelRoutes",
                columns: new[] { "IsPublished", "DepartureAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TravelRoutes");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Deliveries_DriverCoordinates",
                table: "Deliveries");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Deliveries_DriverCoordinates",
                table: "Deliveries",
                sql: "[DriverLatitude] IS NULL OR ([DriverLatitude] >= -90 AND [DriverLatitude] <= 90) AND [DriverLongitude] IS NULL OR ([DriverLongitude] >= -180 AND [DriverLongitude] <= 180)");
        }
    }
}
