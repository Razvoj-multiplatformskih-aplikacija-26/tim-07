import '../ids.dart';
import '../models/occupancy.dart';

abstract interface class StatisticsRepository {
  Future<OccupancyReport> getOccupancy({required StatsPeriod period, UserId? ownerId});
}
