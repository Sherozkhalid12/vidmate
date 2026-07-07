part of '../reel_edit_screen.dart';

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
