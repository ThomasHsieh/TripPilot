import 'dart:io';

import 'package:flutter/material.dart';

/// 全螢幕相片檢視（可縮放、左右滑動切換）。
Future<void> showPhotoViewer(
  BuildContext context,
  List<String> paths,
  int index,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewer(paths: paths, initialIndex: index),
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.paths, required this.initialIndex});
  final List<String> paths;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: paths.length,
        itemBuilder: (BuildContext context, int i) {
          final String path = paths[i];
          const Widget err = Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 64,
          );
          final Widget image = path.startsWith('assets/')
              ? Image.asset(path,
                  fit: BoxFit.contain, errorBuilder: (_, __, ___) => err)
              : Image.file(File(path),
                  fit: BoxFit.contain, errorBuilder: (_, __, ___) => err);
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: image),
          );
        },
      ),
    );
  }
}
