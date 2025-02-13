import 'package:camera/camera.dart';

enum Resolution {
  low,
  medium,
  high,
  veryHigh,
  max,
  ultraHigh;

  ResolutionPreset toResolution() {
    switch (this) {
      case Resolution.low:
        return ResolutionPreset.low;
      case Resolution.medium:
        return ResolutionPreset.medium;
      case Resolution.high:
        return ResolutionPreset.high;
      case Resolution.veryHigh:
        return ResolutionPreset.veryHigh;
      case Resolution.ultraHigh:
        return ResolutionPreset.ultraHigh;
      case Resolution.max:
        return ResolutionPreset.max;
    }
  }
}
