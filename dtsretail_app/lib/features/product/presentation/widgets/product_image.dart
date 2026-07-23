import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.borderRadius = 12,
    this.fallbackIconSize = 28,
  });

  final String? imageUrl;
  final String heroTag;
  final double borderRadius;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: (imageUrl == null || imageUrl!.isEmpty) ? _fallback() : _networkImage(imageUrl!),
      ),
    );
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surfaceTint,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined, size: fallbackIconSize, color: AppColors.primary.withValues(alpha: 0.4)),
    );
  }
}
