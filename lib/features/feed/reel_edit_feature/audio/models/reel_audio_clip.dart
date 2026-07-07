import 'package:flutter/foundation.dart';

/// Type of audio placed on the reel timeline.
enum ReelAudioClipType { music, soundEffect, voiceover }

/// A single audio segment positioned on the video timeline.
@immutable
class ReelAudioClip {
  const ReelAudioClip({
    required this.id,
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.sourceUrl,
    this.localFilePath,
    this.type = ReelAudioClipType.music,
    this.timelineOffsetSec = 0,
    this.sourceTrimStartSec = 0,
    required this.sourceDurationSec,
    this.sourceTrimEndSec,
    this.volume = 1.0,
    this.waveformSamples = const [],
  });

  final String id;
  final String trackId;
  final String title;
  final String subtitle;
  final String sourceUrl;
  final String? localFilePath;
  final ReelAudioClipType type;

  /// Offset from the trimmed video start, in seconds.
  final double timelineOffsetSec;

  /// Trim window inside the source file, in seconds.
  final double sourceTrimStartSec;
  final double sourceDurationSec;
  final double? sourceTrimEndSec;

  final double volume;

  /// Normalized amplitudes (0..1) for waveform rendering.
  final List<double> waveformSamples;

  double get effectiveTrimEndSec =>
      sourceTrimEndSec ?? sourceDurationSec.clamp(sourceTrimStartSec, double.infinity);

  double get clipDurationSec =>
      (effectiveTrimEndSec - sourceTrimStartSec).clamp(0, double.infinity);

  double get timelineEndSec => timelineOffsetSec + clipDurationSec;

  String get displayLabel {
    if (title.isNotEmpty && subtitle.isNotEmpty) return '$title | $subtitle';
    return title.isNotEmpty ? title : subtitle;
  }

  ReelAudioClip copyWith({
    String? id,
    String? trackId,
    String? title,
    String? subtitle,
    String? sourceUrl,
    String? localFilePath,
    bool clearLocalFilePath = false,
    ReelAudioClipType? type,
    double? timelineOffsetSec,
    double? sourceTrimStartSec,
    double? sourceDurationSec,
    double? sourceTrimEndSec,
    bool clearSourceTrimEnd = false,
    double? volume,
    List<double>? waveformSamples,
  }) {
    return ReelAudioClip(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localFilePath:
          clearLocalFilePath ? null : (localFilePath ?? this.localFilePath),
      type: type ?? this.type,
      timelineOffsetSec: timelineOffsetSec ?? this.timelineOffsetSec,
      sourceTrimStartSec: sourceTrimStartSec ?? this.sourceTrimStartSec,
      sourceDurationSec: sourceDurationSec ?? this.sourceDurationSec,
      sourceTrimEndSec:
          clearSourceTrimEnd ? null : (sourceTrimEndSec ?? this.sourceTrimEndSec),
      volume: volume ?? this.volume,
      waveformSamples: waveformSamples ?? this.waveformSamples,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'title': title,
        'subtitle': subtitle,
        'sourceUrl': sourceUrl,
        'localFilePath': localFilePath,
        'type': type.name,
        'timelineOffsetSec': timelineOffsetSec,
        'sourceTrimStartSec': sourceTrimStartSec,
        'sourceDurationSec': sourceDurationSec,
        'sourceTrimEndSec': sourceTrimEndSec,
        'volume': volume,
      };

  factory ReelAudioClip.fromPickerMap(
    Map<String, dynamic> map, {
    required double videoDurationSec,
    ReelAudioClipType type = ReelAudioClipType.music,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final title = (map['musicName'] ?? map['name'] ?? '').toString();
    final subtitle = (map['musicTitle'] ?? '').toString();
    final url = (map['audioUrl'] ?? map['previewUrl'] ?? '').toString();
    final trackId = (map['id'] ?? id).toString();
    const defaultClipLen = 30.0;
    final clipLen = videoDurationSec > 0
        ? videoDurationSec.clamp(1, defaultClipLen)
        : defaultClipLen;

    return ReelAudioClip(
      id: id,
      trackId: trackId,
      title: title,
      subtitle: subtitle,
      sourceUrl: url,
      type: type,
      sourceDurationSec: defaultClipLen,
      sourceTrimEndSec: clipLen.toDouble(),
      waveformSamples: generatePseudoWaveform(trackId),
    );
  }
}

/// Lightweight pseudo-waveform until real analysis is available.
List<double> generatePseudoWaveform(String seed, {int bars = 48}) {
  var hash = seed.hashCode;
  return List<double>.generate(bars, (i) {
    hash = (hash * 31 + i) & 0x7fffffff;
    return 0.15 + (hash % 100) / 100 * 0.85;
  });
}
