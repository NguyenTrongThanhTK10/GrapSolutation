import '../domain/models.dart';
import '../domain/statistics.dart';
import '../network/api_client.dart';

class ApiStatisticsRepository implements StatisticsRepository {
  final ApiClient client;
  ApiStatisticsRepository(this.client);

  @override
  Future<RideStatistics> load(StatisticsPeriod period) async {
    if (period.from.isAfter(period.to) ||
        period.to.difference(period.from).inDays >= 366 ||
        period.to.isAfter(StatisticsPeriod.businessToday())) {
      throw const Failure(
        'VALIDATION_ERROR',
        'Chọn khoảng tối đa 366 ngày, không vượt quá hôm nay.',
      );
    }
    final query = Uri(
      queryParameters: {'from': period.fromDate, 'to': period.toDate},
    ).query;
    final result = await client.request(
      '/me/ride-statistics?$query',
    ) as Map<String, dynamic>;
    return RideStatistics.fromJson(result);
  }
}
