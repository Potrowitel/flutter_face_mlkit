import 'package:camera/camera.dart';

enum CameraType {
  front,
  back,
  external;

  CameraLensDirection toLensDirection() {
    switch (this) {
      case CameraType.front:
        return CameraLensDirection.front;
      case CameraType.back:
        return CameraLensDirection.back;
      case CameraType.external:
        return CameraLensDirection.external;
    }
  }
}

CameraDescription findCamera(
    {required CameraType type, required List<CameraDescription> cameras}) {
  return cameras.firstWhere((e) => e.lensDirection == type.toLensDirection());
}
