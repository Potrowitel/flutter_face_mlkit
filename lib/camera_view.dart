import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/isolates/face_detection_isolate.dart';
import 'package:flutter_face_mlkit/providers/mlkit_provider.dart';
import 'package:flutter_face_mlkit/ui/face_scanner_scope.dart';
import 'package:flutter_face_mlkit/ui/face_scanner_state.dart';

/// Only use with [FaceScannerScope]
class LivenessView extends StatelessWidget {
  const LivenessView();

  @override
  Widget build(BuildContext context) {
    final FaceScannerState state = FaceScannerScope.of(context).state;

    if (state.isInitial) {
      return Center(
        child: CircularProgressIndicator(),
      );
    } else if (state.isFail) {
      return GestureDetector(
        onTap: () {
          print(FaceScannerScope.of(context)
              .scanner
              .controller
              ?.value
              .isInitialized);
          print(FaceScannerScope.of(context)
              .scanner
              .controller
              ?.value
              .isPreviewPaused);
          print(FaceScannerScope.of(context)
              .scanner
              .controller
              ?.value
              .isRecordingPaused);
          print(FaceScannerScope.of(context)
              .scanner
              .controller
              ?.value
              .isRecordingVideo);
          print(FaceScannerScope.of(context)
              .scanner
              .controller
              ?.value
              .isStreamingImages);
          print(FaceScannerScope.of(context)
              .scanner
              .controller
              ?.value
              .isTakingPicture);
        },
        child: Center(
          child: Text(state.exception.toString()),
        ),
      );
    } else {
      final CameraController? controller =
          FaceScannerScope.of(context).controller;
      final Size? previewSize = FaceScannerScope.of(context).previewSize;

      // if (isAndroid) {
      //   final bool isRecording = controller.value.isRecordingVideo;
      //   if (isRecording) {
      //     final double aspectRatio =
      //         1 / (previewSize.height / previewSize.width);

      //     cameraView = Center(
      //         child: Transform.rotate(
      //       alignment: Alignment.center,
      //       angle: math.pi / 2,
      //       child: AspectRatio(
      //         aspectRatio: aspectRatio,
      //         child: CameraPreview(
      //           controller,
      //           child: Container(height: 100, width: 100),
      //         ),
      //       ),
      //     ));
      //   } else {
      //     final double aspectRatio = previewSize.height / previewSize.width;

      //     cameraView = Center(
      //         child: AspectRatio(
      //       aspectRatio: aspectRatio,
      //       child: CameraPreview(controller),
      //     ));
      //   }
      // } else {
      //   final double aspectRatio = previewSize.height / previewSize.width;

      //   cameraView = Center(
      //       child: AspectRatio(
      //     aspectRatio: aspectRatio,
      //     child: CameraPreview(controller),
      //   ));
      // }
      if (controller == null || previewSize == null) {
        return SizedBox();
      }

      final double aspectRatio = previewSize.height / previewSize.width;

      final Widget cameraView = Center(
          child: AspectRatio(
        aspectRatio: aspectRatio,
        child: CameraPreview(controller),
      ));

      return Stack(
        children: <Widget>[
          cameraView,
          StreamBuilder<ProcessResponse>(
            stream: FaceScannerScope.of(context).processStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final Size imageSize = snapshot.data!.imageSize!;
                final ProcessResponse data = snapshot.data!;
                return CameraOverlay(
                  imageSize: imageSize,
                  boundaryBox: data.faceBoundaryBox,
                  color: data.inOval ? Colors.green : Colors.red,
                  size: previewSize,
                );
              }
              return SizedBox();
            },
          ),
          // StreamBuilder<ProcessModel>(
          //   stream: FaceScannerScope.of(context).cameraStream,
          //   builder: (context, snapshot) {
          //     if (snapshot.hasData) {
          //       final CameraImage? image = snapshot.data?.image;

          //       if (image?.planes.length == 1) {
          //         return Container(
          //           width: 200,
          //           child: Image.memoryx(image!.planes.first.bytes),
          //         );
          //       }
          //       return SizedBox();
          //     }
          //     return SizedBox();
          //   },
          // ),
        ],
      );
    }
  }
}

