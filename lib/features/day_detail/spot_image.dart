import 'dart:io';

import 'package:flutter/material.dart';

/// 景點圖片：自動分辨內建範例資產（`assets/...`）與 App 沙盒檔案路徑。
class SpotImage extends StatelessWidget {
  const SpotImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final String path;
  final double? width;
  final double? height;
  final double borderRadius;

  bool get _isAsset => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext context) => Container(
          width: width,
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        );

    final Widget img = _isAsset
        ? Image.asset(
            path,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext c, _, __) => error(c),
          )
        : Image.file(
            File(path),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext c, _, __) => error(c),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: img,
    );
  }
}
