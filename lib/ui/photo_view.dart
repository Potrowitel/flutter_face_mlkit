import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/utils/camera_type.dart';

class PhotoView extends StatefulWidget {
  final Function(File file) onCapture;
  final CameraType cameraType;
  const PhotoView({
    super.key,
    required this.onCapture,
    this.cameraType = CameraType.front,
  });

  @override
  State<PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<PhotoView> {
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
          findCamera(type: CameraType.front, cameras: _cameras!);
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
              child: CameraPreview(_controller!),
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
              alignment: Alignment.topCenter,
              child: Container(
                constraints: BoxConstraints.expand(height: controllersHeight),
                decoration: BoxDecoration(
                  color: Color(0xFF1F2328),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        'Сфотографируйте себя',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF323232),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
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

class CaptureButton extends StatelessWidget {
  final VoidCallback? onTap;
  const CaptureButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        padding: EdgeInsets.all(1),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Color(0xFF1F2328),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
