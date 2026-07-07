import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/utils/theme_helper.dart';
import '../../core/widgets/glass_card.dart';

/// Simple center-crop flow for post images.
/// Ensures all images match the aspect ratio best suited for the post card.
class PostCropScreen extends StatefulWidget {
  final List<File> images;

  const PostCropScreen({
    super.key,
    required this.images,
  });

  @override
  State<PostCropScreen> createState() => _PostCropScreenState();
}

class _PostCropScreenState extends State<PostCropScreen> {
  int _currentIndex = 0;
  bool _isSaving = false;
  final Map<int, Rect> _cropRectsByIndex = {};
  final Set<int> _visitedIndexes = {0};
  final List<Size?> _imageSizes = [];
  Offset? _dragStart;
  Rect? _dragStartRect;

  @override
  void initState() {
    super.initState();
    _imageSizes.addAll(List<Size?>.filled(widget.images.length, null));
    _loadImageSizes();
  }

  Future<void> _loadImageSizes() async {
    for (int i = 0; i < widget.images.length; i++) {
      try {
        final bytes = await widget.images[i].readAsBytes();
        final decoded = await decodeImageFromList(bytes);
        if (!mounted) return;
        setState(() {
          _imageSizes[i] = Size(decoded.width.toDouble(), decoded.height.toDouble());
          _cropRectsByIndex.putIfAbsent(
            i,
            () => _centerCropRect(_imageSizes[i]!, 4 / 5),
          );
        });
      } catch (_) {
        // Keep null dimensions for failed decode.
      }
    }
  }

