import '../domain/models.dart';

typedef Json = Map<String, dynamic>;
GrapUser userFromJson(Json j) => GrapUser(
  id: j['id'] as String,
  name: j['name'] as String,
  role: j['role'] as String,
);
Place placeFromJson(Json j) => Place(
  id: j['placeId'] as String? ?? '${j['latitude']},${j['longitude']}',
  address: j['address'] as String? ?? 'Vị trí tài xế',
  latitude: (j['latitude'] as num).toDouble(),
  longitude: (j['longitude'] as num).toDouble(),
);
Json placeToJson(Place p) => {
  'latitude': p.latitude,
  'longitude': p.longitude,
  'address': p.address,
};
Json positionToJson(PositionEvidence p) => {
  'latitude': p.latitude,
  'longitude': p.longitude,
  'accuracyMeters': p.accuracy,
  'recordedAt': p.recordedAt.toUtc().toIso8601String(),
  'sequence': p.sequence,
};
Fare fareFromJson(Json j) => Fare(
  payable: (j['customerPayable'] as num).toInt(),
  gross: (j['grossFare'] as num).toInt(),
  commission: (j['platformCommission'] as num).toInt(),
  base: (j['baseFare'] as num? ?? 0).toInt(),
  distance: (j['distanceFare'] as num? ?? 0).toInt(),
  duration: (j['durationFare'] as num? ?? 0).toInt(),
  serviceFee: (j['serviceFee'] as num? ?? 0).toInt(),
  discount: (j['discount'] as num? ?? 0).toInt(),
  extras: (j['approvedExtras'] as num? ?? 0).toInt(),
  tax: (j['taxComponent'] as num? ?? 0).toInt(),
);
RideSnapshot rideFromJson(Json j) {
  final d = j['driver'] as Json?, p = j['payment'] as Json?;
  return RideSnapshot(
    id: j['rideId'] as String,
    code: j['rideCode'] as String,
    status: j['status'] as String,
    service: j['serviceTypeCode'] as String,
    version: j['version'] as int,
    pickup: placeFromJson(j['pickup'] as Json),
    dropoff: placeFromJson(j['dropoff'] as Json),
    fare: fareFromJson(j['fare'] as Json),
    createdAt: DateTime.parse(j['createdAt'] as String),
    arrivedAt: j['arrivedAt'] == null
        ? null
        : DateTime.parse(j['arrivedAt'] as String),
    pickupPin: j['pickupPin'] as String?,
    driver: d == null
        ? null
        : DriverInfo(
            name: d['name'] as String,
            vehicle: d['vehicle'] as String,
            plate: d['plate'] as String,
            color: d['color'] as String,
            location: d['latitude'] == null || d['longitude'] == null
                ? null
                : placeFromJson(d),
            locationAt: d['locationAt'] == null
                ? null
                : DateTime.parse(d['locationAt'] as String),
          ),
    payment: p == null
        ? null
        : PaymentSnapshot(
            id: p['id'] as String,
            status: p['status'] as String,
            payable: (p['payableAmount'] as num).toInt(),
            paid: (p['paidAmount'] as num).toInt(),
          ),
  );
}
