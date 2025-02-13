import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/utils/camera_type.dart';
import 'package:flutter_face_mlkit/utils/resolution.dart';
import 'package:video_compress/video_compress.dart';

typedef OverlayBuilder = Function(
    BuildContext context, CameraController controller);

typedef TimerBuilder = Function(BuildContext context, int count);

enum VideoCompressQuality {
  DefaultQuality,
  LowQuality,
  MediumQuality,
  HighestQuality,
  Res640x480Quality,
  Res960x540Quality,
  Res1280x720Quality,
  Res1920x1080Quality;

  VideoQuality toVideoQuality() {
    switch (this) {
      case VideoCompressQuality.DefaultQuality:
        return VideoQuality.DefaultQuality;
      case VideoCompressQuality.LowQuality:
        return VideoQuality.LowQuality;
      case VideoCompressQuality.MediumQuality:
        return VideoQuality.MediumQuality;
      case VideoCompressQuality.HighestQuality:
        return VideoQuality.HighestQuality;
      case VideoCompressQuality.Res640x480Quality:
        return VideoQuality.Res640x480Quality;
      case VideoCompressQuality.Res960x540Quality:
        return VideoQuality.Res960x540Quality;
      case VideoCompressQuality.Res1280x720Quality:
        return VideoQuality.Res1280x720Quality;
      case VideoCompressQuality.Res1920x1080Quality:
        return VideoQuality.Res1920x1080Quality;
    }
  }
}

class VideoView extends StatefulWidget {
  final Function(File file) onComplete;
  final CameraType cameraType;
  final OverlayBuilder? overlay;
  final int timer;
  final TimerBuilder? timerBuilder;
  final Resolution resolution;
  final bool compress;
  final VideoCompressQuality compressQuality;
  const VideoView({
    super.key,
    required this.onComplete,
    this.overlay,
    this.timer = 20,
    this.timerBuilder,
    this.cameraType = CameraType.front,
    this.resolution = Resolution.medium,
    this.compress = false,
    this.compressQuality = VideoCompressQuality.DefaultQuality,
  });

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late final AppLifecycleListener _appLifecycleListener;

  CameraController? _controller;

  List<CameraDescription>? _cameras;

  dynamic exception;

  late final CounterController _counterController;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      binding: WidgetsBinding.instance,
      onStateChange: _didChangeAppLifecycleState,
    );
    _counterController = CounterController(widget.timer);
    _counterController.addListener(_listener);
    _initializeCameraController();
  }

  void _listener() async {
    if (_counterController.value <= 0) {
      XFile? file;
      if (_controller?.value.isRecordingVideo == true) {
        file = await _controller?.stopVideoRecording();
      } else {
        return;
      }
      if (widget.compress) {
        _compressVideo(File(file!.path));
      } else {
        if (file != null) {
          widget.onComplete(File(file.path));
        }
      }
    }
  }

  void _compressVideo(File file) async {
    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      file.path,
      quality: widget.compressQuality.toVideoQuality(),
    );
    if (mediaInfo != null) {
      widget.onComplete(File(mediaInfo.path!));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _appLifecycleListener.dispose();
    _counterController.removeListener(_listener);
    _counterController.dispose();
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
          cameraDescription, widget.resolution.toResolution(),
          enableAudio: false);
      _controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        _controller?.startVideoRecording();
        _counterController.initialize();
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
      return ColoredBox(
        color: Color(0xFF1F2328),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: CameraPreview(
                _controller!,
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 12,
                      child: CloseButton(),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _counterController,
                      builder: (context, value, child) {
                        if (widget.timerBuilder != null) {
                          return widget.timerBuilder!(context, value);
                        } else {
                          return Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              width: 72,
                              margin: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              padding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    value.secondToTime(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (widget.overlay != null && _controller != null)
              widget.overlay!(
                context,
                _controller!,
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

class CloseButton extends StatelessWidget {
  const CloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      width: 32,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(false);
          },
          borderRadius: BorderRadius.circular(32),
          child: Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}

class CounterController extends ValueNotifier<int> {
  Timer? timer;
  late final int initialCount;
  CounterController(super.value) : initialCount = value;

  void initialize() {
    if (timer != null) {
      timer?.cancel();
      timer = null;
      value = initialCount;
    }
    timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) {
        value -= 1;
        if (value == 0) {
          timer.cancel();
        }
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    timer = null;
    super.dispose();
  }
}

extension TimeInteger on int {
  String secondToTime() {
    String result = '';
    int min = this ~/ 60;
    int sec = this % 60;

    result = '$min:${sec < 10 ? "0$sec" : "$sec"}';

    return result;
  }
}
