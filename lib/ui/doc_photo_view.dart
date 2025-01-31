import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/ui/doc_shape.dart';
import 'package:flutter_face_mlkit/utils/camera_type.dart';
import 'package:flutter_face_mlkit/utils/capture_button.dart';
import 'package:image/image.dart' as img;

class DocPhotoView extends StatefulWidget {
  final Function(File file) onCapture;
  final Function(File file)? onCroppedImage;
  final CameraType cameraType;
  final double aspectRatio;
  final Widget? bottom;
  const DocPhotoView({
    super.key,
    required this.onCapture,
    this.onCroppedImage,
    this.cameraType = CameraType.front,
    this.bottom,
    this.aspectRatio = 1.586,
  });

  @override
  State<DocPhotoView> createState() => _DocPhotoViewState();
}

class _DocPhotoViewState extends State<DocPhotoView> {
  late final AppLifecycleListener _appLifecycleListener;

  CameraController? _controller;

  List<CameraDescription>? _cameras;

  dynamic exception;

  bool captureAnimation = false;
  bool onCapture = false;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      binding: WidgetsBinding.instance,
      onStateChange: _didChangeAppLifecycleState,
    );
    _initializeCameraController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _appLifecycleListener.dispose();
    super.dispose();
  }

  void _didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController();
    }
  }

  void _initializeCameraController() async {
    try {
      _cameras = _cameras ?? await availableCameras();
      CameraDescription cameraDescription =
          findCamera(type: widget.cameraType, cameras: _cameras!);
      _controller = CameraController(
          cameraDescription, ResolutionPreset.ultraHigh,
          enableAudio: false);
      _controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    } catch (err) {
      exception = err;
      setState(() {});
    }
  }

  void crop(String path) async {
    img.Image? image = await img.decodeJpgFile(path);
    if (image != null) {
      Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      double width = image.width * 0.9;
      double height = width / widget.aspectRatio;

      double y = (imageSize.height / 2) - (height / 2);
      double x = (imageSize.width * 0.1) / 2;

      await (img.Command()
            ..image(image)
            ..copyCrop(
                x: x.ceil(),
                y: y.ceil(),
                width: width.ceil(),
                height: height.ceil())
            ..writeToFile(path))
          .executeThread();

      if (widget.onCroppedImage != null) {
        widget.onCroppedImage!(File(path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller?.value.isInitialized == true) {
      final double aspectRatio = _controller!.value.aspectRatio;
      final double mediaHeight = MediaQuery.sizeOf(context).height;
      final double mediaWidth = MediaQuery.sizeOf(context).width;

      double controllersHeight = (mediaHeight - (mediaWidth * aspectRatio)) / 2;

      if (controllersHeight < 110) {
        controllersHeight = 110;
      }

      return ColoredBox(
        color: Color(0xFF1F2328),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: CameraPreview(
                _controller!,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        DocOverlay(
                          height: constraints.maxHeight,
                          width: constraints.maxWidth,
                          borderColor: Colors.white,
                          aspectRatio: widget.aspectRatio,
                          overlayColor:
                              Color(0xFF292933).withValues(alpha: 0.6),
                        ),
                        if (widget.bottom != null)
                          Positioned(
                            top: constraints.maxHeight / 2 +
                                (constraints.maxWidth / widget.aspectRatio) / 2,
                            child: widget.bottom!,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 100),
                opacity: captureAnimation ? 1 : 0,
                child: Container(
                  height: double.infinity,
                  width: double.infinity,
                  color: Colors.black,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints.expand(height: controllersHeight),
                decoration: BoxDecoration(
                  color: Color(0xFF1F2328),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CaptureButton(
                      onTap: () async {
                        if (!onCapture) {
                          onCapture = true;
                          setState(() {
                            captureAnimation = true;
                          });
                          Future.delayed(Duration(milliseconds: 50)).then((_) {
                            setState(() {
                              captureAnimation = false;
                            });
                          });
                          XFile? file = await _controller?.takePicture();
                          if (file != null) {
                            if (widget.onCroppedImage != null) {
                              crop(file.path);
                            }
                            widget.onCapture.call(File(file.path));
                          }
                          onCapture = false;
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (exception != null) {
      return Center(child: Text(exception.toString()));
    } else {
      return Container(
        decoration: BoxDecoration(color: Color(0xFF1F2328)),
        child: Center(child: CircularProgressIndicator()),
      );
    }
  }
}

class DocOverlay extends StatelessWidget {
  const DocOverlay({
    super.key,
    required double height,
    required double width,
    required this.aspectRatio,
    this.overlayColor,
    this.borderColor,
  })  : _height = height,
        _width = width;

  final double _height;
  final double _width;
  final Color? overlayColor;
  final Color? borderColor;

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final double width = _width * 0.9;

    return Container(
      decoration: ShapeDecoration(
          shape: PassOverlayShape(
        cutOutBottomOffset: 0,
        aspectRatio: aspectRatio,
        borderColor: borderColor,
        cutOutHeight: width / aspectRatio,
        cutOutWidth: width,
        borderLength: width / 2,
        borderWidth: 0.1,
        overlayColor: overlayColor ?? const Color.fromRGBO(0, 0, 0, 80),
      )),
      padding: const EdgeInsets.symmetric(vertical: 28),
      height: _height,
      width: _width,
    );
  }
}
