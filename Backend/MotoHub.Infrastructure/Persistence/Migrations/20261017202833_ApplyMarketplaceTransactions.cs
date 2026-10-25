using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MotoHub.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ApplyMarketplaceTransactions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "Latitude",
                table: "Products",
                type: "decimal(9,6)",
                precision: 9,
                scale: 6,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Longitude",
                table: "Products",
                type: "decimal(9,6)",
                precision: 9,
                scale: 6,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentMethod",
                table: "Products",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ProductTransactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SellerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BuyerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OfferedAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Currency = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false),
                    PaymentMethod = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    AcceptedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    PaidAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    DeliveredAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CancelledAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CancellationReason = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductTransactions", x => x.Id);
                    table.CheckConstraint("CK_ProductTransactions_OfferedAmount", "[OfferedAmount] >= 0");
                    table.ForeignKey(
                        name: "FK_ProductTransactions_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ProductTransactions_Users_BuyerUserId",
                        column: x => x.BuyerUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ProductTransactions_Users_SellerUserId",
                        column: x => x.SellerUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ProductTransactionReviews",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductTransactionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReviewerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReviewedUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Rating = table.Column<int>(type: "int", nullable: false),
                    Comment = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductTransactionReviews", x => x.Id);
                    table.CheckConstraint("CK_ProductTransactionReviews_Rating", "[Rating] BETWEEN 1 AND 5");
                    table.ForeignKey(
                        name: "FK_ProductTransactionReviews_ProductTransactions_ProductTransactionId",
                        column: x => x.ProductTransactionId,
                        principalTable: "ProductTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProductTransactionReviews_Users_ReviewedUserId",
                        column: x => x.ReviewedUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ProductTransactionReviews_Users_ReviewerUserId",
                        column: x => x.ReviewerUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_Products_Latitude",
                table: "Products",
                sql: "[Latitude] IS NULL OR ([Latitude] >= -90 AND [Latitude] <= 90)");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Products_Longitude",
                table: "Products",
                sql: "[Longitude] IS NULL OR ([Longitude] >= -180 AND [Longitude] <= 180)");

            migrationBuilder.CreateIndex(
                name: "IX_ProductTransactionReviews_ProductTransactionId_ReviewerUserId",
                table: "ProductTransactionReviews",
                columns: new[] { "ProductTransactionId", "ReviewerUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProductTransactionReviews_ReviewedUserId",
                table: "ProductTransactionReviews",
                column: "ReviewedUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductTransactionReviews_ReviewerUserId",
                table: "ProductTransactionReviews",
                column: "ReviewerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductTransactions_BuyerUserId_CreatedAt",
                table: "ProductTransactions",
                columns: new[] { "BuyerUserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductTransactions_ProductId",
                table: "ProductTransactions",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductTransactions_SellerUserId_CreatedAt",
                table: "ProductTransactions",
                columns: new[] { "SellerUserId", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ProductTransactionReviews");

            migrationBuilder.DropTable(
                name: "ProductTransactions");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Products_Latitude",
                table: "Products");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Products_Longitude",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "PaymentMethod",
                table: "Products");
        }
    }
}
