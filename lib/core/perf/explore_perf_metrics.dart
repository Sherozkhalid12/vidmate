import 'package:flutter/foundation.dart';

/// Debug traces for explore grid and search (Feature 4.9).
class ExplorePerfMetrics {
  ExplorePerfMetrics._();

  static void logExploreGridPaintMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] explore_grid_paint_ms=$ms');
    }
  }

  static void logSearchResultsMs(int ms) {
    if (kDebugMode) {
      debugPrint('[perf] explore_search_results_ms=$ms');
    }
  }
}
