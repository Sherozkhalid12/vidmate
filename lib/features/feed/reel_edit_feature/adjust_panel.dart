part of '../reel_edit_screen.dart';

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
