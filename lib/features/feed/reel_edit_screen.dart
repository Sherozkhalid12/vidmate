import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/theme_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REEL EDIT THEME – app theme on black background, bluish accent, nothing hides
// ═══════════════════════════════════════════════════════════════════════════

class _ReelEditThemeData {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color accent;
  final Color accentAlt;
  final Color textPrim;
  final Color textSec;
  final Color textDim;

  const _ReelEditThemeData({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.accent,
    required this.accentAlt,
    required this.textPrim,
    required this.textSec,
    required this.textDim,
  });
}

class _ReelEditTheme extends InheritedWidget {
  const _ReelEditTheme({required this.data, required super.child});
  final _ReelEditThemeData data;

  static _ReelEditThemeData _fallback() => const _ReelEditThemeData(
    bg: Colors.black,
    surface: Color(0xFF1E293B),
    surface2: Color(0xFF334155),
    border: Color(0xFF475569),
    accent: Color(0xFF60A5FA),
    accentAlt: Color(0xFFF87171),
    textPrim: Colors.white,
    textSec: Color(0xFFB0BEC5),
    textDim: Color(0xFF78909C),
  );

  static _ReelEditThemeData of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<_ReelEditTheme>();
    return t?.data ?? _fallback();
  }

  @override
  bool updateShouldNotify(_ReelEditTheme old) => data != old.data;
}

class _DS {
  _DS._();

  static TextStyle label(
      BuildContext context, {
        double size = 10,
        Color? color,
        FontWeight? weight,
      }) {
    final d = _ReelEditTheme.of(context);
    return TextStyle(
      fontSize: size,
      color: color ?? d.textSec,
      fontWeight: weight ?? FontWeight.w500,
      letterSpacing: 1.2,
      fontFamily: 'monospace',
    );
  }

  static TextStyle heading(BuildContext context,
      {double size = 13, Color? color}) {
    final d = _ReelEditTheme.of(context);
    return TextStyle(
      fontSize: size,
      color: color ?? d.textPrim,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
  }

  static BoxDecoration pill(BuildContext context,
      {Color? bg, Color? borderColor}) {
    final d = _ReelEditTheme.of(context);
    return BoxDecoration(
      color: bg ?? d.surface2,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: borderColor ?? d.border, width: 1),
    );
  }

