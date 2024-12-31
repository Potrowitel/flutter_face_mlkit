import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class PhotoScanner {
  PhotoScanner();

  late final FaceDetector _detector;
  bool _initialized = false;

  void initial() {
    _detector = FaceDetector(
        options: FaceDetectorOptions(
      enableClassification: true,
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ));
    _initialized = true;
  }

  Future<Face> detect(String path) async {
    if (_initialized) {
      print(path);
      List<Face> faces =
          await _detector.processImage(InputImage.fromFile(File(path)));
      print(faces);
      if (faces.isEmpty) {
        throw Exception('Face not found');
      } else if (faces.length == 1) {
        return faces.first;
      } else {
        throw Exception('Too many faces');
      }
    }
    throw Exception('Not initialized');
  }

  void dispose() async {
    _initialized = false;
    await _detector.close();
  }
}
