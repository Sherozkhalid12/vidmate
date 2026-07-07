part of '../reel_edit_screen.dart';

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
