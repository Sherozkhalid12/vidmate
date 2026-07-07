import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/theme_helper.dart';
import 'reel_edit_feature/reel_edit_export_result.dart';
import 'reel_edit_feature/audio/models/reel_audio_clip.dart';
import 'reel_edit_feature/audio/providers/reel_audio_preview_provider.dart';
import 'reel_edit_feature/audio/providers/reel_audio_timeline_provider.dart';
import 'reel_edit_feature/audio/providers/reel_edit_playback_provider.dart';
import 'reel_edit_feature/audio/services/reel_audio_cache_service.dart';
import 'reel_edit_feature/audio/services/reel_audio_ffmpeg_mixer.dart';
import 'reel_edit_feature/audio/services/reel_audio_session_service.dart';
import 'reel_edit_feature/audio/widgets/reel_audio_timeline_panel.dart';

part 'reel_edit_feature/theme.dart';
part 'reel_edit_feature/models.dart';
part 'reel_edit_feature/state.dart';
part 'reel_edit_feature/export_progress_dialog.dart';
part 'reel_edit_feature/screen_state.dart';
part 'reel_edit_feature/interactive_layer.dart';
part 'reel_edit_feature/text_layer_widget.dart';
part 'reel_edit_feature/text_editor_dialog.dart';
part 'reel_edit_feature/sticker_picker.dart';
part 'reel_edit_feature/paint_panel.dart';
part 'reel_edit_feature/filter_panel.dart';
part 'reel_edit_feature/adjust_panel.dart';
part 'reel_edit_feature/crop_panel.dart';
part 'reel_edit_feature/trim_panel.dart';
part 'reel_edit_feature/layer_painter.dart';
part 'reel_edit_feature/crop_overlay.dart';
part 'reel_edit_feature/vignette_overlay.dart';
part 'reel_edit_feature/shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ReelEditScreen extends ConsumerStatefulWidget {
  /// Video (reel / long) or a single photo (story image mode).
  final File mediaFile;
  /// When true: static image editor — no trim, no playback; export is a PNG composite.
  final bool isImageMode;

  const ReelEditScreen({
    super.key,
    required this.mediaFile,
    this.isImageMode = false,
  });

  @override
  ConsumerState<ReelEditScreen> createState() => _ReelEditScreenState();
}
