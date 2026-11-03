using GrapSolution.Application;
using GrapSolution.Domain;
using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Infrastructure;
public static class Seed
{
    public static async Task Development(GrapDbContext db, ISecrets secrets)
    {
        if (await db.Set<User>().AnyAsync()) return;
        db.Add(new ServiceZone { Id = "hcm", Name = "TP. Hồ Chí Minh", PolygonJson = "[[106.55,10.65],[106.9,10.65],[106.9,10.95],[106.55,10.95]]" });
        foreach (var (code, name, baseFare, perKm, minimum) in new[] { ("BIKE", "GrapBike", 12000L, 4500L, 15000L), ("CAR_4", "GrapCar 4 chỗ", 22000L, 10000L, 30000L), ("CAR_7", "GrapCar 7 chỗ", 28000L, 13000L, 40000L) }) db.Add(new FarePolicy { Id = "fare-" + code, ServiceTypeCode = code, Name = name, BaseFare = baseFare, PerKm = perKm, MinimumFare = minimum, Status = "PUBLISHED", EffectiveFrom = DateTime.UtcNow.AddDays(-30), CreatedBy = "seed" });
        foreach (var (role, name, suffix) in new[] { (Roles.Operations, "Nguyễn Minh Anh", "01"), (Roles.Dispatcher, "Trần Khánh Linh", "02"), (Roles.Reviewer, "Lê Hoàng Nam", "03"), (Roles.Support, "Phạm Thảo Vy", "04"), (Roles.Finance, "Nguyễn Hải Yến", "05"), (Roles.Approver, "Đặng Quốc Bảo", "06"), (Roles.Security, "Võ Minh Khang", "07") }) db.Add(new User { Id = "staff-" + role, Phone = "+849000000" + suffix, Name = name, Role = role });
        string[] names = ["Nguyễn Văn Hùng", "Trần Minh Tuấn", "Lê Quốc Bảo", "Phạm Hoàng Nam", "Võ Đức Anh", "Đặng Minh Khoa", "Bùi Thanh Tùng", "Đỗ Quang Huy", "Hồ Anh Dũng", "Ngô Văn Phúc", "Dương Thành Đạt", "Lý Minh Nhật"];
        for (var i = 0; i < names.Length; i++)
        {
            db.Add(new User { Id = "driver-user-" + i, Phone = "+84910000" + i.ToString("000"), Name = names[i], Role = Roles.Driver });
            db.Add(new Driver { Id = "driver-" + i, UserId = "driver-user-" + i, ReviewStatus = i < 9 ? "APPROVED" : "PENDING_REVIEW", ServiceTypeCode = i % 3 == 0 ? "BIKE" : i % 3 == 1 ? "CAR_4" : "CAR_7", Plate = i % 3 == 0 ? $"59-S2 {12340 + i}" : $"51H-{45600 + i}", Vehicle = i % 3 == 0 ? "Honda Air Blade" : i % 3 == 1 ? "Toyota Vios" : "Mitsubishi Xpander", Color = i % 3 == 0 ? "Đen" : "Trắng", Latitude = 10.771 + i * 0.003, Longitude = 106.694 + i * 0.002, LocationAt = DateTime.UtcNow.AddMinutes(-15), DocumentsExpireAt = DateTime.UtcNow.AddYears(1), Rating = 4.7m + (i % 4) * 0.1m });
        }
        string[] customers = ["Trần Ngọc Hà", "Nguyễn Bảo An", "Lê Minh Châu", "Phạm Gia Hân", "Võ Thanh Bình", "Đặng Thiên Ân", "Bùi Hoàng Yến", "Đỗ Tuấn Kiệt"];
        for (var i = 0; i < customers.Length; i++) db.Add(new User { Id = "customer-" + i, Phone = "+84920000" + i.ToString("000"), Name = customers[i], Role = Roles.Customer, CreatedAt = DateTime.UtcNow.AddDays(-i * 3) });
        await db.SaveChangesAsync();
        for (var i = 0; i < 48; i++)
        {
            var created = DateTime.UtcNow.Date.AddHours(-7).AddDays(-(i / 8)).AddHours(7 + i % 8 * 1.5); if (created > DateTime.UtcNow) created = DateTime.UtcNow.AddMinutes(-20 - i * 4);
            var service = i % 3 == 0 ? "BIKE" : i % 3 == 1 ? "CAR_4" : "CAR_7"; var policy = db.Set<FarePolicy>().Local.Single(p => p.ServiceTypeCode == service); var fare = policy.Calculate(6300, 1200); var pickup = DemoMapProvider.Places[0].Point; var dropoff = DemoMapProvider.Places[1].Point;
            var quote = new Quote { CustomerId = "customer-" + i % 8, Pickup = pickup, Dropoff = dropoff, ServiceTypeCode = service, FarePolicyId = policy.Id, FarePolicyVersion = 1, Fare = fare, RouteSource = "DEVELOPMENT_FIXTURE", CreatedAt = created, ExpiresAt = created.AddMinutes(2), DistanceMeters = 6300, DurationSeconds = 1200 };
            var canceled = i % 9 == 0; var ride = new Ride { QuoteId = quote.Id, CustomerId = quote.CustomerId, DriverId = canceled ? null : "driver-" + i % 9, ServiceTypeCode = service, Fare = fare, Pickup = pickup, Dropoff = dropoff, Status = canceled ? "CANCELED" : "COMPLETED", CreatedAt = created, EndedAt = created.AddMinutes(20), Version = canceled ? 2 : 5, PinHmac = secrets.Hmac("0000"), CustomerPinProtected = secrets.Protect("0000") }; quote.ConsumedRideId = ride.Id; db.Add(quote); db.Add(ride);
            db.Add(new RideEvent { RideId = ride.Id, Sequence = 1, EventType = "Đã tạo chuyến (dữ liệu mẫu)", ActorId = ride.CustomerId, CreatedAt = created }); db.Add(new RideEvent { RideId = ride.Id, Sequence = ride.Version, EventType = ride.Status, ActorId = "seed", CreatedAt = created.AddMinutes(20) });
            if (!canceled)
            {
                db.Add(new Assignment { RideId = ride.Id, DriverId = ride.DriverId!, CreatedAt = created, EndedAt = ride.EndedAt, EndReason = "COMPLETED" }); var paid = i % 7 != 0;
                var payment = new Payment { RideId = ride.Id, DriverId = ride.DriverId!, PayableAmount = fare.CustomerPayable, PaidAmount = paid ? fare.CustomerPayable : 0, Status = paid ? "SUCCEEDED" : "PENDING", CreatedAt = created }; db.Add(payment);
                var entitlement = new Journal { RideId = ride.Id, OperationKey = ride.Id + ":entitlement", Description = "Nghĩa vụ chuyến mẫu", CreatedAt = created, Entries = [new() { Account = "CUSTOMER_RECEIVABLE", OwnerId = ride.CustomerId, Debit = fare.CustomerPayable }, new() { Account = "DRIVER_PAYABLE", OwnerId = ride.DriverId!, Credit = fare.GrossFare - fare.PlatformCommission }, new() { Account = "PLATFORM_FEES", Credit = fare.PlatformCommission }] }; db.Add(entitlement);
                if (paid) { db.Add(new CashCollection { PaymentId = payment.Id, DriverId = ride.DriverId!, OperationId = "seed-" + ride.Id, Amount = fare.CustomerPayable, Reason = "SEED_DEMO", CreatedAt = created }); db.Add(new Journal { RideId = ride.Id, OperationKey = "cash:seed-" + ride.Id, Description = "Thu tiền mặt mẫu", CreatedAt = created, Entries = [new() { Account = "DRIVER_PAYABLE", OwnerId = ride.DriverId!, Debit = fare.CustomerPayable }, new() { Account = "CUSTOMER_RECEIVABLE", OwnerId = ride.CustomerId, Credit = fare.CustomerPayable }] }); }
            }
        }
        string[] subjects = ["Cần hỗ trợ tìm đồ để quên trên xe", "Chưa được xác nhận thanh toán tiền mặt", "Bổ sung giấy tờ đăng ký xe", "Góp ý về điểm đón tại sân bay", "Yêu cầu kiểm tra lại biên nhận"];
        for (var i = 0; i < subjects.Length; i++) { var t = new SupportTicket { RequesterId = "customer-" + i, Subject = subjects[i], Category = i == 1 ? "PAYMENT" : "OTHER", Priority = i == 1 ? "HIGH" : "NORMAL", Status = i < 2 ? "OPEN" : "IN_PROGRESS", CreatedAt = DateTime.UtcNow.AddHours(-i - 1) }; db.Add(t); db.Add(new TicketMessage { TicketId = t.Id, AuthorId = t.RequesterId, Body = subjects[i] + ". Nhờ đội ngũ hỗ trợ kiểm tra giúp tôi." }); }
        db.Add(new AuditLog { ActorId = "seed", ActorName = "Hệ thống", Action = "development.seed", ResourceId = "hcm", Reason = "Khởi tạo dữ liệu minh họa local; không phải số liệu vận hành thật." });
        await db.SaveChangesAsync();
    }
}
