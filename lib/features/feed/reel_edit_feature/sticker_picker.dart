part of '../reel_edit_screen.dart';

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
