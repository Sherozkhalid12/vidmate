part of '../reel_edit_screen.dart';

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

enum _Tool { none, paint, text, sticker, filter, adjust, crop, trim, audio }
