using GrapSolution.Domain;
using GrapSolution.Application;
using Xunit;
namespace GrapSolution.Tests;
public sealed class DomainTests
{
    [Fact] public void Fare_uses_integer_vnd_and_explicit_rounding() { var p = new FarePolicy { BaseFare = 12000, PerKm = 4500, PerMinute = 300, ServiceFee = 2000, MinimumFare = 15000, CommissionRate = .2m }; var f = p.Calculate(6300, 1200); Assert.Equal(48350, f.CustomerPayable); Assert.Equal(9270, f.PlatformCommission); }
    [Fact] public void Fare_enforces_minimum_before_service_fee() { var p = new FarePolicy { BaseFare = 1000, PerKm = 0, PerMinute = 0, MinimumFare = 15000, ServiceFee = 2000 }; Assert.Equal(17000, p.Calculate(100, 60).GrossFare); }
    [Theory] [InlineData("COMPLETED")] [InlineData("CANCELED")] [InlineData("NO_DRIVER")] [InlineData("EXPIRED")] public void Terminal_states_cannot_start(string status) { Assert.False(RideStates.IsActive(status)); Assert.Throws<RuleException>(() => RideStates.Require(status, "DRIVER_ARRIVED")); }
    [Fact] public void Version_conflicts_expose_current_version() { var ex = Assert.Throws<RuleException>(() => new Ride { Version = 5 }.CheckVersion(4)); Assert.Equal("VERSION_CONFLICT", ex.Code); Assert.Equal(5, ex.CurrentVersion); }
    [Fact] public void Ledger_rejects_unbalanced_journal() { var journal = new Journal { Entries = [new() { Debit = 100 }, new() { Credit = 99 }] }; Assert.Throws<RuleException>(journal.Validate); }
    [Fact] public void Ledger_rejects_negative_amounts() { var journal = new Journal { Entries = [new() { Debit = -100 }, new() { Credit = -100 }] }; Assert.Throws<RuleException>(journal.Validate); }
    [Fact] public void Ledger_allows_balanced_double_entry() { new Journal { Entries = [new() { Debit = 60000 }, new() { Credit = 50000 }, new() { Credit = 10000 }] }.Validate(); }
    [Fact] public void Zone_polygon_checks_inside_and_outside() { const string zone = "[[106.55,10.65],[106.9,10.65],[106.9,10.95],[106.55,10.95]]"; Assert.True(RideService.Contains(zone, new(10.7721, 106.6983, "HCM"))); Assert.False(RideService.Contains(zone, new(21.0285, 105.8542, "Hà Nội"))); }
    [Theory] [InlineData(91, 100)] [InlineData(20, 181)] [InlineData(double.NaN, 100)] public void Coordinates_must_be_finite_and_in_range(double lat, double lon) => Assert.Throws<RuleException>(() => new GeoPoint(lat, lon, "Điểm").Validate());
    [Fact] public void Phone_is_masked() => Assert.Equal("+84 ••• 000", RideService.Mask("+84920000000"));
}
