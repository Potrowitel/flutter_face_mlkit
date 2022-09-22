// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

@pragma("vm:entry-point")
class ScannerUtils {
  ScannerUtils._();

  static Uint8List concatenatePlanes(List<Plane> planes) {
    return _concatenatePlanes(planes);
  }

  static Future<String> detectText(String path) async {
    String? text;
    try {
      var textRecognizer = TextRecognizer();
      var textData =
          await textRecognizer.processImage(InputImage.fromFilePath(path));
      text = textData.text;
      await textRecognizer.close();
    } catch (_) {}
    return text ?? '';
  }

  static Future<CameraDescription> getCamera(CameraLensDirection dir) async {
    return await availableCameras().then(
      (List<CameraDescription> cameras) => cameras.firstWhere(
        (CameraDescription camera) => camera.lensDirection == dir,
      ),
    );
  }

  static Future<dynamic> detect({
    required CameraImage image,
    required Future<dynamic> Function(InputImage image) detectInImage,
    required int imageRotation,
  }) async {
     print(image.planes.length);

    return await detectInImage(
      InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        // image.planes[0].bytes,
        inputImageData:
            _buildMetaData(image, _rotationIntToImageRotation(imageRotation)),
      ),
    );
  }

  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  static InputImageData _buildMetaData(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    return InputImageData(
      inputImageFormat: InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21,
      size: Size(image.width.toDouble(), image.height.toDouble()),
      imageRotation: rotation,
      planeData: image.planes.map(
        (Plane plane) {
          return InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        },
      ).toList(),
    );
  }

  static InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      default:
        assert(rotation == 270);
        return InputImageRotation.rotation270deg;
    }
  }
}