  Future<void> _applyAndReturn() async {
    if (_isSaving || !_allImagesVisited) return;
    setState(() {
      _isSaving = true;
    });

    final List<File> result = [];
    try {
      final dir = await getTemporaryDirectory();
      const targetAspect = 4 / 5; // Portrait, tuned for post card widget

      for (int i = 0; i < widget.images.length; i++) {
        final file = widget.images[i];
        try {
          final bytes = await file.readAsBytes();
          final decoded = img.decodeImage(bytes);
          if (decoded == null) {
            result.add(file);
            continue;
          }
          final cropRect = _cropRectsByIndex[i] ?? _centerCropRect(Size(decoded.width.toDouble(), decoded.height.toDouble()), targetAspect);
          final clampedRect = _clampCropRectToImage(
            cropRect,
            Size(decoded.width.toDouble(), decoded.height.toDouble()),
          );
          final cropped = img.copyCrop(
            decoded,
            x: clampedRect.left.round(),
            y: clampedRect.top.round(),
            width: clampedRect.width.round(),
            height: clampedRect.height.round(),
          );
          final jpg = img.encodeJpg(cropped, quality: 95);
          final out = File(
            '${dir.path}/post_crop_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          );
          await out.writeAsBytes(jpg);
          result.add(out);
        } catch (_) {
          result.add(file);
        }
      }
    } finally {
      if (!mounted) return;
      Navigator.pop(context, result);
    }
  }

  bool get _allImagesVisited => _visitedIndexes.length == widget.images.length;

  Rect _centerCropRect(Size imageSize, double targetAspect) {
    final currentAspect = imageSize.width / imageSize.height;
    double cropW = imageSize.width;
    double cropH = imageSize.height;
    if (currentAspect > targetAspect) {
      cropW = imageSize.height * targetAspect;
    } else {
      cropH = imageSize.width / targetAspect;
    }
    final left = (imageSize.width - cropW) / 2;
    final top = (imageSize.height - cropH) / 2;
    return Rect.fromLTWH(left, top, cropW, cropH);
  }

  Rect _clampCropRectToImage(Rect rect, Size imageSize) {
    final width = math.min(rect.width, imageSize.width);
    final height = math.min(rect.height, imageSize.height);
    final left = rect.left.clamp(0.0, imageSize.width - width);
    final top = rect.top.clamp(0.0, imageSize.height - height);
    return Rect.fromLTWH(left, top, width, height);
  }

  void _switchImage(int index) {
    setState(() {
      _currentIndex = index;
      _visitedIndexes.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final current = widget.images[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: context.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: GlassCard(
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (total > 1) ...[
                          _buildSlider(total),
                          const SizedBox(height: 12),
                        ],
                        AspectRatio(
                          aspectRatio: 4 / 5,
                          child: _buildCropEditor(current),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: ElevatedButton(
                  onPressed: (_isSaving || !_allImagesVisited) ? null : _applyAndReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getAccentColor(context),
                    foregroundColor: ThemeHelper.getOnAccentColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ThemeHelper.getOnAccentColor(context),
                          ),
                        )
                      : Text(
                          _allImagesVisited ? 'Apply crop' : 'Open all images to enable apply',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close, color: context.textPrimary),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        'Crop post',
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildSlider(int total) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        itemBuilder: (context, index) {
          final file = widget.images[index];
          final isSelected = index == _currentIndex;
          final isVisited = _visitedIndexes.contains(index);
          return GestureDetector(
            onTap: () => _switchImage(index),
            child: Container(
              width: 72,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? ThemeHelper.getAccentColor(context)
                      : ThemeHelper.getBorderColor(context),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      file,
                      fit: BoxFit.cover,
                    ),
                    if (isVisited)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: ThemeHelper.getAccentColor(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: ThemeHelper.getOnAccentColor(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCropEditor(File currentFile) {
    final imageSize = _imageSizes[_currentIndex];
    if (imageSize == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black12,
        ),
        child: Center(
          child: CircularProgressIndicator(color: ThemeHelper.getAccentColor(context)),
        ),
      );
    }

    final cropRect = _cropRectsByIndex[_currentIndex] ?? _centerCropRect(imageSize, 4 / 5);
    _cropRectsByIndex[_currentIndex] = cropRect;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageRect = _computeContainRect(imageSize, constraints.biggest);
        final displayCropRect = _imageRectToDisplayRect(cropRect, imageSize, imageRect);
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  currentFile,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    if (displayCropRect.contains(details.localPosition)) {
                      _dragStart = details.localPosition;
                      _dragStartRect = cropRect;
                    }
                  },
                  onPanUpdate: (details) {
                    if (_dragStart == null || _dragStartRect == null) return;
                    final delta = details.localPosition - _dragStart!;
                    final dxImage = delta.dx * (imageSize.width / imageRect.width);
                    final dyImage = delta.dy * (imageSize.height / imageRect.height);
                    final moved = _dragStartRect!.shift(Offset(dxImage, dyImage));
                    setState(() {
                      _cropRectsByIndex[_currentIndex] = _clampCropRectToImage(moved, imageSize);
                    });
                  },
                  onPanEnd: (_) {
                    _dragStart = null;
                    _dragStartRect = null;
                  },
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      imageRect: imageRect,
                      cropRect: _imageRectToDisplayRect(
                        _cropRectsByIndex[_currentIndex]!,
                        imageSize,
                        imageRect,
                      ),
                      borderColor: ThemeHelper.getAccentColor(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Rect _computeContainRect(Size imageSize, Size boxSize) {
    final imageAspect = imageSize.width / imageSize.height;
    final boxAspect = boxSize.width / boxSize.height;
    double drawWidth;
    double drawHeight;
    double left;
    double top;
    if (imageAspect > boxAspect) {
      drawWidth = boxSize.width;
      drawHeight = drawWidth / imageAspect;
      left = 0;
      top = (boxSize.height - drawHeight) / 2;
    } else {
      drawHeight = boxSize.height;
      drawWidth = drawHeight * imageAspect;
      top = 0;
      left = (boxSize.width - drawWidth) / 2;
    }
    return Rect.fromLTWH(left, top, drawWidth, drawHeight);
  }

  Rect _imageRectToDisplayRect(Rect imageRectCrop, Size imageSize, Rect displayedImageRect) {
    final scaleX = displayedImageRect.width / imageSize.width;
    final scaleY = displayedImageRect.height / imageSize.height;
    return Rect.fromLTWH(
      displayedImageRect.left + imageRectCrop.left * scaleX,
      displayedImageRect.top + imageRectCrop.top * scaleY,
      imageRectCrop.width * scaleX,
      imageRectCrop.height * scaleY,
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;
  final Color borderColor;

  _CropOverlayPainter({
    required this.imageRect,
    required this.cropRect,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final clipPath = Path()..addRect(imageRect);
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(16)));
    final dimPath = Path.combine(PathOperation.difference, clipPath, holePath);
    canvas.drawPath(dimPath, overlayPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(16)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.borderColor != borderColor;
  }
}

