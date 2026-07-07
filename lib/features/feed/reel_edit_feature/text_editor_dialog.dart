part of '../reel_edit_screen.dart';

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