enum CameraOverlaType {
  initial,
  focus,
  success,
  error,
}

class DynamicFaceBoundaryBox extends StatelessWidget {
  final Rect? boundaryBox;
  final Color? color;
  final Size imageSize;
  final Size size;
  const DynamicFaceBoundaryBox({
    super.key,
    required this.size,
    required this.imageSize,
    this.boundaryBox,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: FaceBoundaryPainter(
        boundaryBox: boundaryBox,
        imageSize: imageSize,
        color: color,
      ),
    );
  }
}

class FaceBoundaryPainter extends CustomPainter {
  final Rect? boundaryBox;
  final Color? color;
  final Size imageSize;
  const FaceBoundaryPainter({
    required this.imageSize,
    this.boundaryBox,
    this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    if (boundaryBox != null) {
      final rect = transformRect(boundaryBox!, imageSize, size);

      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FaceBoundaryPainter oldDelegate) =>
      oldDelegate.boundaryBox != boundaryBox ||
      oldDelegate.imageSize != imageSize;
}

class CameraOverlay extends StatelessWidget {
  final CameraOverlaType type;
  final Rect? boundaryBox;
  final Color? color;
  final Size size;
  final Size imageSize;

  const CameraOverlay({
    super.key,
    required this.size,
    required this.imageSize,
    this.boundaryBox,
    this.color,
    this.type = CameraOverlaType.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          size: size,
          painter: OverlayPainter(),
        ),
        AnimatedBoundaryBox(
          duration: Duration(milliseconds: 500),
          size: size,
          color: color,
          imageSize: imageSize,
          boundaryBox: boundaryBox,
        ),
      ],
    );
  }
}

class AnimatedBoundaryBox extends ImplicitlyAnimatedWidget {
  final Size size;
  final Size imageSize;
  final Rect? boundaryBox;
  final Color? color;
  const AnimatedBoundaryBox({
    super.key,
    required super.duration,
    required this.imageSize,
    required this.size,
    this.boundaryBox,
    this.color,
  });

  @override
  AnimatedWidgetBaseState<AnimatedBoundaryBox> createState() =>
      _AnimatedBoundaryBoxState();
}

class _AnimatedBoundaryBoxState
    extends AnimatedWidgetBaseState<AnimatedBoundaryBox> {
  RectTween? _boundaryBox;
  ColorTween? _color;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _boundaryBox = visitor(_boundaryBox, widget.boundaryBox,
        (dynamic value) => RectTween(begin: value as Rect)) as RectTween?;
    _color = visitor(_color, widget.color,
        (dynamic value) => ColorTween(begin: value as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = this.animation;
    return DynamicFaceBoundaryBox(
      size: widget.size,
      imageSize: widget.imageSize,
      boundaryBox: _boundaryBox?.evaluate(animation),
      color: _color?.evaluate(animation),
    );
  }
}

class OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double overlaylRelativeWidth = MlkitProvider.ovalRelativeWidth;
    final double overlayAspectRatio = MlkitProvider.ovalAspectRatio;
    final double overlaylWidth = size.width * overlaylRelativeWidth;
    final double overlaylHeight = overlaylWidth / overlayAspectRatio;
    final Size ovalSize = Size(overlaylWidth, overlaylHeight);

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: ovalSize.width,
        height: ovalSize.height);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

Rect transformRect(Rect rectX, Size sizeX, Size sizeY) {
  final scaleX = sizeY.width / sizeX.width;
  final scaleY = sizeY.height / sizeX.height;

  return Rect.fromLTWH(
    rectX.left * scaleX,
    rectX.top * scaleY,
    rectX.width * scaleX,
    rectX.height * scaleY,
  );
}
