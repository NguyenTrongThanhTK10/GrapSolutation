using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GrapSolution.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class PrivateFilesAndIntegrity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "DriverId",
                table: "DriverDocument",
                type: "character varying(64)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.CreateTable(
                name: "LocationSample",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DriverId = table.Column<string>(type: "text", nullable: false),
                    SessionId = table.Column<string>(type: "text", nullable: false),
                    SampleId = table.Column<string>(type: "text", nullable: false),
                    Sequence = table.Column<long>(type: "bigint", nullable: false),
                    Latitude = table.Column<double>(type: "double precision", nullable: false),
                    Longitude = table.Column<double>(type: "double precision", nullable: false),
                    AccuracyMeters = table.Column<double>(type: "double precision", nullable: false),
                    RecordedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LocationSample", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PrivateFile",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    OwnerId = table.Column<string>(type: "character varying(64)", nullable: false),
                    Purpose = table.Column<string>(type: "text", nullable: false),
                    ContentType = table.Column<string>(type: "text", nullable: false),
                    Size = table.Column<long>(type: "bigint", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PrivateFile", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PrivateFile_User_OwnerId",
                        column: x => x.OwnerId,
                        principalTable: "User",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_Rating_Stars",
                table: "Rating",
                sql: "\"Stars\" >= 1 AND \"Stars\" <= 5");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Payment_Amounts",
                table: "Payment",
                sql: "\"PayableAmount\" >= 0 AND \"PaidAmount\" >= 0 AND \"PaidAmount\" <= \"PayableAmount\"");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Ledger_Sides",
                table: "LedgerEntry",
                sql: "\"Debit\" >= 0 AND \"Credit\" >= 0 AND NOT (\"Debit\" > 0 AND \"Credit\" > 0)");

            migrationBuilder.CreateIndex(
                name: "IX_DriverDocument_DriverId",
                table: "DriverDocument",
                column: "DriverId");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Cash_Amount",
                table: "CashCollection",
                sql: "\"Amount\" >= 0");

            migrationBuilder.CreateIndex(
                name: "IX_LocationSample_DriverId_SessionId_SampleId",
                table: "LocationSample",
                columns: new[] { "DriverId", "SessionId", "SampleId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PrivateFile_OwnerId",
                table: "PrivateFile",
                column: "OwnerId");

            migrationBuilder.AddForeignKey(
                name: "FK_DriverDocument_Driver_DriverId",
                table: "DriverDocument",
                column: "DriverId",
                principalTable: "Driver",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_DriverDocument_Driver_DriverId",
                table: "DriverDocument");

            migrationBuilder.DropTable(
                name: "LocationSample");

            migrationBuilder.DropTable(
                name: "PrivateFile");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Rating_Stars",
                table: "Rating");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Payment_Amounts",
                table: "Payment");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Ledger_Sides",
                table: "LedgerEntry");

            migrationBuilder.DropIndex(
                name: "IX_DriverDocument_DriverId",
                table: "DriverDocument");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Cash_Amount",
                table: "CashCollection");

            migrationBuilder.AlterColumn<string>(
                name: "DriverId",
                table: "DriverDocument",
                type: "text",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(64)");
        }
    }
}
