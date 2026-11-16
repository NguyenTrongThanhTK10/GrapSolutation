using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GrapSolution.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class RideChat : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Chat notifications also need the existing push model, which lacked a PostgreSQL migration.
            migrationBuilder.AddColumn<string>(
                name: "Kind",
                table: "Notification",
                type: "text",
                nullable: false,
                defaultValue: "ride");

            migrationBuilder.CreateTable(
                name: "PushDevice",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    InstallationId = table.Column<string>(type: "text", nullable: false),
                    AppType = table.Column<string>(type: "text", nullable: false),
                    Platform = table.Column<string>(type: "text", nullable: false),
                    UserId = table.Column<string>(type: "character varying(64)", nullable: false),
                    SessionId = table.Column<string>(type: "character varying(64)", nullable: false),
                    TokenHash = table.Column<string>(type: "text", nullable: false),
                    TokenProtected = table.Column<string>(type: "text", nullable: false),
                    LastSeenAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RevokedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PushDevice", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PushDevice_Session_SessionId",
                        column: x => x.SessionId,
                        principalTable: "Session",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PushDevice_User_UserId",
                        column: x => x.UserId,
                        principalTable: "User",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RideChatMessage",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    RideId = table.Column<string>(type: "character varying(64)", nullable: false),
                    AssignmentId = table.Column<string>(type: "character varying(64)", nullable: false),
                    SenderId = table.Column<string>(type: "character varying(64)", nullable: false),
                    BodyProtected = table.Column<string>(type: "text", nullable: false),
                    Sequence = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RideChatMessage", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RideChatMessage_Assignment_AssignmentId",
                        column: x => x.AssignmentId,
                        principalTable: "Assignment",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RideChatMessage_Ride_RideId",
                        column: x => x.RideId,
                        principalTable: "Ride",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RideChatMessage_User_SenderId",
                        column: x => x.SenderId,
                        principalTable: "User",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PushDelivery",
                columns: table => new
                {
                    Id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    NotificationId = table.Column<string>(type: "character varying(64)", nullable: false),
                    DeviceId = table.Column<string>(type: "character varying(64)", nullable: false),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    SessionId = table.Column<string>(type: "text", nullable: false),
                    TokenHash = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    Attempts = table.Column<int>(type: "integer", nullable: false),
                    NextAttemptAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    SentAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LastError = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PushDelivery", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PushDelivery_Notification_NotificationId",
                        column: x => x.NotificationId,
                        principalTable: "Notification",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PushDelivery_PushDevice_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "PushDevice",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PushDelivery_DeviceId",
                table: "PushDelivery",
                column: "DeviceId");

            migrationBuilder.CreateIndex(
                name: "IX_PushDelivery_NotificationId_DeviceId",
                table: "PushDelivery",
                columns: new[] { "NotificationId", "DeviceId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PushDelivery_Status_NextAttemptAt",
                table: "PushDelivery",
                columns: new[] { "Status", "NextAttemptAt" });

            migrationBuilder.CreateIndex(
                name: "IX_PushDevice_InstallationId_AppType",
                table: "PushDevice",
                columns: new[] { "InstallationId", "AppType" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PushDevice_SessionId",
                table: "PushDevice",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_PushDevice_TokenHash",
                table: "PushDevice",
                column: "TokenHash",
                unique: true,
                filter: "\"RevokedAt\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_PushDevice_UserId",
                table: "PushDevice",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RideChatMessage_AssignmentId_Sequence",
                table: "RideChatMessage",
                columns: new[] { "AssignmentId", "Sequence" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RideChatMessage_RideId",
                table: "RideChatMessage",
                column: "RideId");

            migrationBuilder.CreateIndex(
                name: "IX_RideChatMessage_SenderId",
                table: "RideChatMessage",
                column: "SenderId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PushDelivery");

            migrationBuilder.DropTable(
                name: "RideChatMessage");

            migrationBuilder.DropTable(
                name: "PushDevice");

            migrationBuilder.DropColumn(
                name: "Kind",
                table: "Notification");
        }
    }
}
