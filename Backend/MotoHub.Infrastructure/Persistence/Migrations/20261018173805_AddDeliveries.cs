using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MotoHub.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDeliveries : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Deliveries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductTransactionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BuyerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SellerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DestinationLatitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    DestinationLongitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: false),
                    DriverLatitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: true),
                    DriverLongitude = table.Column<decimal>(type: "decimal(9,6)", precision: 9, scale: 6, nullable: true),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Deliveries", x => x.Id);
                    table.CheckConstraint("CK_Deliveries_DestinationCoordinates", "[DestinationLatitude] >= -90 AND [DestinationLatitude] <= 90 AND [DestinationLongitude] >= -180 AND [DestinationLongitude] <= 180");
                    table.CheckConstraint("CK_Deliveries_DriverCoordinates", "([DriverLatitude] IS NULL AND [DriverLongitude] IS NULL) OR ([DriverLatitude] >= -90 AND [DriverLatitude] <= 90 AND [DriverLongitude] >= -180 AND [DriverLongitude] <= 180)");
                    table.ForeignKey(
                        name: "FK_Deliveries_ProductTransactions_ProductTransactionId",
                        column: x => x.ProductTransactionId,
                        principalTable: "ProductTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Deliveries_Users_BuyerUserId",
                        column: x => x.BuyerUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Deliveries_Users_SellerUserId",
                        column: x => x.SellerUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Deliveries_BuyerUserId",
                table: "Deliveries",
                column: "BuyerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Deliveries_ProductTransactionId",
                table: "Deliveries",
                column: "ProductTransactionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Deliveries_SellerUserId",
                table: "Deliveries",
                column: "SellerUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Deliveries");
        }
    }
}
