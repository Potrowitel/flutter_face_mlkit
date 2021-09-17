import 'dart:ui';

import 'package:flutter_face_mlkit/camera_view.dart';

class CameraInfo {
  final CameraLensType lensType;
  final double aspectRatio;
  final Size? previewSize;

  CameraInfo(this.lensType, this.aspectRatio, this.previewSize);

  @override
  String toString() =>
      'CameraInfo(lensType: $lensType, aspectRatio: $aspectRatio, previewSize: $previewSize)';
}
