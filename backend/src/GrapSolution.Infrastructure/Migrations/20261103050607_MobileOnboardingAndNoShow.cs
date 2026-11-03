using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GrapSolution.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class MobileOnboardingAndNoShow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ReviewReason",
                table: "DriverDocument",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "RideContactAttempt",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RideId = table.Column<string>(type: "character varying(64)", nullable: false),
                    DriverId = table.Column<string>(type: "text", nullable: false),
                    Channel = table.Column<string>(type: "text", nullable: false),
                    Note = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RideContactAttempt", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RideContactAttempt_Ride_RideId",
                        column: x => x.RideId,
                        principalTable: "Ride",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RideContactAttempt_RideId_DriverId_CreatedAt",
                table: "RideContactAttempt",
                columns: new[] { "RideId", "DriverId", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RideContactAttempt");

            migrationBuilder.DropColumn(
                name: "ReviewReason",
                table: "DriverDocument");
        }
    }
}
