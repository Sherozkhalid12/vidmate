import 'api_base.dart';

/// Ads API service (Magnite/SpotX integration)
class AdsApi extends ApiBase {
  // Request ad
  Future<Map<String, dynamic>> requestAd({
    required String adType, // 'banner', 'video', 'interstitial'
    String? placementId,
  }) async {
    return await get(
      '/ads/request',
      queryParams: {
        'type': adType,
        if (placementId != null) 'placementId': placementId,
      },
    );
  }

  // Track ad impression
  Future<Map<String, dynamic>> trackImpression(String adId) async {
    return await post('/ads/$adId/impression', {});
  }

  // Track ad click
  Future<Map<String, dynamic>> trackClick(String adId) async {
    return await post('/ads/$adId/click', {});
  }

  // Get CPM data
  Future<Map<String, dynamic>> getCpmData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await get(
      '/ads/cpm',
      queryParams: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }

  // Get revenue data
  Future<Map<String, dynamic>> getRevenueData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await get(
      '/ads/revenue',
      queryParams: {
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
  }
}

