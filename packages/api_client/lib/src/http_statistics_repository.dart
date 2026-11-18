import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';

import 'api_client.dart';

/// Zauzetost terena računa server (odluka 14), klijent samo prikazuje.
final class HttpStatisticsRepository implements StatisticsRepository {
  const HttpStatisticsRepository(this._api);

  final ApiClient _api;

  /// `ownerId` se ne šalje: vlasnik dobija svoje terene, a administrator sve,
  /// prema tokenu. Period se šalje kao vrsta i dan koji ga određuje.
  @override
  Future<OccupancyReport> getOccupancy({
    required StatsPeriod period,
    UserId? ownerId,
  }) async {
    final json = await _api.get(
      ApiPaths.stats,
      query: {
        ApiQuery.period: statsPeriodToCode(period.kind),
        ApiQuery.day: dateToJson(
          period.from.year,
          period.from.month,
          period.from.day,
        ),
      },
    );
    return readBody(json, (o) => OccupancyReportDto.fromJson(o).toDomain());
  }
}