  static BoxDecoration activePill(BuildContext context) {
    final d = _ReelEditTheme.of(context);
    return BoxDecoration(
      color: d.accent.withOpacity(0.18),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: d.accent, width: 1),
    );
  }

  static Future<void> hapticLight() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> hapticMedium() async {
    await HapticFeedback.mediumImpact();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LAYER MODELS
// ═══════════════════════════════════════════════════════════════════════════

abstract class _Layer {
  Offset position;
  double scale;
  double rotation;
  bool selected;
  final String id;

  _Layer({
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.selected = false,
  }) : id =
  '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(10000)}';

  _Layer copyWith();
}

class _TextLayer extends _Layer {
  String text;
  Color color;
  Color? bgColor;
  double fontSize;
  FontWeight fontWeight;
  TextAlign align;
  _TextStyle style;

  _TextLayer({
    required super.position,
    required this.text,
    required this.color,
    this.bgColor,
    required this.fontSize,
    this.fontWeight = FontWeight.bold,
    this.align = TextAlign.center,
    this.style = _TextStyle.plain,
    super.scale,
    super.rotation,
    super.selected,
  });

  @override
  _TextLayer copyWith() => _TextLayer(
    position: position,
    text: text,
    color: color,
    bgColor: bgColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    align: align,
    style: style,
    scale: scale,
    rotation: rotation,
    selected: selected,
  );
}

enum _TextStyle { plain, filled, outlined, neon }

class _StickerLayer extends _Layer {
  String emoji;
  double size;

  _StickerLayer({
    required super.position,
    required this.emoji,
    required this.size,
    super.scale,
    super.rotation,
    super.selected,
  });

  @override
  _StickerLayer copyWith() => _StickerLayer(
    position: position,
    emoji: emoji,
    size: size,
    scale: scale,
    rotation: rotation,
    selected: selected,
  );
}

class _DrawLayer extends _Layer {
  List<Offset?> points;
  Color color;
  double strokeWidth;
  _BrushType brush;

  _DrawLayer({
    required super.position,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.brush = _BrushType.pen,
    super.scale,
    super.rotation,
    super.selected,
  });

  @override
  _DrawLayer copyWith() => _DrawLayer(
    position: position,
    points: List.from(points),
    color: color,
    strokeWidth: strokeWidth,
    brush: brush,
    scale: scale,
    rotation: rotation,
    selected: selected,
  );
}

enum _BrushType { pen, marker, neon, eraser }

// ═══════════════════════════════════════════════════════════════════════════
// FILTER DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════

class _FilterDef {
  final String name;
  final List<double>? matrix;
  final double blur;
  final String? ffmpegFilter;

  const _FilterDef({
    required this.name,
    this.matrix,
    this.blur = 0,
    this.ffmpegFilter,
  });

  ColorFilter? get colorFilter =>
      matrix != null ? ColorFilter.matrix(matrix!) : null;
}

const _filters = <_FilterDef>[
  _FilterDef(name: 'RAW'),
  _FilterDef(
    name: 'LUMEN',
    matrix: [
      1.1, 0.05, 0.0, 0, 15,
      0.0, 1.05, 0.05, 0, 10,
      0.0, 0.0, 0.9, 0, 5,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'eq=brightness=0.06:contrast=1.05:saturation=1.1',
  ),
  _FilterDef(
    name: 'ARGENT',
    matrix: [
      0.45, 0.55, 0.10, 0, 0,
      0.45, 0.55, 0.10, 0, 0,
      0.45, 0.55, 0.10, 0, 0,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131',
  ),
  _FilterDef(
    name: 'CHROME',
    matrix: [
      1.3, 0.0, 0.0, 0, -20,
      0.0, 1.0, 0.0, 0, -10,
      0.0, 0.0, 0.8, 0, 5,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'eq=contrast=1.3:saturation=1.2:brightness=-0.05',
  ),
  _FilterDef(
    name: 'AMBER',
    matrix: [
      1.2, 0.1, 0.0, 0, 20,
      0.0, 0.95, 0.0, 0, 10,
      0.0, 0.0, 0.65, 0, -10,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'colorbalance=rs=0.2:gs=0.1:bs=-0.2',
  ),
  _FilterDef(
    name: 'JADE',
    matrix: [
      0.7, 0.1, 0.0, 0, -5,
      0.1, 1.1, 0.1, 0, 10,
      0.0, 0.1, 0.9, 0, 0,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'colorbalance=rs=-0.2:gs=0.2:bs=0.1',
  ),
  _FilterDef(
    name: 'DUSK',
    matrix: [
      0.85, 0.0, 0.15, 0, 5,
      0.0, 0.75, 0.1, 0, -5,
      0.1, 0.0, 1.1, 0, 15,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'colorbalance=rs=0.1:gs=-0.1:bs=0.2',
  ),
  _FilterDef(
    name: 'COAL',
    matrix: [
      0.9, 0.05, 0.05, 0, -15,
      0.05, 0.9, 0.05, 0, -15,
      0.05, 0.05, 0.9, 0, -15,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'eq=brightness=-0.08:contrast=0.95:saturation=0.9',
  ),
  _FilterDef(
    name: 'BLOOM',
    matrix: [
      1.0, 0.0, 0.05, 0, 20,
      0.05, 1.05, 0.0, 0, 15,
      0.0, 0.0, 1.0, 0, 20,
      0, 0, 0, 1, 0,
    ],
    blur: 0.3,
    ffmpegFilter: 'eq=brightness=0.08:saturation=1.05,gblur=sigma=0.5',
  ),
  _FilterDef(
    name: 'VOID',
    matrix: [
      0.2, 0.2, 0.2, 0, -30,
      0.2, 0.2, 0.2, 0, -30,
      0.2, 0.2, 0.2, 0, -30,
      0, 0, 0, 1, 0,
    ],
    ffmpegFilter: 'eq=brightness=-0.15:saturation=0.2',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// ASPECT RATIOS
// ═══════════════════════════════════════════════════════════════════════════

class _AspectRatioDef {
  final String label;
  final double? ratio;
  const _AspectRatioDef(this.label, this.ratio);
}

const _aspectRatios = <_AspectRatioDef>[
  _AspectRatioDef('FREE', null),
  _AspectRatioDef('1:1', 1.0),
  _AspectRatioDef('4:5', 4 / 5),
  _AspectRatioDef('9:16', 9 / 16),
  _AspectRatioDef('16:9', 16 / 9),
  _AspectRatioDef('3:4', 3 / 4),
  _AspectRatioDef('2:3', 2 / 3),
];

// ═══════════════════════════════════════════════════════════════════════════
// TOOL ENUM
// ═══════════════════════════════════════════════════════════════════════════

enum _Tool { none, paint, text, sticker, filter, adjust, crop, trim }

// ═══════════════════════════════════════════════════════════════════════════
// EDITOR STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EditorState extends ChangeNotifier {
  _Tool _activeTool = _Tool.none;
  _Tool get activeTool => _activeTool;
  set activeTool(_Tool v) {
    if (_activeTool != v) {
      _activeTool = v;
      notifyListeners();
    }
  }

  int _filterIndex = 0;
  int get filterIndex => _filterIndex;
  set filterIndex(int v) {
    if (_filterIndex != v) {
      _filterIndex = v;
      notifyListeners();
    }
  }

  double brightness = 0.0;
  double contrast = 1.0;
  double saturation = 1.0;
  double warmth = 0.0;
  double blur = 0.0;
  double vignette = 0.0;
  double sharpness = 0.0;

  int aspectRatioIndex = 0;
  Rect cropRect = const Rect.fromLTWH(0, 0, 1, 1);

  double trimStart = 0.0;
  double trimEnd = 1.0;

  void notifyAdjustmentChanged() => notifyListeners();
}

class _BrushState extends ChangeNotifier {
  Color _color = const Color(0xFFE8FF47);
  double _size = 5.0;
  _BrushType _type = _BrushType.pen;

  Color get color => _color;
  set color(Color v) {
    if (_color != v) {
      _color = v;
      notifyListeners();
    }
  }

  double get size => _size;
  set size(double v) {
    if (_size != v) {
      _size = v;
      notifyListeners();
    }
  }

  _BrushType get type => _type;
  set type(_BrushType v) {
    if (_type != v) {
      _type = v;
      notifyListeners();
    }
  }
}

class _LayerState extends ChangeNotifier {
  final List<_Layer> _layers = [];
  final List<List<_Layer>> _history = [];
  int? _selectedIndex;

  List<_Layer> get layers => List.unmodifiable(_layers);
  int? get selectedIndex => _selectedIndex;
  bool get canUndo => _history.isNotEmpty;
  bool get hasLayers => _layers.isNotEmpty;

  set selectedIndex(int? v) {
    if (_selectedIndex != v) {
      _selectedIndex = v;
      notifyListeners();
    }
  }

  void saveHistory() {
    _history.add(_layers.map((l) => l.copyWith()).toList());
    if (_history.length > 30) _history.removeAt(0);
  }

  void undo() {
    if (_history.isEmpty) return;
    _layers
      ..clear()
      ..addAll(_history.removeLast());
    _selectedIndex = null;
    notifyListeners();
  }

  void addLayer(_Layer layer) {
    saveHistory();
    _layers.add(layer);
    notifyListeners();
  }

  void updateLayer(int index, _Layer layer) {
    if (index >= 0 && index < _layers.length) {
      _layers[index] = layer;
      notifyListeners();
    }
  }

  void removeLayer(int index) {
    if (index >= 0 && index < _layers.length) {
      saveHistory();
      _layers.removeAt(index);
      _selectedIndex = null;
      notifyListeners();
    }
  }

  void updateLayerTransform(int index,
      {Offset? position, double? scale, double? rotation}) {
    if (index >= 0 && index < _layers.length) {
      final layer = _layers[index];
      if (position != null) layer.position = position;
      if (scale != null) layer.scale = scale;
      if (rotation != null) layer.rotation = rotation;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedIndex = null;
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXPORT PROGRESS DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _ExportProgressDialog extends StatefulWidget {
  final Stream<double> progressStream;
  final Stream<String> statusStream;
  final bool isImageExport;

  const _ExportProgressDialog({
    required this.progressStream,
    required this.statusStream,
    this.isImageExport = false,
  });

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _status = 'Preparing...';
  late AnimationController _pulseController;
  StreamSubscription<double>? _progressSub;
  StreamSubscription<String>? _statusSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _progressSub = widget.progressStream.listen((progress) {
      if (mounted) setState(() => _progress = progress);
    });
    _statusSub = widget.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _statusSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _ReelEditTheme.of(context);
    final accent = ThemeHelper.getAccentColor(context);
    final title = widget.isImageExport ? 'Saving image' : 'Exporting video';
    final icon = widget.isImageExport ? Icons.image_outlined : Icons.movie_creation_outlined;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                d.surface,
                Color.lerp(d.surface, d.bg, 0.35)!,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.22), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12 + _pulseController.value * 0.08),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(icon, color: accent, size: 28),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: d.textPrim,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: TextStyle(
                  color: d.textSec,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress.clamp(0.0, 1.0) : null,
                  minHeight: 8,
                  backgroundColor: d.border.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _progress > 0 ? '${(_progress * 100).clamp(0, 100).toInt()}%' : '…',
                style: TextStyle(
                  color: d.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ReelEditScreen extends StatefulWidget {
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
  State<ReelEditScreen> createState() => _ReelEditScreenState();
}

class _ReelEditScreenState extends State<ReelEditScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late final AnimationController _toolPanelAnim;

  late final _EditorState _editorState;
  late final _BrushState _brushState;
  late final _LayerState _layerState;
  late final ValueNotifier<bool> _isPlaying;
  late final ValueNotifier<bool> _isInitializing;
  late final ValueNotifier<List<Offset?>> _currentStroke;

  bool _isExporting = false;

  final _overlayKey = GlobalKey();
  final _fullImageExportKey = GlobalKey();
  final _videoContainerKey = GlobalKey();

  /// Pixel dimensions of [mediaFile] when [isImageMode].
  double? _imagePixelW;
  double? _imagePixelH;

  Size _videoDisplaySize = Size.zero;

  @override
  void initState() {
    super.initState();

    _editorState = _EditorState();
    _brushState = _BrushState();
    _layerState = _LayerState();
    _isPlaying = ValueNotifier(false);
    _isInitializing = ValueNotifier(true);
    _currentStroke = ValueNotifier([]);

    _toolPanelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    if (widget.isImageMode) {
      _loadImageForEdit();
    } else {
      _initVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _toolPanelAnim.dispose();
    _editorState.dispose();
    _brushState.dispose();
    _layerState.dispose();
    _isPlaying.dispose();
    _isInitializing.dispose();
    _currentStroke.dispose();
    super.dispose();
  }

  Future<void> _loadImageForEdit() async {
    try {
      final bytes = await widget.mediaFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _imagePixelW = img.width.toDouble();
        _imagePixelH = img.height.toDouble();
      });
      img.dispose();
      _isInitializing.value = false;
    } catch (e) {
      debugPrint('Story image load error: $e');
      if (mounted) _isInitializing.value = false;
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.file(widget.mediaFile);
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(_videoListener);

      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      _isInitializing.value = false;
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) _isInitializing.value = false;
    }
  }

  void _videoListener() {
    if (widget.isImageMode) return;
    final controller = _videoController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      final duration = controller.value.duration;
      final position = controller.value.position;
      final trimEndMs =
      (duration.inMilliseconds * _editorState.trimEnd).round();

      if (position.inMilliseconds >= trimEndMs) {
        controller.pause();
        _isPlaying.value = false;
        final trimStartMs =
        (duration.inMilliseconds * _editorState.trimStart).round();
        controller.seekTo(Duration(milliseconds: trimStartMs));
      }
    }
  }

  void _togglePlay() async {
    if (widget.isImageMode) return;
    final controller = _videoController;
    if (controller == null) return;

    await _DS.hapticLight();

    if (_isPlaying.value) {
      await controller.pause();
    } else {
      final duration = controller.value.duration;
      final position = controller.value.position;
      final trimStartMs =
      (duration.inMilliseconds * _editorState.trimStart).round();
      final trimEndMs =
      (duration.inMilliseconds * _editorState.trimEnd).round();

      if (position.inMilliseconds < trimStartMs ||
          position.inMilliseconds >= trimEndMs) {
        await controller.seekTo(Duration(milliseconds: trimStartMs));
      }

      await controller.play();
    }

    _isPlaying.value = !_isPlaying.value;
  }

  void _selectTool(_Tool tool) async {
    await _DS.hapticLight();
    if (widget.isImageMode && tool == _Tool.trim) return;

    if (_editorState.activeTool == tool) {
      _editorState.activeTool = _Tool.none;
      _toolPanelAnim.reverse();
    } else {
      _editorState.activeTool = tool;
      _toolPanelAnim.forward(from: 0);
    }
    _layerState.selectedIndex = null;
  }

  void _onPanStart(DragStartDetails details) {
    if (_editorState.activeTool != _Tool.paint) return;
    _layerState.saveHistory();
    _currentStroke.value = [details.localPosition];
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_editorState.activeTool != _Tool.paint) return;
    _currentStroke.value = [..._currentStroke.value, details.localPosition];
  }

  void _onPanEnd(DragEndDetails _) {
    if (_editorState.activeTool != _Tool.paint) return;
    if (_currentStroke.value.isEmpty) return;

    _layerState.addLayer(_DrawLayer(
      position: Offset.zero,
      points: List.from(_currentStroke.value),
      color: _brushState.color,
      strokeWidth: _brushState.size,
      brush: _brushState.type,
    ));
    _currentStroke.value = [];
  }

  void _onCanvasTap(TapDownDetails details) async {
    if (_editorState.activeTool == _Tool.text) {
      await _showTextEditor(position: details.localPosition);
      return;
    }
    if (_editorState.activeTool == _Tool.sticker) {
      await _showStickerPicker(position: details.localPosition);
      return;
    }
    if (_layerState.selectedIndex != null) {
      _layerState.selectedIndex = null;
    }
  }

  Future<void> _showTextEditor({Offset? position, int? editIndex}) async {
    _videoController?.pause();
    _isPlaying.value = false;

    final existing = editIndex != null
        ? _layerState.layers[editIndex] as _TextLayer?
        : null;

    final result = await showGeneralDialog<_TextLayer?>(
      context: context,
      barrierDismissible: false,
      barrierColor: ThemeHelper.getBackgroundColor(context).withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, a1, a2, child) {
        return FadeTransition(
          opacity: a1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) => _TextEditorDialog(
        existing: existing,
        initialPosition: position ?? const Offset(80, 200),
      ),
    );

    if (result != null) {
      if (editIndex != null) {
        _layerState.updateLayer(editIndex, result);
      } else {
        _layerState.addLayer(result);
      }
    }
  }

  Future<void> _showStickerPicker({required Offset position}) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _ReelEditTheme.of(context).surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const _StickerPickerSheet(),
    );

    if (emoji != null) {
      _layerState.addLayer(_StickerLayer(
        position: position - const Offset(24, 24),
        emoji: emoji,
        size: 48,
      ));
    }
  }

  ColorFilter? _computeColorFilter() {
    final filter = _filters[_editorState.filterIndex];

    final b = _editorState.brightness * 80;
    final c = _editorState.contrast;
    final s = _editorState.saturation;
    final w = _editorState.warmth;

    final hasAdjustments = _editorState.brightness != 0 ||
        _editorState.contrast != 1 ||
        _editorState.saturation != 1 ||
        _editorState.warmth != 0;

    if (filter.matrix == null && !hasAdjustments) return null;

    if (filter.matrix != null) return filter.colorFilter;

    final sr = (1 - s) * 0.2126;
    final sg = (1 - s) * 0.7152;
    final sb = (1 - s) * 0.0722;

    return ColorFilter.matrix([
      c * (sr + s), c * sg, c * sb, 0, b + w * 20,
      c * sr, c * (sg + s), c * sb, 0, b,
      c * sr, c * sg, c * (sb + s), 0, b - w * 20,
      0, 0, 0, 1, 0,
    ]);
  }

  double get _effectiveBlur {
    final filterBlur = _filters[_editorState.filterIndex].blur * 3;
    return _editorState.blur + filterBlur;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIXED EXPORT FUNCTIONALITY - PROPERLY MERGES ALL LAYERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleExport() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    await _DS.hapticMedium();

    // Pause video and clear selection
    _videoController?.pause();
    _isPlaying.value = false;
    _layerState.clearSelection();
    _editorState.activeTool = _Tool.none;

    // Wait for UI to update (removes selection borders)
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final File? result = widget.isImageMode
          ? await _exportImageWithOverlays()
          : await _exportVideoWithOverlays();
      if (mounted && result != null) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: _ReelEditTheme.of(context).accentAlt,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<File?> _exportImageWithOverlays() async {
    final progressController = StreamController<double>.broadcast();
    final statusController = StreamController<String>.broadcast();

    if (!mounted) return null;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.82),
      builder: (_) => _ExportProgressDialog(
        progressStream: progressController.stream,
        statusStream: statusController.stream,
        isImageExport: true,
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      statusController.add('Preparing…');
      progressController.add(0.06);
      await Future.delayed(const Duration(milliseconds: 120));

      statusController.add('Rendering…');
      progressController.add(0.22);

      final boundary = _fullImageExportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context);
        return widget.mediaFile;
      }

      await Future.delayed(const Duration(milliseconds: 80));
      final pixelRatio =
          MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
      final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
      progressController.add(0.62);
      statusController.add('Saving…');

      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      if (byteData == null) {
        if (mounted) Navigator.pop(context);
        return widget.mediaFile;
      }

      final outPath = '${tempDir.path}/story_edit_$timestamp.png';
      await File(outPath).writeAsBytes(byteData.buffer.asUint8List());

      progressController.add(1.0);
      statusController.add('Done');
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) Navigator.pop(context);

      return File(outPath);
    } catch (e, st) {
      debugPrint('Image export error: $e\n$st');
      if (mounted) Navigator.pop(context);
      rethrow;
    } finally {
      await progressController.close();
      await statusController.close();
    }
  }

  Future<File?> _exportVideoWithOverlays() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return widget.mediaFile;
    }

    // Create stream controllers for progress
    final progressController = StreamController<double>.broadcast();
    final statusController = StreamController<String>.broadcast();

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.82),
      builder: (_) => _ExportProgressDialog(
        progressStream: progressController.stream,
        statusStream: statusController.stream,
        isImageExport: false,
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      statusController.add('Capturing overlay layers...');
      progressController.add(0.05);

      // Step 1: Capture overlay if there are layers
      String? overlayPath;

      // Capture overlay when there are layers (text/stickers/drawings) or an in-progress stroke
      final hasOverlayContent =
          _layerState.hasLayers || _currentStroke.value.isNotEmpty;
      if (hasOverlayContent) {
        // Force a rebuild to ensure layers are rendered without selection
        await Future.delayed(const Duration(milliseconds: 100));

        final overlayData = await _captureOverlayImage();
        if (overlayData != null) {
          overlayPath = '${tempDir.path}/overlay_$timestamp.png';
          final overlayFile = File(overlayPath);
          await overlayFile.writeAsBytes(overlayData);
          debugPrint('✓ Overlay saved: $overlayPath (${overlayData.length} bytes)');
        }
      }

      progressController.add(0.15);
      statusController.add('Processing video...');

      // Step 2: Calculate trim parameters
      final duration = controller.value.duration;
      final totalMs = duration.inMilliseconds;
      final startMs = (totalMs * _editorState.trimStart).round();
      final endMs = (totalMs * _editorState.trimEnd).round();
      final clipDurationMs = endMs - startMs;

      final startTimeSec = startMs / 1000.0;
      final clipDurationSec = clipDurationMs / 1000.0;

      // Step 3: Get video dimensions
      final videoWidth = controller.value.size.width.toInt();
      final videoHeight = controller.value.size.height.toInt();

      // Step 4: Build output path
      final outputPath = '${tempDir.path}/edited_video_$timestamp.mp4';

      // Step 5: Build FFmpeg arguments (list form for reliable parsing, no shell quoting)
      final ffmpegArgs = _buildFFmpegExportArguments(
        inputPath: widget.mediaFile.path,
        overlayPath: overlayPath,
        outputPath: outputPath,
        startTime: startTimeSec,
        duration: clipDurationSec,
        videoWidth: videoWidth,
        videoHeight: videoHeight,
      );

      debugPrint('FFmpeg args: ${ffmpegArgs.join(" ")}');

      progressController.add(0.2);
      statusController.add('Encoding video with effects...');

      // Step 6: Setup progress monitoring
      FFmpegKitConfig.enableStatisticsCallback((Statistics statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && clipDurationMs > 0) {
          final progress = 0.2 + (timeMs / clipDurationMs) * 0.7;
          progressController.add(progress.clamp(0.2, 0.9));
        }
      });

      // Step 7: Execute FFmpeg with argument list (avoids quote/parse issues)
      final session = await FFmpegKit.executeWithArguments(ffmpegArgs);
      final returnCode = await session.getReturnCode();

      progressController.add(0.95);
      statusController.add('Finalizing...');

      // Step 8: Check result
      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          debugPrint('✓ Export successful: $outputPath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

          // Cleanup temp overlay
          if (overlayPath != null) {
            try {
              await File(overlayPath).delete();
            } catch (_) {}
          }

          progressController.add(1.0);
          statusController.add('Complete!');
          await Future.delayed(const Duration(milliseconds: 300));

          // Close dialog
          if (mounted) Navigator.pop(context);

          return outputFile;
        }
      }

      // Log FFmpeg output on failure
      final logs = await session.getAllLogsAsString();
      final failureStack = await session.getFailStackTrace();
      debugPrint('FFmpeg failed!\nLogs: $logs\nStack: $failureStack');

      // Close dialog
      if (mounted) Navigator.pop(context);

      // Return original file as fallback
      return widget.mediaFile;

    } catch (e, stackTrace) {
      debugPrint('Export exception: $e\n$stackTrace');
      if (mounted) Navigator.pop(context);
      rethrow;
    } finally {
      await progressController.close();
      await statusController.close();
    }
  }

  /// Captures the overlay layers as a PNG image with transparency
  Future<Uint8List?> _captureOverlayImage() async {
    try {
      final boundary = _overlayKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('⚠ Overlay boundary is null');
        return null;
      }

      // Wait for any pending paints
      await Future.delayed(const Duration(milliseconds: 50));

      // Capture at device pixel ratio for quality
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('⚠ Failed to convert overlay to bytes');
        return null;
      }

      debugPrint('✓ Overlay captured: ${image.width}x${image.height} @ ${pixelRatio}x');
      return byteData.buffer.asUint8List();

    } catch (e) {
      debugPrint('⚠ Overlay capture error: $e');
      return null;
    }
  }

  /// Builds the FFmpeg arguments for export (list form for executeWithArguments).
  /// Overlay image is read with -loop 1 so it lasts the full video duration.
  List<String> _buildFFmpegExportArguments({
    required String inputPath,
    String? overlayPath,
    required String outputPath,
    required double startTime,
    required double duration,
    required int videoWidth,
    required int videoHeight,
  }) {
    // Build video filter chain
    final List<String> videoFilters = [];

    // 1. Color filter from presets
    final filterDef = _filters[_editorState.filterIndex];
    if (filterDef.ffmpegFilter != null && filterDef.ffmpegFilter!.isNotEmpty) {
      videoFilters.add(filterDef.ffmpegFilter!);
    }

    // 2. Manual adjustments (brightness, contrast, saturation)
    if (_editorState.brightness != 0 ||
        _editorState.contrast != 1 ||
        _editorState.saturation != 1) {
      final brightness = (_editorState.brightness * 0.3).toStringAsFixed(3);
      final contrast = _editorState.contrast.toStringAsFixed(3);
      final saturation = _editorState.saturation.toStringAsFixed(3);
      videoFilters.add('eq=brightness=$brightness:contrast=$contrast:saturation=$saturation');
    }

    // 3. Color temperature (warmth)
    if (_editorState.warmth != 0) {
      final w = _editorState.warmth;
      if (w > 0) {
        videoFilters.add(
            'colorbalance=rs=${(w * 0.3).toStringAsFixed(2)}:gs=${(w * 0.1).toStringAsFixed(2)}:bs=${(-w * 0.2).toStringAsFixed(2)}'
        );
      } else {
        videoFilters.add(
            'colorbalance=rs=${(w * 0.2).toStringAsFixed(2)}:gs=${(w * 0.1).toStringAsFixed(2)}:bs=${(-w * 0.3).toStringAsFixed(2)}'
        );
      }
    }

    // 4. Blur
    if (_editorState.blur > 0) {
      final sigma = (_editorState.blur * 2).toStringAsFixed(2);
      videoFilters.add('gblur=sigma=$sigma');
    }

    // 5. Vignette
    if (_editorState.vignette > 0) {
      final angle = (_editorState.vignette * 0.5).toStringAsFixed(2);
      videoFilters.add('vignette=angle=$angle');
    }

    final videoFilterChain = videoFilters.isNotEmpty
        ? videoFilters.join(',')
        : 'null';

    if (overlayPath != null) {
      // [0:v] = main video, [1:v] = overlay image.
      // Overlay image must be read with -loop 1 so it lasts the full duration;
      // otherwise shortest=1 would make output only 1 frame.
      final complexFilter = StringBuffer();
      complexFilter.write('[0:v]');
      complexFilter.write('setpts=PTS-STARTPTS');
      if (videoFilterChain != 'null') {
        complexFilter.write(',');
        complexFilter.write(videoFilterChain);
      }
      complexFilter.write('[base];');
      complexFilter.write('[1:v]');
      complexFilter.write('scale=$videoWidth:$videoHeight,');
      complexFilter.write('format=rgba');
      complexFilter.write('[ovrl];');
      complexFilter.write('[base][ovrl]');
      complexFilter.write('overlay=0:0:format=auto:shortest=1[v]');

      return [
        '-y',
        '-ss', startTime.toStringAsFixed(3),
        '-i', inputPath,
        '-loop', '1',
        '-i', overlayPath,
        '-filter_complex', complexFilter.toString(),
        '-map', '[v]',
        '-map', '0:a?',
        '-t', duration.toStringAsFixed(3),
        '-c:v', 'libx264',
        '-profile:v', 'baseline',
        '-level', '3.1',
        '-preset', 'fast',
        '-crf', '23',
        '-pix_fmt', 'yuv420p',
        '-vsync', 'cfr',
        '-r', '30',
        '-x264opts', 'keyint=30:min-keyint=30:no-scenecut',
        '-c:a', 'aac',
        '-b:a', '128k',
        '-ac', '2',
        '-ar', '44100',
        '-movflags', '+faststart',
        outputPath,
      ];
    }

    // No overlay: simple re-encode with optional video filters
    final args = <String>[
      '-y',
      '-ss', startTime.toStringAsFixed(3),
      '-i', inputPath,
    ];
    if (videoFilters.isNotEmpty) {
      args.addAll(['-vf', videoFilterChain]);
    }
    args.addAll([
      '-t', duration.toStringAsFixed(3),
      '-c:v', 'libx264',
      '-profile:v', 'baseline',
      '-level', '3.1',
      '-preset', 'fast',
      '-crf', '23',
      '-pix_fmt', 'yuv420p',
      '-vsync', 'cfr',
      '-r', '30',
      '-x264opts', 'keyint=30:min-keyint=30:no-scenecut',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-ac', '2',
      '-ar', '44100',
      '-movflags', '+faststart',
      outputPath,
    ]);
    return args;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accent = ThemeHelper.getAccentColor(context);
    final themeData = _ReelEditThemeData(
      bg: ThemeHelper.getBackgroundColor(context),
      surface: ThemeHelper.getSurfaceColor(context),
      surface2: ThemeHelper.getSecondaryBackgroundColor(context),
      border: ThemeHelper.getBorderColor(context),
      accent: accent,
      accentAlt: AppColors.error,
      textPrim: ThemeHelper.getTextPrimary(context),
      textSec: ThemeHelper.getTextSecondary(context),
      textDim: ThemeHelper.getTextMuted(context),
    );

    return _ReelEditTheme(
      data: themeData,
      child: Scaffold(
        backgroundColor: _ReelEditTheme.of(context).bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListenableBuilder(
                  listenable: _editorState,
                  builder: (context, _) {
                    return Center(
                      child: _buildVideoViewport(size),
                    );
                  },
                ),
              ),
              _buildToolPanel(),
              _buildTabBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _IconBtn(
            Icons.close,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(widget.isImageMode ? 'EDIT PHOTO' : 'EDITOR',
              style: _DS.heading(context,
                  size: 11, color: _ReelEditTheme.of(context).textSec)),
          const Spacer(),
          ListenableBuilder(
            listenable: _layerState,
            builder: (context, _) {
              if (!_layerState.canUndo) return const SizedBox.shrink();
              return _IconBtn(
                Icons.undo_rounded,
                onTap: _layerState.undo,
                color: _ReelEditTheme.of(context).textSec,
              );
            },
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isExporting ? null : _handleExport,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: _isExporting
                    ? _ReelEditTheme.of(context).surface2
                    : _ReelEditTheme.of(context).accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _isExporting
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _ReelEditTheme.of(context).accent,
                ),
              )
                  : Text(
                'EXPORT',
                style: _DS.label(context,
                    color: ThemeHelper.getOnAccentColor(context),
                    weight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoViewport(Size screenSize) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isInitializing,
      builder: (context, isInitializing, _) {
        if (isInitializing) {
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _ReelEditTheme.of(context).accent),
            ),
          );
        }

        if (widget.isImageMode) {
          final iw = _imagePixelW;
          final ih = _imagePixelH;
          if (iw == null || ih == null || iw <= 0 || ih <= 0) {
            return Center(
              child: Icon(Icons.broken_image_outlined,
                  color: _ReelEditTheme.of(context).textDim, size: 40),
            );
          }
          final imageAspect = iw / ih;
          final selectedRatio =
              _aspectRatios[_editorState.aspectRatioIndex].ratio;
          final displayAspect = selectedRatio ?? imageAspect;

          final maxWidth = screenSize.width - 24;
          final maxHeight = screenSize.height * 0.55;

          double viewW, viewH;
          if (maxWidth / displayAspect <= maxHeight) {
            viewW = maxWidth;
            viewH = maxWidth / displayAspect;
          } else {
            viewH = maxHeight;
            viewW = maxHeight * displayAspect;
          }

          _videoDisplaySize = Size(viewW, viewH);

          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              key: _videoContainerKey,
              width: viewW,
              height: viewH,
              child: _buildImageStack(viewW, viewH),
            ),
          );
        }

        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return Center(
            child: Icon(Icons.broken_image_outlined,
                color: _ReelEditTheme.of(context).textDim, size: 40),
          );
        }

        final videoAspect = controller.value.aspectRatio;
        final selectedRatio =
            _aspectRatios[_editorState.aspectRatioIndex].ratio;
        final displayAspect = selectedRatio ?? videoAspect;

        final maxWidth = screenSize.width - 24;
        final maxHeight = screenSize.height * 0.55;

        double viewW, viewH;
        if (maxWidth / displayAspect <= maxHeight) {
          viewW = maxWidth;
          viewH = maxWidth / displayAspect;
        } else {
          viewH = maxHeight;
          viewW = maxHeight * displayAspect;
        }

        _videoDisplaySize = Size(viewW, viewH);

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            key: _videoContainerKey,
            width: viewW,
            height: viewH,
            child: _buildVideoStack(controller, viewW, viewH),
          ),
        );
      },
    );
  }

  Widget _buildVideoStack(
      VideoPlayerController controller, double width, double height) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _onCanvasTap,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Video layer with effects
          Positioned.fill(
            child: RepaintBoundary(
              child: _buildVideoWithEffects(controller),
            ),
          ),

          // ALL OVERLAYS in one RepaintBoundary for capture
          // This captures: drawings, text, stickers
          Positioned.fill(
            child: RepaintBoundary(
              key: _overlayKey,
              child: Stack(
                children: [
                  // Drawing canvas (CustomPaint for strokes)
                  ValueListenableBuilder<List<Offset?>>(
                    valueListenable: _currentStroke,
                    builder: (context, stroke, _) {
                      return ListenableBuilder(
                        listenable:
                        Listenable.merge([_layerState, _brushState]),
                        builder: (context, _) {
                          return CustomPaint(
                            size: Size(width, height),
                            painter: _LayerPainter(
                              layers: _layerState.layers,
                              currentStroke: stroke,
                              currentColor: _brushState.color,
                              currentStrokeWidth: _brushState.size,
                              currentBrush: _brushState.type,
                            ),
                            isComplex: true,
                            willChange: stroke.isNotEmpty,
                          );
                        },
                      );
                    },
                  ),

                  // Text and Sticker layers
                  _buildOverlayLayers(),
                ],
              ),
            ),
          ),

          // Crop overlay (NOT part of export)
          if (_editorState.activeTool == _Tool.crop)
            Positioned.fill(
              child: _CropOverlay(
                rect: _editorState.cropRect,
                onRectChanged: (rect) {
                  _editorState.cropRect = rect;
                  _editorState.notifyAdjustmentChanged();
                },
              ),
            ),

          // Vignette (applied via FFmpeg, but preview here)
          if (_editorState.vignette > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: _VignetteOverlay(intensity: _editorState.vignette),
              ),
            ),

          // Play button
          _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildVideoWithEffects(VideoPlayerController controller) {
    Widget video = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );

    final colorFilter = _computeColorFilter();
    if (colorFilter != null) {
      video = ColorFiltered(colorFilter: colorFilter, child: video);
    }

    final blur = _effectiveBlur;
    if (blur > 0) {
      video = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: video,
      );
    }

    return video;
  }

  Widget _buildImageWithEffects() {
    final w = _imagePixelW!;
    final h = _imagePixelH!;
    Widget image = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: w,
          height: h,
          child: Image.file(
            widget.mediaFile,
            fit: BoxFit.cover,
            width: w,
            height: h,
          ),
        ),
      ),
    );

    final colorFilter = _computeColorFilter();
    if (colorFilter != null) {
      image = ColorFiltered(colorFilter: colorFilter, child: image);
    }

    final blur = _effectiveBlur;
    if (blur > 0) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: image,
      );
    }

    return image;
  }

  Widget _buildImageStack(double width, double height) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _onCanvasTap,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: _fullImageExportKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: _buildImageWithEffects()),
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: _overlayKey,
                      child: Stack(
                        children: [
                          ValueListenableBuilder<List<Offset?>>(
                            valueListenable: _currentStroke,
                            builder: (context, stroke, _) {
                              return ListenableBuilder(
                                listenable:
                                    Listenable.merge([_layerState, _brushState]),
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: Size(width, height),
                                    painter: _LayerPainter(
                                      layers: _layerState.layers,
                                      currentStroke: stroke,
                                      currentColor: _brushState.color,
                                      currentStrokeWidth: _brushState.size,
                                      currentBrush: _brushState.type,
                                    ),
                                    isComplex: true,
                                    willChange: stroke.isNotEmpty,
                                  );
                                },
                              );
                            },
                          ),
                          _buildOverlayLayers(),
                        ],
                      ),
                    ),
                  ),
                  if (_editorState.vignette > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child:
                            _VignetteOverlay(intensity: _editorState.vignette),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_editorState.activeTool == _Tool.crop)
            Positioned.fill(
              child: _CropOverlay(
                rect: _editorState.cropRect,
                onRectChanged: (rect) {
                  _editorState.cropRect = rect;
                  _editorState.notifyAdjustmentChanged();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    if (widget.isImageMode) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: _isPlaying,
      builder: (context, isPlaying, _) {
        if (isPlaying || _editorState.activeTool != _Tool.none) {
          return const SizedBox.shrink();
        }

        return Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  // Build overlay layers - hide selection UI during export
  Widget _buildOverlayLayers() {
    return ListenableBuilder(
      listenable: _layerState,
      builder: (context, _) {
        final children = <Widget>[];

        for (int i = 0; i < _layerState.layers.length; i++) {
          final layer = _layerState.layers[i];
          if (layer is _DrawLayer) continue; // Handled by CustomPaint

          children.add(
            _InteractiveLayerWidget(
              key: ValueKey(layer.id),
              layer: layer,
              // Hide selection border during export
              isSelected: _layerState.selectedIndex == i && !_isExporting,
              onTap: () {
                if (_layerState.selectedIndex == i) {
                  if (layer is _TextLayer) {
                    _showTextEditor(editIndex: i);
                  }
                } else {
                  _layerState.selectedIndex = i;
                }
              },
              onTransformUpdate: (position, scale, rotation) {
                _layerState.updateLayerTransform(
                  i,
                  position: position,
                  scale: scale,
                  rotation: rotation,
                );
              },
              onDelete: () => _layerState.removeLayer(i),
              hideControls: _isExporting,
            ),
          );
        }

        return Stack(children: children);
      },
    );
  }

  Widget _buildToolPanel() {
    return ListenableBuilder(
      listenable: _editorState,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _buildToolPanelContent(),
        );
      },
    );
  }

  Widget _buildToolPanelContent() {
    return switch (_editorState.activeTool) {
      _Tool.paint =>
          _PaintPanel(key: const ValueKey('paint'), brushState: _brushState),
      _Tool.filter => _FilterPanel(
        key: const ValueKey('filter'),
        selectedIndex: _editorState.filterIndex,
        onFilterSelected: (index) => _editorState.filterIndex = index,
      ),
      _Tool.adjust =>
          _AdjustPanel(key: const ValueKey('adjust'), editorState: _editorState),
      _Tool.crop => _CropPanel(
        key: const ValueKey('crop'),
        selectedIndex: _editorState.aspectRatioIndex,
        onAspectRatioSelected: (index) {
          _editorState.aspectRatioIndex = index;
          _editorState.notifyAdjustmentChanged();
        },
      ),
      _Tool.trim => widget.isImageMode
          ? const SizedBox.shrink(key: ValueKey('trim_none'))
          : _TrimPanel(
              key: const ValueKey('trim'),
              controller: _videoController,
              trimStart: _editorState.trimStart,
              trimEnd: _editorState.trimEnd,
              isPlaying: _isPlaying,
              onTrimChanged: (start, end) {
                _editorState.trimStart = start;
                _editorState.trimEnd = end;
                _editorState.notifyAdjustmentChanged();
              },
              onTogglePlay: _togglePlay,
              onSeek: (position) {
                final duration =
                    _videoController?.value.duration ?? Duration.zero;
                _videoController?.seekTo(Duration(
                  milliseconds: (duration.inMilliseconds * position).round(),
                ));
              },
            ),
      _ => const SizedBox.shrink(key: ValueKey('none')),
    };
  }

  Widget _buildTabBar() {
    final tabs = <(IconData, String, _Tool)>[
      if (!widget.isImageMode)
        (Icons.content_cut_rounded, 'TRIM', _Tool.trim),
      (Icons.crop_rounded, 'CROP', _Tool.crop),
      (Icons.filter_rounded, 'FILTER', _Tool.filter),
      (Icons.tune_rounded, 'ADJUST', _Tool.adjust),
      (Icons.edit_rounded, 'DRAW', _Tool.paint),
      (Icons.title_rounded, 'TEXT', _Tool.text),
      (Icons.emoji_emotions_rounded, 'STICKER', _Tool.sticker),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _ReelEditTheme.of(context).surface,
        border: Border(
            top: BorderSide(color: _ReelEditTheme.of(context).border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ListenableBuilder(
          listenable: _editorState,
          builder: (context, _) {
            return Row(
              children: tabs.map((tab) {
                final isActive = _editorState.activeTool == tab.$3;
                return _TabButton(
                  icon: tab.$1,
                  label: tab.$2,
                  isActive: isActive,
                  onTap: () => _selectTool(tab.$3),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERACTIVE LAYER WIDGET - Updated with hideControls
// ═══════════════════════════════════════════════════════════════════════════

class _InteractiveLayerWidget extends StatefulWidget {
  final _Layer layer;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset position, double scale, double rotation)
  onTransformUpdate;
  final VoidCallback onDelete;
  final bool hideControls;

  const _InteractiveLayerWidget({
    super.key,
    required this.layer,
    required this.isSelected,
    required this.onTap,
    required this.onTransformUpdate,
    required this.onDelete,
    this.hideControls = false,
  });

  @override
  State<_InteractiveLayerWidget> createState() =>
      _InteractiveLayerWidgetState();
}

class _InteractiveLayerWidgetState extends State<_InteractiveLayerWidget> {
  Offset _initialFocalPoint = Offset.zero;
  Offset _initialPosition = Offset.zero;
  double _initialScale = 1.0;
  double _initialRotation = 0.0;

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;

    Widget content;
    if (layer is _TextLayer) {
      content = _TextLayerWidget(layer: layer);
    } else if (layer is _StickerLayer) {
      content = Text(
        layer.emoji,
        style: TextStyle(fontSize: layer.size * layer.scale),
      );
    } else {
      return const SizedBox.shrink();
    }

    final showSelection = widget.isSelected && !widget.hideControls;

    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: showSelection
              ? BoxDecoration(
            border: Border.all(
                color: _ReelEditTheme.of(context).accent, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: layer.rotation,
                child: Transform.scale(
                  scale: layer.scale,
                  child: content,
                ),
              ),
              // Only show delete button when selected and not exporting
              if (showSelection)
                Positioned(
                  top: -20,
                  right: -20,
                  child: GestureDetector(
                    onTap: () async {
                      await _DS.hapticLight();
                      widget.onDelete();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _ReelEditTheme.of(context).accentAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _initialFocalPoint = details.focalPoint;
    _initialPosition = widget.layer.position;
    _initialScale = widget.layer.scale;
    _initialRotation = widget.layer.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newPosition =
        _initialPosition + (details.focalPoint - _initialFocalPoint);
    final newScale = (_initialScale * details.scale).clamp(0.3, 4.0);
    final newRotation = _initialRotation + details.rotation;

    widget.onTransformUpdate(newPosition, newScale, newRotation);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEXT LAYER WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _TextLayerWidget extends StatelessWidget {
  final _TextLayer layer;

  const _TextLayerWidget({required this.layer});

  @override
  Widget build(BuildContext context) {
    return switch (layer.style) {
      _TextStyle.plain => Text(
        layer.text,
        style: TextStyle(
          color: layer.color,
          fontSize: layer.fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
      _TextStyle.filled => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: layer.bgColor ?? Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          layer.text,
          style: TextStyle(
            color: layer.color,
            fontSize: layer.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      _TextStyle.outlined => Stack(
        children: [
          Text(
            layer.text,
            style: TextStyle(
              fontSize: layer.fontSize,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = Colors.black,
            ),
          ),
          Text(
            layer.text,
            style: TextStyle(
              color: layer.color,
              fontSize: layer.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      _TextStyle.neon => Text(
        layer.text,
        style: TextStyle(
          color: layer.color,
          fontSize: layer.fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(blurRadius: 2, color: layer.color),
            Shadow(blurRadius: 10, color: layer.color),
            Shadow(blurRadius: 20, color: layer.color.withOpacity(0.6)),
          ],
        ),
      ),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REST OF THE FILE - KEEP EXACTLY AS IS
// (TextEditorDialog, StickerPickerSheet, PaintPanel, FilterPanel, etc.)
// ═══════════════════════════════════════════════════════════════════════════

class _TextEditorDialog extends StatefulWidget {
  final _TextLayer? existing;
  final Offset initialPosition;

  const _TextEditorDialog({
    this.existing,
    required this.initialPosition,
  });

  @override
  State<_TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<_TextEditorDialog> {
  late final TextEditingController _controller;
  late Color _color;
  late double _size;
  late _TextStyle _style;
  late Color _bgColor;

  static const _palette = [
    Colors.white,
    Color(0xFFE8FF47),
    Color(0xFFFF4757),
    Color(0xFF00E5FF),
    Color(0xFFFF9100),
    Color(0xFFE040FB),
    Colors.black,
  ];

  static const _styles = [
    (_TextStyle.plain, 'Aa', 'Plain'),
    (_TextStyle.filled, '▌Aa', 'Fill'),
    (_TextStyle.outlined, '○Aa', 'Stroke'),
    (_TextStyle.neon, '✦Aa', 'Neon'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.text ?? '');
    _color = widget.existing?.color ?? Colors.white;
    _size = widget.existing?.fontSize ?? 28;
    _style = widget.existing?.style ?? _TextStyle.plain;
    _bgColor = widget.existing?.bgColor ?? Colors.black;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDone() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(
      context,
      _TextLayer(
        position: widget.existing?.position ?? widget.initialPosition,
        text: text,
        color: _color,
        bgColor: _bgColor,
        fontSize: _size,
        style: _style,
        scale: widget.existing?.scale ?? 1.0,
        rotation: widget.existing?.rotation ?? 0.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStyleSelector(),
            Expanded(child: _buildTextField()),
            _buildSizeSlider(),
            _buildColorPalette(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          _IconBtn(Icons.close, onTap: () => Navigator.pop(context)),
          const Spacer(),
          GestureDetector(
            onTap: _handleDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _ReelEditTheme.of(context).accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('DONE',
                  style: _DS.label(context,
                      color: Colors.black, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final style = _styles[index];
          final isActive = _style == style.$1;
          return GestureDetector(
            onTap: () => setState(() => _style = style.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration:
              isActive ? _DS.activePill(context) : _DS.pill(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    style.$2,
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive
                          ? _ReelEditTheme.of(context).accent
                          : _ReelEditTheme.of(context).textSec,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _color,
            fontSize: _size,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Type here…',
            hintStyle: TextStyle(
                color: _ReelEditTheme.of(context).textDim, fontSize: _size),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text('A',
              style: _DS.label(context,
                  size: 12, color: _ReelEditTheme.of(context).textDim)),
          Expanded(
            child: _SlimSlider(
              value: _size,
              min: 14,
              max: 72,
              onChanged: (v) => setState(() => _size = v),
            ),
          ),
          Text('A',
              style: _DS.label(context,
                  size: 24, color: _ReelEditTheme.of(context).textPrim)),
        ],
      ),
    );
  }

  Widget _buildColorPalette() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _palette
            .map((c) => _ColorCircle(
          color: c,
          isSelected: _color == c,
          onTap: () => setState(() => _color = c),
          size: 36,
        ))
            .toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STICKER PICKER SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _StickerPickerSheet extends StatelessWidget {
  const _StickerPickerSheet();

  static const _categories = {
    'Smileys': ['😊', '😂', '🥹', '😍', '🥰', '😎', '🤩', '😇'],
    'Gestures': ['👍', '👏', '🙌', '✌️', '🤟', '💪', '🙏', '👀'],
    'Hearts': ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '💕'],
    'Objects': ['🔥', '✨', '⭐', '💫', '🌟', '⚡', '💎', '🎯'],
    'Nature': ['🌸', '🌺', '🌻', '🌹', '🦋', '🌈', '☀️', '🌙'],
    'Food': ['🍕', '🍔', '🍟', '🍩', '🍪', '🍰', '🧁', '☕'],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _ReelEditTheme.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text('STICKERS', style: _DS.heading(context, size: 14)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close,
                      color: _ReelEditTheme.of(context).textDim, size: 22),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: _categories.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(entry.key,
                          style: _DS.label(context,
                              size: 11,
                              color: _ReelEditTheme.of(context).textDim)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value
                          .map((emoji) => _StickerButton(
                        emoji: emoji,
                        onTap: () => Navigator.pop(context, emoji),
                      ))
                          .toList(),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _StickerButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _DS.hapticLight();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _ReelEditTheme.of(context).surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _ReelEditTheme.of(context).border),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINT PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _PaintPanel extends StatelessWidget {
  final _BrushState brushState;

  const _PaintPanel({super.key, required this.brushState});

  static const _colors = [
    Color(0xFFE8FF47),
    Color(0xFFFF4757),
    Colors.white,
    Color(0xFF00E5FF),
    Color(0xFFFF9100),
    Color(0xFFE040FB),
    Color(0xFF00E676),
    Colors.black,
  ];

  static const _brushes = [
    (_BrushType.pen, Icons.edit, 'PEN'),
    (_BrushType.marker, Icons.format_paint, 'MARKER'),
    (_BrushType.neon, Icons.auto_awesome, 'NEON'),
    (_BrushType.eraser, Icons.auto_fix_high, 'ERASE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _ReelEditTheme.of(context).surface,
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: brushState,
        builder: (ctx, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrushTypes(ctx),
              const SizedBox(height: 16),
              _buildSizeSlider(),
              const SizedBox(height: 16),
              _buildColorRow(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrushTypes(BuildContext context) {
    return Row(
      children: _brushes.map((b) {
        final isActive = brushState.type == b.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () async {
              await _DS.hapticLight();
              brushState.type = b.$1;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration:
              isActive ? _DS.activePill(context) : _DS.pill(context),
              child: Column(
                children: [
                  Icon(
                    b.$2,
                    size: 20,
                    color: isActive
                        ? _ReelEditTheme.of(context).accent
                        : _ReelEditTheme.of(context).textSec,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.$3,
                    style: _DS.label(
                      context,
                      size: 8,
                      color: isActive
                          ? _ReelEditTheme.of(context).accent
                          : _ReelEditTheme.of(context).textDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSizeSlider() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: brushState.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SlimSlider(
            value: brushState.size,
            min: 2,
            max: 30,
            onChanged: (v) => brushState.size = v,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: brushState.size.clamp(8, 24),
          height: brushState.size.clamp(8, 24),
          decoration: BoxDecoration(
            color: brushState.color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildColorRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _colors
          .map((c) => _ColorCircle(
        color: c,
        isSelected: brushState.color == c,
        onTap: () async {
          await _DS.hapticLight();
          brushState.color = c;
        },
      ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTER PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _FilterPanel extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onFilterSelected;

  const _FilterPanel({
    super.key,
    required this.selectedIndex,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: _ReelEditTheme.of(context).surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _filters.length,
        itemBuilder: (_, index) {
          final isActive = selectedIndex == index;
          return GestureDetector(
            onTap: () async {
              await _DS.hapticLight();
              onFilterSelected(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration:
              isActive ? _DS.activePill(context) : _DS.pill(context),
              child: Center(
                child: Text(
                  _filters[index].name,
                  style: _DS.label(
                    context,
                    size: 12,
                    color: isActive
                        ? _ReelEditTheme.of(context).accent
                        : _ReelEditTheme.of(context).textSec,
                    weight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADJUST PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _AdjustPanel extends StatefulWidget {
  final _EditorState editorState;

  const _AdjustPanel({super.key, required this.editorState});

  @override
  State<_AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends State<_AdjustPanel> {
  @override
  Widget build(BuildContext context) {
    final params = [
      ('BRIGHTNESS', widget.editorState.brightness, -1.0, 1.0,
          (double v) => widget.editorState.brightness = v),
      ('CONTRAST', widget.editorState.contrast - 1, -0.5, 1.0,
          (double v) => widget.editorState.contrast = v + 1),
      ('SATURATION', widget.editorState.saturation - 1, -1.0, 2.0,
          (double v) => widget.editorState.saturation = v + 1),
      ('WARMTH', widget.editorState.warmth, -1.0, 1.0,
          (double v) => widget.editorState.warmth = v),
      ('BLUR', widget.editorState.blur / 20, 0.0, 1.0,
          (double v) => widget.editorState.blur = v * 20),
      ('VIGNETTE', widget.editorState.vignette, 0.0, 1.0,
          (double v) => widget.editorState.vignette = v),
    ];

    return Container(
      color: _ReelEditTheme.of(context).surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: params
            .map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(p.$1,
                    style: _DS.label(context,
                        size: 9,
                        color: _ReelEditTheme.of(context).textDim)),
              ),
              Expanded(
                child: _SlimSlider(
                  value: p.$2,
                  min: p.$3,
                  max: p.$4,
                  centered: p.$3 < 0,
                  onChanged: (v) {
                    setState(() => p.$5(v));
                    widget.editorState.notifyAdjustmentChanged();
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  (p.$2 * 100).round().toString(),
                  textAlign: TextAlign.right,
                  style: _DS.label(context,
                      size: 10,
                      color: _ReelEditTheme.of(context).accent),
                ),
              ),
            ],
          ),
        ))
            .toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CROP PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _CropPanel extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onAspectRatioSelected;

  const _CropPanel({
    super.key,
    required this.selectedIndex,
    required this.onAspectRatioSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _ReelEditTheme.of(context).surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ASPECT RATIO',
              style:
              _DS.label(context, color: _ReelEditTheme.of(context).textDim)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_aspectRatios.length, (i) {
                final isActive = selectedIndex == i;
                return GestureDetector(
                  onTap: () async {
                    await _DS.hapticLight();
                    onAspectRatioSelected(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration:
                    isActive ? _DS.activePill(context) : _DS.pill(context),
                    child: Text(
                      _aspectRatios[i].label,
                      style: _DS.label(
                        context,
                        size: 12,
                        color: isActive
                            ? _ReelEditTheme.of(context).accent
                            : _ReelEditTheme.of(context).textSec,
                        weight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIM PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _TrimPanel extends StatefulWidget {
  final VideoPlayerController? controller;
  final double trimStart;
  final double trimEnd;
  final ValueNotifier<bool> isPlaying;
  final void Function(double start, double end) onTrimChanged;
  final VoidCallback onTogglePlay;
  final void Function(double position) onSeek;

  const _TrimPanel({
    super.key,
    required this.controller,
    required this.trimStart,
    required this.trimEnd,
    required this.isPlaying,
    required this.onTrimChanged,
    required this.onTogglePlay,
    required this.onSeek,
  });

  @override
  State<_TrimPanel> createState() => _TrimPanelState();
}

class _TrimPanelState extends State<_TrimPanel> {
  @override
  Widget build(BuildContext context) {
    final duration = widget.controller?.value.duration ?? Duration.zero;
    final startMs = (duration.inMilliseconds * widget.trimStart).round();
    final endMs = (duration.inMilliseconds * widget.trimEnd).round();
    final trimmedDurationMs = endMs - startMs;

    return Container(
      color: _ReelEditTheme.of(context).surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('TRIM VIDEO',
                  style: _DS.label(context,
                      color: _ReelEditTheme.of(context).textDim, size: 11)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _ReelEditTheme.of(context).surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_formatDuration(startMs)} → ${_formatDuration(endMs)} (${_formatDuration(trimmedDurationMs)})',
                  style: _DS.label(context,
                      size: 10, color: _ReelEditTheme.of(context).accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TrimRangeSlider(
            controller: widget.controller,
            trimStart: widget.trimStart,
            trimEnd: widget.trimEnd,
            onTrimChanged: widget.onTrimChanged,
            onSeek: widget.onSeek,
          ),
          const SizedBox(height: 16),
          _buildPlaybackControls(duration),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms / 1000;
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final millis = ((totalSeconds % 1) * 10).floor();

    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$millis';
    }
    return '${seconds}.$millis s';
  }

  Widget _buildPlaybackControls(Duration duration) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PlaybackButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Go to start',
          onTap: () => widget.onSeek(widget.trimStart),
        ),
        const SizedBox(width: 12),
        _PlaybackButton(
          icon: Icons.replay_5_rounded,
          tooltip: 'Back 5s',
          onTap: () {
            final current =
                widget.controller?.value.position.inMilliseconds ?? 0;
            final newPos = (current - 5000) / duration.inMilliseconds;
            widget.onSeek(newPos.clamp(widget.trimStart, widget.trimEnd));
          },
        ),
        const SizedBox(width: 12),
        ValueListenableBuilder<bool>(
          valueListenable: widget.isPlaying,
          builder: (_, playing, __) {
            return GestureDetector(
              onTap: widget.onTogglePlay,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _ReelEditTheme.of(context).accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                      _ReelEditTheme.of(context).accent.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 30,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        _PlaybackButton(
          icon: Icons.forward_5_rounded,
          tooltip: 'Forward 5s',
          onTap: () {
            final current =
                widget.controller?.value.position.inMilliseconds ?? 0;
            final newPos = (current + 5000) / duration.inMilliseconds;
            widget.onSeek(newPos.clamp(widget.trimStart, widget.trimEnd));
          },
        ),
        const SizedBox(width: 12),
        _PlaybackButton(
          icon: Icons.skip_next_rounded,
          tooltip: 'Go to end',
          onTap: () => widget.onSeek(widget.trimEnd - 0.01),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIM RANGE SLIDER
// ═══════════════════════════════════════════════════════════════════════════

class _TrimRangeSlider extends StatefulWidget {
  final VideoPlayerController? controller;
  final double trimStart;
  final double trimEnd;
  final void Function(double start, double end) onTrimChanged;
  final void Function(double position) onSeek;

  const _TrimRangeSlider({
    required this.controller,
    required this.trimStart,
    required this.trimEnd,
    required this.onTrimChanged,
    required this.onSeek,
  });

  @override
  State<_TrimRangeSlider> createState() => _TrimRangeSliderState();
}

class _TrimRangeSliderState extends State<_TrimRangeSlider> {
  static const double _handleWidth = 24.0;
  static const double _trackHeight = 56.0;

  _DragTarget? _currentDrag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final trackWidth = totalWidth - _handleWidth;

        final startHandleLeft = widget.trimStart * trackWidth;
        final endHandleLeft = widget.trimEnd * trackWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              _onDragStart(details, trackWidth),
          onHorizontalDragUpdate: (details) =>
              _onDragUpdate(details, trackWidth),
          onHorizontalDragEnd: (_) => _onDragEnd(),
          onTapUp: (details) => _onTap(details, trackWidth),
          child: SizedBox(
            height: _trackHeight + 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _handleWidth / 2,
                  right: _handleWidth / 2,
                  top: 8,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _ReelEditTheme.of(context).surface2,
                      borderRadius: BorderRadius.circular(4),
                      border:
                      Border.all(color: _ReelEditTheme.of(context).border),
                    ),
                    child: CustomPaint(
                      painter: _TimelineGridPainter(
                        borderColor: _ReelEditTheme.of(context).border,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _handleWidth / 2,
                  top: 8,
                  width: startHandleLeft,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: endHandleLeft + _handleWidth / 2,
                  right: _handleWidth / 2,
                  top: 8,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: startHandleLeft + _handleWidth / 2,
                  width: endHandleLeft - startHandleLeft,
                  top: 8,
                  height: _trackHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: _ReelEditTheme.of(context).accent,
                            width: 3),
                        bottom: BorderSide(
                            color: _ReelEditTheme.of(context).accent,
                            width: 3),
                      ),
                      color:
                      _ReelEditTheme.of(context).accent.withOpacity(0.08),
                    ),
                  ),
                ),
                if (widget.controller != null &&
                    widget.controller!.value.isInitialized)
                  _buildPlayhead(trackWidth),
                Positioned(
                  left: startHandleLeft,
                  top: 4,
                  child: _TrimHandle(
                    isStart: true,
                    isActive: _currentDrag == _DragTarget.start,
                    height: _trackHeight + 8,
                    width: _handleWidth,
                  ),
                ),
                Positioned(
                  left: endHandleLeft,
                  top: 4,
                  child: _TrimHandle(
                    isStart: false,
                    isActive: _currentDrag == _DragTarget.end,
                    height: _trackHeight + 8,
                    width: _handleWidth,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildTimeLabels(trackWidth),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayhead(double trackWidth) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller!,
      builder: (_, value, __) {
        final duration = value.duration.inMilliseconds;
        if (duration == 0) return const SizedBox.shrink();

        final position = value.position.inMilliseconds / duration;
        final left = position * trackWidth + _handleWidth / 2;

        return Positioned(
          left: left - 1.5,
          top: 4,
          child: Container(
            width: 3,
            height: _trackHeight + 8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeLabels(double trackWidth) {
    final duration = widget.controller?.value.duration ?? Duration.zero;

    return Padding(
      padding:
      EdgeInsets.only(left: _handleWidth / 2, right: _handleWidth / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatTime(
                (duration.inMilliseconds * widget.trimStart).round()),
            style: _DS.label(context,
                size: 9, color: _ReelEditTheme.of(context).accent),
          ),
          Text(
            _formatTime((duration.inMilliseconds * widget.trimEnd).round()),
            style: _DS.label(context,
                size: 9, color: _ReelEditTheme.of(context).accent),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final seconds = (ms / 1000).floor();
    final millis = ((ms % 1000) / 100).floor();
    return '$seconds.${millis}s';
  }

  void _onDragStart(DragStartDetails details, double trackWidth) {
    final localX = details.localPosition.dx;

    final startHandleCenter =
        widget.trimStart * trackWidth + _handleWidth / 2;
    final endHandleCenter = widget.trimEnd * trackWidth + _handleWidth / 2;

    final distToStart = (localX - startHandleCenter).abs();
    final distToEnd = (localX - endHandleCenter).abs();

    const touchTolerance = 40.0;

    if (distToStart < touchTolerance && distToStart <= distToEnd) {
      setState(() => _currentDrag = _DragTarget.start);
      _DS.hapticLight();
    } else if (distToEnd < touchTolerance) {
      setState(() => _currentDrag = _DragTarget.end);
      _DS.hapticLight();
    } else {
      setState(() => _currentDrag = _DragTarget.playhead);
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    if (_currentDrag == null) return;

    final delta = details.delta.dx / trackWidth;

    switch (_currentDrag!) {
      case _DragTarget.start:
        final newStart =
        (widget.trimStart + delta).clamp(0.0, widget.trimEnd - 0.05);
        widget.onTrimChanged(newStart, widget.trimEnd);
        widget.onSeek(newStart);
        break;

      case _DragTarget.end:
        final newEnd =
        (widget.trimEnd + delta).clamp(widget.trimStart + 0.05, 1.0);
        widget.onTrimChanged(widget.trimStart, newEnd);
        widget.onSeek(newEnd);
        break;

      case _DragTarget.playhead:
        final position =
            (details.localPosition.dx - _handleWidth / 2) / trackWidth;
        final clampedPosition =
        position.clamp(widget.trimStart, widget.trimEnd);
        widget.onSeek(clampedPosition);
        break;
    }
  }

  void _onDragEnd() {
    setState(() => _currentDrag = null);
  }

  void _onTap(TapUpDetails details, double trackWidth) {
    final localX = details.localPosition.dx;
    final position = (localX - _handleWidth / 2) / trackWidth;
    final clampedPosition = position.clamp(widget.trimStart, widget.trimEnd);
    widget.onSeek(clampedPosition);
  }
}

enum _DragTarget { start, end, playhead }

// ═══════════════════════════════════════════════════════════════════════════
// TRIM HANDLE
// ═══════════════════════════════════════════════════════════════════════════

class _TrimHandle extends StatelessWidget {
  final bool isStart;
  final bool isActive;
  final double height;
  final double width;

  const _TrimHandle({
    required this.isStart,
    required this.isActive,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isActive
            ? _ReelEditTheme.of(context).accent
            : _ReelEditTheme.of(context).accent.withOpacity(0.9),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(6) : Radius.zero,
          right: isStart ? Radius.zero : const Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? _ReelEditTheme.of(context).accent.withOpacity(0.5)
                : Colors.black.withOpacity(0.3),
            blurRadius: isActive ? 12 : 4,
            spreadRadius: isActive ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isStart ? Icons.chevron_right : Icons.chevron_left,
              color: Colors.black.withOpacity(0.5),
              size: 16,
            ),
            const SizedBox(height: 2),
            ...List.generate(
                3,
                    (_) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMELINE GRID PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _TimelineGridPainter extends CustomPainter {
  const _TimelineGridPainter({required this.borderColor});
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;

    const segments = 20;
    for (int i = 0; i <= segments; i++) {
      final x = (size.width / segments) * i;
      final isMain = i % 5 == 0;

      paint.color = borderColor.withOpacity(isMain ? 0.5 : 0.2);

      canvas.drawLine(
        Offset(x, isMain ? 0 : size.height * 0.3),
        Offset(x, size.height),
        paint,
      );
    }

    paint.color = borderColor.withOpacity(0.3);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAYBACK BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _PlaybackButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;

  const _PlaybackButton({
    required this.icon,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: () async {
          await _DS.hapticLight();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _ReelEditTheme.of(context).surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _ReelEditTheme.of(context).border),
          ),
          child:
          Icon(icon, color: _ReelEditTheme.of(context).textSec, size: 22),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LAYER PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _LayerPainter extends CustomPainter {
  final List<_Layer> layers;
  final List<Offset?> currentStroke;
  final Color currentColor;
  final double currentStrokeWidth;
  final _BrushType currentBrush;

  const _LayerPainter({
    required this.layers,
    required this.currentStroke,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentBrush,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final layer in layers) {
      if (layer is _DrawLayer) {
        _paintStroke(
            canvas, layer.points, layer.color, layer.strokeWidth, layer.brush);
      }
    }

    if (currentStroke.isNotEmpty) {
      _paintStroke(canvas, currentStroke, currentColor, currentStrokeWidth,
          currentBrush);
    }

    canvas.restore();
  }

  void _paintStroke(Canvas canvas, List<Offset?> points, Color color,
      double width, _BrushType brush) {
    if (points.isEmpty) return;

    final path = _buildPath(points);

    switch (brush) {
      case _BrushType.pen:
        canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..strokeWidth = width
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..style = PaintingStyle.stroke);

      case _BrushType.marker:
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.55)
              ..strokeWidth = width * 2.5
              ..strokeCap = StrokeCap.square
              ..style = PaintingStyle.stroke);

      case _BrushType.neon:
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.3)
              ..strokeWidth = width * 4
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
              ..style = PaintingStyle.stroke);
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withOpacity(0.6)
              ..strokeWidth = width * 2
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
              ..style = PaintingStyle.stroke);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white
              ..strokeWidth = width * 0.5
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);

      case _BrushType.eraser:
        canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.clear
              ..strokeWidth = width * 3
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);
    }
  }

  Path _buildPath(List<Offset?> points) {
    final path = Path();
    bool needsMove = true;

    for (final point in points) {
      if (point == null) {
        needsMove = true;
        continue;
      }
      if (needsMove) {
        path.moveTo(point.dx, point.dy);
        needsMove = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(_LayerPainter oldDelegate) {
    return oldDelegate.currentStroke != currentStroke ||
        oldDelegate.layers.length != layers.length ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CROP OVERLAY
// ═══════════════════════════════════════════════════════════════════════════

class _CropOverlay extends StatelessWidget {
  final Rect rect;
  final ValueChanged<Rect> onRectChanged;

  const _CropOverlay({required this.rect, required this.onRectChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final left = rect.left * width;
        final top = rect.top * height;
        final right = rect.right * width;
        final bottom = rect.bottom * height;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter:
                _CropDimPainter(Rect.fromLTRB(left, top, right, bottom)),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: right - left,
              height: bottom - top,
              child: CustomPaint(painter: _GridPainter()),
            ),
            Positioned(
              left: left,
              top: top,
              width: right - left,
              height: bottom - top,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _ReelEditTheme.of(context).accent, width: 2),
                ),
              ),
            ),
            _buildCornerHandle(
                context, left - 12, top - 12, 1, 1, width, height),
            _buildCornerHandle(
                context, right - 12, top - 12, -1, 1, width, height),
            _buildCornerHandle(
                context, left - 12, bottom - 12, 1, -1, width, height),
            _buildCornerHandle(
                context, right - 12, bottom - 12, -1, -1, width, height),
            Positioned(
              left: left + 24,
              top: top + 24,
              width: right - left - 48,
              height: bottom - top - 48,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (d) {
                  final newRect = Rect.fromLTRB(
                    ((left + d.delta.dx) / width).clamp(0, 1 - rect.width),
                    ((top + d.delta.dy) / height).clamp(0, 1 - rect.height),
                    ((right + d.delta.dx) / width).clamp(rect.width, 1),
                    ((bottom + d.delta.dy) / height).clamp(rect.height, 1),
                  );
                  onRectChanged(newRect);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCornerHandle(BuildContext context, double x, double y,
      double sx, double sy, double containerWidth, double containerHeight) {
    return Positioned(
      left: x,
      top: y,
      width: 24,
      height: 24,
      child: GestureDetector(
        onPanUpdate: (d) {
          final newRect = Rect.fromLTRB(
            sx > 0
                ? ((rect.left * containerWidth + d.delta.dx) / containerWidth)
                .clamp(0, rect.right - 0.1)
                : rect.left,
            sy > 0
                ? ((rect.top * containerHeight + d.delta.dy) / containerHeight)
                .clamp(0, rect.bottom - 0.1)
                : rect.top,
            sx < 0
                ? ((rect.right * containerWidth + d.delta.dx) / containerWidth)
                .clamp(rect.left + 0.1, 1)
                : rect.right,
            sy < 0
                ? ((rect.bottom * containerHeight + d.delta.dy) /
                containerHeight)
                .clamp(rect.top + 0.1, 1)
                : rect.bottom,
          );
          onRectChanged(newRect);
        },
        child: Container(
          decoration: BoxDecoration(
            color: _ReelEditTheme.of(context).accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _CropDimPainter extends CustomPainter {
  final Rect cropRect;
  _CropDimPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(_CropDimPainter oldDelegate) =>
      cropRect != oldDelegate.cropRect;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// VIGNETTE OVERLAY
// ═══════════════════════════════════════════════════════════════════════════

class _VignetteOverlay extends StatelessWidget {
  final double intensity;
  const _VignetteOverlay({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(intensity * 0.85)
          ],
          stops: const [0.5, 1.0],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn(this.icon, {required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            color: color ?? _ReelEditTheme.of(context).textPrim, size: 22),
      ),
    );
  }
}

class _SlimSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool centered;
  final ValueChanged<double> onChanged;

  const _SlimSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _ReelEditTheme.of(context).accent,
        inactiveTrackColor: _ReelEditTheme.of(context).border,
        thumbColor: _ReelEditTheme.of(context).accent,
        overlayColor: _ReelEditTheme.of(context).accent.withOpacity(0.15),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: isActive
            ? _DS.activePill(context)
            : BoxDecoration(borderRadius: BorderRadius.circular(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: isActive
                    ? _ReelEditTheme.of(context).accent
                    : _ReelEditTheme.of(context).textSec),
            const SizedBox(height: 4),
            Text(
              label,
              style: _DS.label(
                context,
                size: 9,
                color: isActive
                    ? _ReelEditTheme.of(context).accent
                    : _ReelEditTheme.of(context).textDim,
                weight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: isSelected ? size + 6 : size,
        height: isSelected ? size + 6 : size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? _ReelEditTheme.of(context).accent
                : _ReelEditTheme.of(context).border,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)]
              : null,
        ),
      ),
    );
  }
}
