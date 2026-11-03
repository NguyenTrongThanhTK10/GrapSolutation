CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "AuditLog" (
        "Id" character varying(64) NOT NULL,
        "ActorId" text NOT NULL,
        "ActorName" text NOT NULL,
        "Action" text NOT NULL,
        "ResourceId" text NOT NULL,
        "Reason" text NOT NULL,
        "TraceId" text NOT NULL,
        "ZoneId" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_AuditLog" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "DriverDocument" (
        "Id" character varying(64) NOT NULL,
        "DriverId" text NOT NULL,
        "Type" text NOT NULL,
        "FileId" text NOT NULL,
        "Status" text NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "Version" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_DriverDocument" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "FarePolicy" (
        "Id" character varying(64) NOT NULL,
        "ZoneId" text NOT NULL,
        "ServiceTypeCode" text NOT NULL,
        "Name" text NOT NULL,
        "Version" integer NOT NULL,
        "Status" text NOT NULL,
        "BaseFare" bigint NOT NULL,
        "PerKm" bigint NOT NULL,
        "PerMinute" bigint NOT NULL,
        "MinimumFare" bigint NOT NULL,
        "ServiceFee" bigint NOT NULL,
        "CommissionRate" numeric NOT NULL,
        "EffectiveFrom" timestamp with time zone NOT NULL,
        "CreatedBy" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_FarePolicy" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "IdempotencyRecord" (
        "Id" character varying(64) NOT NULL,
        "ActorId" text NOT NULL,
        "Scope" text NOT NULL,
        "Key" text NOT NULL,
        "PayloadHash" text NOT NULL,
        "ResponseJson" text NOT NULL,
        "StatusCode" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_IdempotencyRecord" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Journal" (
        "Id" character varying(64) NOT NULL,
        "OperationKey" text NOT NULL,
        "RideId" text NOT NULL,
        "Description" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Journal" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Notification" (
        "Id" character varying(64) NOT NULL,
        "UserId" text NOT NULL,
        "Title" text NOT NULL,
        "Body" text NOT NULL,
        "EntityId" text,
        "ReadAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Notification" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "OtpChallenge" (
        "Id" character varying(64) NOT NULL,
        "Phone" text NOT NULL,
        "AppType" text NOT NULL,
        "CodeHmac" text NOT NULL,
        "Attempts" integer NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "ConsumedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_OtpChallenge" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "OutboxMessage" (
        "Id" character varying(64) NOT NULL,
        "EventType" text NOT NULL,
        "AggregateId" text NOT NULL,
        "AggregateVersion" integer NOT NULL,
        "Payload" text NOT NULL,
        "PublishedAt" timestamp with time zone,
        "Attempts" integer NOT NULL,
        "NextAttemptAt" timestamp with time zone NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_OutboxMessage" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Quote" (
        "Id" character varying(64) NOT NULL,
        "CustomerId" text NOT NULL,
        "Pickup" text NOT NULL,
        "Dropoff" text NOT NULL,
        "ServiceTypeCode" text NOT NULL,
        "ZoneId" text NOT NULL,
        "FarePolicyId" text NOT NULL,
        "FarePolicyVersion" integer NOT NULL,
        "Fare" text NOT NULL,
        "DistanceMeters" integer NOT NULL,
        "DurationSeconds" integer NOT NULL,
        "RouteSource" text NOT NULL,
        "RouteGeometry" text,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "ConsumedRideId" text,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Quote" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Rating" (
        "Id" character varying(64) NOT NULL,
        "RideId" text NOT NULL,
        "AuthorId" text NOT NULL,
        "Stars" integer NOT NULL,
        "Comment" text,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Rating" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Remittance" (
        "Id" character varying(64) NOT NULL,
        "DriverId" text NOT NULL,
        "Amount" bigint NOT NULL,
        "Reference" text NOT NULL,
        "MakerId" text NOT NULL,
        "ApproverId" text,
        "Status" text NOT NULL,
        "Evidence" text NOT NULL,
        "Version" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Remittance" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "SafetyIncident" (
        "Id" character varying(64) NOT NULL,
        "RideId" text NOT NULL,
        "ReporterId" text NOT NULL,
        "Status" text NOT NULL,
        "AcknowledgedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_SafetyIncident" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "ServiceZone" (
        "Id" character varying(64) NOT NULL,
        "Name" text NOT NULL,
        "PolygonJson" text NOT NULL,
        "Active" boolean NOT NULL,
        "Version" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_ServiceZone" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "ShareToken" (
        "Id" character varying(64) NOT NULL,
        "RideId" text NOT NULL,
        "TokenHash" text NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "RevokedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_ShareToken" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "SupportTicket" (
        "Id" character varying(64) NOT NULL,
        "RequesterId" text NOT NULL,
        "RideId" text,
        "ZoneId" text NOT NULL,
        "Subject" text NOT NULL,
        "Category" text NOT NULL,
        "Priority" text NOT NULL,
        "Status" text NOT NULL,
        "AssigneeId" text,
        "Version" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_SupportTicket" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "TicketMessage" (
        "Id" character varying(64) NOT NULL,
        "TicketId" text NOT NULL,
        "AuthorId" text NOT NULL,
        "Body" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_TicketMessage" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "User" (
        "Id" character varying(64) NOT NULL,
        "Phone" text NOT NULL,
        "Name" text NOT NULL,
        "Role" text NOT NULL,
        "ZoneId" text NOT NULL,
        "Status" text NOT NULL,
        "Email" text,
        "Version" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_User" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "LedgerEntry" (
        "Id" character varying(64) NOT NULL,
        "JournalId" character varying(64) NOT NULL,
        "Account" text NOT NULL,
        "OwnerId" text NOT NULL,
        "Debit" bigint NOT NULL,
        "Credit" bigint NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_LedgerEntry" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_LedgerEntry_Journal_JournalId" FOREIGN KEY ("JournalId") REFERENCES "Journal" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Driver" (
        "Id" character varying(64) NOT NULL,
        "UserId" character varying(64) NOT NULL,
        "ReviewStatus" text NOT NULL,
        "ServiceTypeCode" text NOT NULL,
        "Plate" text NOT NULL,
        "Vehicle" text NOT NULL,
        "Color" text NOT NULL,
        "ZoneId" text NOT NULL,
        "Online" boolean NOT NULL,
        "OfflineAfterRide" boolean NOT NULL,
        "ActiveSessionId" text,
        "HeartbeatAt" timestamp with time zone,
        "Latitude" double precision NOT NULL,
        "Longitude" double precision NOT NULL,
        "Accuracy" double precision NOT NULL,
        "LocationSequence" bigint NOT NULL,
        "LocationAt" timestamp with time zone,
        "DocumentsExpireAt" timestamp with time zone,
        "ReviewReason" text,
        "Rating" numeric NOT NULL,
        "Version" integer NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Driver" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Driver_User_UserId" FOREIGN KEY ("UserId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Session" (
        "Id" character varying(64) NOT NULL,
        "UserId" character varying(64) NOT NULL,
        "DeviceId" text NOT NULL,
        "RefreshHash" text NOT NULL,
        "Family" text NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "RevokedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Session" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Session_User_UserId" FOREIGN KEY ("UserId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Ride" (
        "Id" character varying(64) NOT NULL,
        "Code" text NOT NULL,
        "CustomerId" character varying(64) NOT NULL,
        "DriverId" character varying(64),
        "QuoteId" character varying(64) NOT NULL,
        "ZoneId" text NOT NULL,
        "ServiceTypeCode" text NOT NULL,
        "Status" text NOT NULL,
        "PickupNote" text NOT NULL,
        "Pickup" text NOT NULL,
        "Dropoff" text NOT NULL,
        "Fare" text NOT NULL,
        "PinHmac" text NOT NULL,
        "CustomerPinProtected" text NOT NULL,
        "PinAttempts" integer NOT NULL,
        "Version" integer NOT NULL,
        "DeadlineAt" timestamp with time zone NOT NULL,
        "ArrivedAt" timestamp with time zone,
        "EndedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Ride" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Ride_Driver_DriverId" FOREIGN KEY ("DriverId") REFERENCES "Driver" ("Id") ON DELETE RESTRICT,
        CONSTRAINT "FK_Ride_Quote_QuoteId" FOREIGN KEY ("QuoteId") REFERENCES "Quote" ("Id") ON DELETE RESTRICT,
        CONSTRAINT "FK_Ride_User_CustomerId" FOREIGN KEY ("CustomerId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Assignment" (
        "Id" character varying(64) NOT NULL,
        "RideId" character varying(64) NOT NULL,
        "DriverId" character varying(64) NOT NULL,
        "VehicleSnapshot" text NOT NULL,
        "EndedAt" timestamp with time zone,
        "EndReason" text,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Assignment" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Assignment_Driver_DriverId" FOREIGN KEY ("DriverId") REFERENCES "Driver" ("Id") ON DELETE RESTRICT,
        CONSTRAINT "FK_Assignment_Ride_RideId" FOREIGN KEY ("RideId") REFERENCES "Ride" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Offer" (
        "Id" character varying(64) NOT NULL,
        "RideId" character varying(64) NOT NULL,
        "DriverId" character varying(64) NOT NULL,
        "Status" text NOT NULL,
        "Version" integer NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Offer" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Offer_Driver_DriverId" FOREIGN KEY ("DriverId") REFERENCES "Driver" ("Id") ON DELETE RESTRICT,
        CONSTRAINT "FK_Offer_Ride_RideId" FOREIGN KEY ("RideId") REFERENCES "Ride" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "Payment" (
        "Id" character varying(64) NOT NULL,
        "RideId" character varying(64) NOT NULL,
        "DriverId" text NOT NULL,
        "PayableAmount" bigint NOT NULL,
        "PaidAmount" bigint NOT NULL,
        "Status" text NOT NULL,
        "Currency" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Payment" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Payment_Ride_RideId" FOREIGN KEY ("RideId") REFERENCES "Ride" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "RideEvent" (
        "Id" character varying(64) NOT NULL,
        "RideId" character varying(64) NOT NULL,
        "Sequence" integer NOT NULL,
        "EventType" text NOT NULL,
        "ActorId" text NOT NULL,
        "Reason" text,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_RideEvent" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_RideEvent_Ride_RideId" FOREIGN KEY ("RideId") REFERENCES "Ride" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE TABLE "CashCollection" (
        "Id" character varying(64) NOT NULL,
        "PaymentId" character varying(64) NOT NULL,
        "OperationId" text NOT NULL,
        "DriverId" text NOT NULL,
        "Amount" bigint NOT NULL,
        "Reason" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_CashCollection" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_CashCollection_Payment_PaymentId" FOREIGN KEY ("PaymentId") REFERENCES "Payment" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Assignment_DriverId" ON "Assignment" ("DriverId") WHERE "EndedAt" IS NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Assignment_RideId" ON "Assignment" ("RideId") WHERE "EndedAt" IS NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_CashCollection_OperationId" ON "CashCollection" ("OperationId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE INDEX "IX_CashCollection_PaymentId" ON "CashCollection" ("PaymentId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Driver_UserId" ON "Driver" ("UserId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_FarePolicy_ZoneId_ServiceTypeCode_Version" ON "FarePolicy" ("ZoneId", "ServiceTypeCode", "Version");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_IdempotencyRecord_ActorId_Scope_Key" ON "IdempotencyRecord" ("ActorId", "Scope", "Key");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Journal_OperationKey" ON "Journal" ("OperationKey");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE INDEX "IX_LedgerEntry_JournalId" ON "LedgerEntry" ("JournalId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Offer_DriverId" ON "Offer" ("DriverId") WHERE "Status" = 'OPEN';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Offer_RideId" ON "Offer" ("RideId") WHERE "Status" = 'OPEN';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Payment_RideId" ON "Payment" ("RideId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Rating_RideId_AuthorId" ON "Rating" ("RideId", "AuthorId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Ride_CustomerId" ON "Ride" ("CustomerId") WHERE "Status" IN ('SEARCHING','ASSIGNED','DRIVER_ARRIVED','IN_PROGRESS');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE INDEX "IX_Ride_CustomerId_CreatedAt_Id" ON "Ride" ("CustomerId", "CreatedAt", "Id");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE INDEX "IX_Ride_DriverId" ON "Ride" ("DriverId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Ride_QuoteId" ON "Ride" ("QuoteId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE INDEX "IX_Ride_Status_DeadlineAt" ON "Ride" ("Status", "DeadlineAt");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_RideEvent_RideId_Sequence" ON "RideEvent" ("RideId", "Sequence");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_Session_RefreshHash" ON "Session" ("RefreshHash");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE INDEX "IX_Session_UserId" ON "Session" ("UserId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_ShareToken_TokenHash" ON "ShareToken" ("TokenHash");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    CREATE UNIQUE INDEX "IX_User_Phone" ON "User" ("Phone");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043521_InitialSchema') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261103043521_InitialSchema', '10.0.14');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    ALTER TABLE "DriverDocument" ALTER COLUMN "DriverId" TYPE character varying(64);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    CREATE TABLE "LocationSample" (
        "Id" character varying(64) NOT NULL,
        "DriverId" text NOT NULL,
        "SessionId" text NOT NULL,
        "SampleId" text NOT NULL,
        "Sequence" bigint NOT NULL,
        "Latitude" double precision NOT NULL,
        "Longitude" double precision NOT NULL,
        "AccuracyMeters" double precision NOT NULL,
        "RecordedAt" timestamp with time zone NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_LocationSample" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    CREATE TABLE "PrivateFile" (
        "Id" character varying(64) NOT NULL,
        "OwnerId" character varying(64) NOT NULL,
        "Purpose" text NOT NULL,
        "ContentType" text NOT NULL,
        "Size" bigint NOT NULL,
        "Status" text NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_PrivateFile" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_PrivateFile_User_OwnerId" FOREIGN KEY ("OwnerId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    ALTER TABLE "Rating" ADD CONSTRAINT "CK_Rating_Stars" CHECK ("Stars" >= 1 AND "Stars" <= 5);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    ALTER TABLE "Payment" ADD CONSTRAINT "CK_Payment_Amounts" CHECK ("PayableAmount" >= 0 AND "PaidAmount" >= 0 AND "PaidAmount" <= "PayableAmount");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    ALTER TABLE "LedgerEntry" ADD CONSTRAINT "CK_Ledger_Sides" CHECK ("Debit" >= 0 AND "Credit" >= 0 AND NOT ("Debit" > 0 AND "Credit" > 0));
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    CREATE INDEX "IX_DriverDocument_DriverId" ON "DriverDocument" ("DriverId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    ALTER TABLE "CashCollection" ADD CONSTRAINT "CK_Cash_Amount" CHECK ("Amount" >= 0);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    CREATE UNIQUE INDEX "IX_LocationSample_DriverId_SessionId_SampleId" ON "LocationSample" ("DriverId", "SessionId", "SampleId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    CREATE INDEX "IX_PrivateFile_OwnerId" ON "PrivateFile" ("OwnerId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    ALTER TABLE "DriverDocument" ADD CONSTRAINT "FK_DriverDocument_Driver_DriverId" FOREIGN KEY ("DriverId") REFERENCES "Driver" ("Id") ON DELETE RESTRICT;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103043840_PrivateFilesAndIntegrity') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261103043840_PrivateFilesAndIntegrity', '10.0.14');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103050607_MobileOnboardingAndNoShow') THEN
    ALTER TABLE "DriverDocument" ADD "ReviewReason" text;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103050607_MobileOnboardingAndNoShow') THEN
    CREATE TABLE "RideContactAttempt" (
        "Id" character varying(64) NOT NULL,
        "RideId" character varying(64) NOT NULL,
        "DriverId" text NOT NULL,
        "Channel" text NOT NULL,
        "Note" text NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_RideContactAttempt" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_RideContactAttempt_Ride_RideId" FOREIGN KEY ("RideId") REFERENCES "Ride" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103050607_MobileOnboardingAndNoShow') THEN
    CREATE INDEX "IX_RideContactAttempt_RideId_DriverId_CreatedAt" ON "RideContactAttempt" ("RideId", "DriverId", "CreatedAt");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103050607_MobileOnboardingAndNoShow') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261103050607_MobileOnboardingAndNoShow', '10.0.14');
    END IF;
END $EF$;
COMMIT;

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    CREATE TABLE "AccountDeletionRequest" (
        "Id" character varying(64) NOT NULL,
        "UserId" character varying(64) NOT NULL,
        "ZoneId" text NOT NULL,
        "Status" text NOT NULL,
        "Reason" text NOT NULL,
        "ReviewNote" text,
        "ReviewerId" text,
        "TicketId" text NOT NULL,
        "Version" integer NOT NULL,
        "WithdrawnAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_AccountDeletionRequest" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_AccountDeletionRequest_User_UserId" FOREIGN KEY ("UserId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    CREATE TABLE "SavedPlace" (
        "Id" character varying(64) NOT NULL,
        "CustomerId" character varying(64) NOT NULL,
        "Label" text NOT NULL,
        "LabelKey" text NOT NULL,
        "Address" text NOT NULL,
        "Note" text NOT NULL,
        "Latitude" double precision NOT NULL,
        "Longitude" double precision NOT NULL,
        "Version" integer NOT NULL,
        "DeletedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_SavedPlace" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_SavedPlace_User_CustomerId" FOREIGN KEY ("CustomerId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    CREATE TABLE "TrustedContact" (
        "Id" character varying(64) NOT NULL,
        "UserId" character varying(64) NOT NULL,
        "Name" text NOT NULL,
        "PhoneProtected" text NOT NULL,
        "ConsentedAt" timestamp with time zone NOT NULL,
        "Version" integer NOT NULL,
        "DeletedAt" timestamp with time zone,
        "CreatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_TrustedContact" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_TrustedContact_User_UserId" FOREIGN KEY ("UserId") REFERENCES "User" ("Id") ON DELETE RESTRICT
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    CREATE UNIQUE INDEX "IX_AccountDeletionRequest_UserId" ON "AccountDeletionRequest" ("UserId") WHERE "Status" IN ('REQUESTED','BLOCKED_OBLIGATIONS','IN_REVIEW','NEEDS_INFORMATION');
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    CREATE UNIQUE INDEX "IX_SavedPlace_CustomerId_LabelKey" ON "SavedPlace" ("CustomerId", "LabelKey") WHERE "DeletedAt" IS NULL;
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    CREATE INDEX "IX_TrustedContact_UserId_DeletedAt" ON "TrustedContact" ("UserId", "DeletedAt");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261103053443_CustomerJourneyAndPrivacy') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261103053443_CustomerJourneyAndPrivacy', '10.0.14');
    END IF;
END $EF$;
COMMIT;

