part of '../reel_edit_screen.dart';

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
