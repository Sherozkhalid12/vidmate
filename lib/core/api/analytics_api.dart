import 'api_base.dart';

/// Analytics API service
class AnalyticsApi extends ApiBase {
  // Get daily active users
  Future<Map<String, dynamic>> getDailyActiveUsers({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await get(
      '/analytics/dau',
      queryParams: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }

  // Get views count (1M views calculation)
  Future<Map<String, dynamic>> getViewsCount({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await get(
      '/analytics/views',
      queryParams: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }

  // Get watch time
  Future<Map<String, dynamic>> getWatchTime({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await get(
      '/analytics/watch-time',
      queryParams: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }

  // Get retention data
  Future<Map<String, dynamic>> getRetention({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await get(
      '/analytics/retention',
      queryParams: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }

  // Get server load
  Future<Map<String, dynamic>> getServerLoad() async {
    return await get('/analytics/server-load');
  }

  // Get user analytics
  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    return await get('/analytics/users/$userId');
  }

  // Get content analytics
  Future<Map<String, dynamic>> getContentAnalytics(String contentId) async {
    return await get('/analytics/content/$contentId');
  }
}


