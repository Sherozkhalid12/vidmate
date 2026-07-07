part of '../reel_edit_screen.dart';

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
