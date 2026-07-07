part of '../reel_edit_screen.dart';

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
