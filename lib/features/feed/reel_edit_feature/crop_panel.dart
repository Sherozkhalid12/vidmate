part of '../reel_edit_screen.dart';

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
