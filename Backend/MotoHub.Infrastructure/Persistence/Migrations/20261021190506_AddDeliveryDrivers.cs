using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MotoHub.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDeliveryDrivers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "DriverUserId",
                table: "Deliveries",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PickupLatitude",
                table: "Deliveries",
                type: "decimal(9,6)",
                precision: 9,
                scale: 6,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PickupLongitude",
                table: "Deliveries",
                type: "decimal(9,6)",
                precision: 9,
                scale: 6,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "DeliveryDriverProfiles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Latitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    Longitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    IsAvailable = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeliveryDriverProfiles", x => x.Id);
                    table.CheckConstraint("CK_DeliveryDriverProfiles_Latitude", "[Latitude] >= -90 AND [Latitude] <= 90");
                    table.CheckConstraint("CK_DeliveryDriverProfiles_Longitude", "[Longitude] >= -180 AND [Longitude] <= 180");
                    table.ForeignKey(
                        name: "FK_DeliveryDriverProfiles_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Deliveries_DriverUserId",
                table: "Deliveries",
                column: "DriverUserId");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Deliveries_PickupCoordinates",
                table: "Deliveries",
                sql: "([PickupLatitude] IS NULL AND [PickupLongitude] IS NULL) OR ([PickupLatitude] >= -90 AND [PickupLatitude] <= 90 AND [PickupLongitude] >= -180 AND [PickupLongitude] <= 180)");

            migrationBuilder.CreateIndex(
                name: "IX_DeliveryDriverProfiles_UserId",
                table: "DeliveryDriverProfiles",
                column: "UserId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Deliveries_Users_DriverUserId",
                table: "Deliveries",
                column: "DriverUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Deliveries_Users_DriverUserId",
                table: "Deliveries");

            migrationBuilder.DropTable(
                name: "DeliveryDriverProfiles");

            migrationBuilder.DropIndex(
                name: "IX_Deliveries_DriverUserId",
                table: "Deliveries");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Deliveries_PickupCoordinates",
                table: "Deliveries");

            migrationBuilder.DropColumn(
                name: "DriverUserId",
                table: "Deliveries");

            migrationBuilder.DropColumn(
                name: "PickupLatitude",
                table: "Deliveries");

            migrationBuilder.DropColumn(
                name: "PickupLongitude",
                table: "Deliveries");
        }
    }
}
