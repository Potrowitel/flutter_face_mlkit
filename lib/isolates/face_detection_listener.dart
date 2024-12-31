
import 'package:flutter_face_mlkit/isolates/face_detection_isolate.dart';

abstract class FaceDetectionListener {
  void onFaceDetect(ProcessResponse response);
}

final class FaceDetectionListenerImpl implements FaceDetectionListener {
  final void Function(ProcessResponse response) onFaceDetecting;

  FaceDetectionListenerImpl({required this.onFaceDetecting});

  @override
  void onFaceDetect(ProcessResponse response) => onFaceDetecting(response);
}
