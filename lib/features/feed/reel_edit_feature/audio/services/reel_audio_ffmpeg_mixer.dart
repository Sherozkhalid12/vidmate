import '../models/reel_audio_clip.dart';

/// Builds FFmpeg filter_complex segments for mixing timeline audio clips.
class ReelAudioFfmpegMixer {
  const ReelAudioFfmpegMixer._();

  /// Returns extra `-i` paths and audio filter graph to append to export args.
  static AudioMixPlan build({
    required List<ReelAudioClip> clips,
    required List<String> localPaths,
    required double exportDurationSec,
    required int firstAudioInputIndex,
    bool includeBaseVideoAudio = true,
  }) {
    if (clips.isEmpty || localPaths.length != clips.length) {
      return const AudioMixPlan(extraInputs: [], filterGraph: null, outputLabel: null);
    }

    final extraInputs = <String>[];
    final filters = <String>[];
    final mixLabels = <String>[];

    if (includeBaseVideoAudio) {
      filters.add('[0:a]volume=0.35[va]');
      mixLabels.add('[va]');
    }

    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final path = localPaths[i];
      if (path.isEmpty) continue;

      final inputIndex = firstAudioInputIndex + i;
      extraInputs.add(path);

      final delayMs = (clip.timelineOffsetSec * 1000).round();
      final trimStart = clip.sourceTrimStartSec;
      final trimDur = clip.clipDurationSec;
      final vol = clip.volume.toStringAsFixed(3);
      final label = 'aclip$i';

      final chain = StringBuffer('[$inputIndex:a]');
      chain.write('atrim=start=$trimStart:duration=${trimDur.toStringAsFixed(3)},');
      chain.write('asetpts=PTS-STARTPTS,');
      chain.write('volume=$vol,');
      chain.write('adelay=$delayMs|$delayMs');
      chain.write('[$label]');
      filters.add(chain.toString());
      mixLabels.add('[$label]');
    }

    if (mixLabels.isEmpty) {
      return AudioMixPlan(
        extraInputs: extraInputs,
        filterGraph: null,
        outputLabel: null,
      );
    }

    final inputs = mixLabels.length;
    filters.add(
      '${mixLabels.join()}amix=inputs=$inputs:duration=longest:dropout_transition=0[aout]',
    );

    return AudioMixPlan(
      extraInputs: extraInputs,
      filterGraph: filters.join(';'),
      outputLabel: '[aout]',
    );
  }
}

class AudioMixPlan {
  const AudioMixPlan({
    required this.extraInputs,
    required this.filterGraph,
    required this.outputLabel,
  });

  final List<String> extraInputs;
  final String? filterGraph;
  final String? outputLabel;

  bool get hasAudioMix => outputLabel != null && filterGraph != null;
}
