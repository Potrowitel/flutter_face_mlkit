import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:drawing_animation/drawing_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_face_mlkit/camera_view.dart';
import 'package:flutter_face_mlkit/utils/camera_info.dart';
import 'package:flutter_face_mlkit/utils/face_detector_painter.dart';
import 'package:flutter_face_mlkit/utils/loading_overlay.dart';
import 'package:flutter_face_mlkit/utils/oval_clipper.dart';
import 'package:flutter_face_mlkit/utils/scanner_utils.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:google_ml_vision/google_ml_vision.dart';

import 'package:path_provider/path_provider.dart';

enum FaceStepType {
  FACE_STEP_FACEDETECTION,
  FACE_STEP_LIVENESS,
  FACE_STEP_CAPTURING
}

enum FaceLivenessType {
  FACE_ANGLE_LEFT,
  FACE_ANGLE_RIGHT,
  FACE_ANGLE_TOP,
  FACE_ANGLE_BOTTOM
}

void _compressFile(Map<String, dynamic> param) async {
  var sendPort = param['port'] as SendPort;
  var file = await FlutterImageCompress.compressAndGetFile(
      param['path']!, param['outPath']!,
      quality: 75);

  sendPort.send(file!.path);
}

typedef void CaptureResult(String? path, CameraInfo info);

class LivenessComponent extends StatefulWidget {
  final Rect? ovalRect;

  final ValueChanged<double>? onLivenessPercentChange;
  final ValueChanged<FaceStepType>? onStepChanged;
  final CaptureResult? onCapturePhoto;
  final CaptureResult? onActionPhoto;

  final FaceLivenessType livenessType;

  final Widget Function(BuildContext, CameraInfo)? infoBlockBuilder;

  LivenessComponent(
      {Key? key,
      this.ovalRect,
      this.livenessType = FaceLivenessType.FACE_ANGLE_LEFT,
      this.onLivenessPercentChange,
      this.infoBlockBuilder,
      this.onCapturePhoto,
      this.onActionPhoto,
      this.onStepChanged})
      : super(key: key);

  @override
  _LivenessComponentState createState() => _LivenessComponentState();
}

class _LivenessComponentState extends State<LivenessComponent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GlobalKey _keyBuilder = GlobalKey();
  static GlobalKey previewContainer = new GlobalKey();
  Future<void>? _initializeControllerFuture;
  CameraController? _controller;

  late CameraDescription _cameraDescription;
  bool _isDetecting = false;
  bool _isTakePhoto = false;
  FaceDetector? _faceDetector;
  Rect? _customOvalRect;

  Face? _face;

  Path? _ovalPath;
  Paint? _ovalPaint;
  AnimationController? _successImageAnimationController;
  Animation<double>? _successImageAnimation;
  bool _isAnimRun = false;

  FaceStepType _faceStepType = FaceStepType.FACE_STEP_FACEDETECTION;

  void _onPercentChange(double percent) {
    widget.onLivenessPercentChange?.call(percent);
  }

  void _onStepChange(FaceStepType type) {
    widget.onStepChanged?.call(type);
  }

  void _onCapturePhoto(String? path) {
    var cameraInfo = CameraInfo(
        CameraLensType.CAMERA_FRONT,
        _controller?.value.aspectRatio ?? 1.0,
        _controller?.value.previewSize ?? Size(1, 1));
    widget.onCapturePhoto?.call(path, cameraInfo);
  }

  void _onActionPhoto(String? path) {
    var cameraInfo = CameraInfo(
        CameraLensType.CAMERA_FRONT,
        _controller?.value.aspectRatio ?? 1.0,
        _controller?.value.previewSize ?? Size(1, 1));
    widget.onActionPhoto?.call(path, cameraInfo);
  }

  Widget _infoBlockBuilder(BuildContext context) {
    var cameraInfo = CameraInfo(
        CameraLensType.CAMERA_FRONT,
        _controller?.value.aspectRatio ?? 1.0,
        _controller?.value.previewSize ?? Size(1, 1));

    return widget.infoBlockBuilder?.call(context, cameraInfo) ??
        SizedBox(height: 0, width: 0);
  }

  bool _isShowOvalArea() {
    return _faceStepType == FaceStepType.FACE_STEP_LIVENESS ||
        _faceStepType == FaceStepType.FACE_STEP_CAPTURING;
  }

  bool _isShowAnimationArea() {
    return _faceStepType == FaceStepType.FACE_STEP_CAPTURING;
  }

  bool _isFaceInOval(Face face) {
    var _faceAngle = face.headEulerAngleY!;
    _faceAngle = _faceAngle > 50.0 ? 50.0 : _faceAngle;

    double _facePercentage = _faceAngle * 100.0 / 50.0;
    print('Face angle percentage = $_facePercentage');

    RenderBox box = _keyBuilder.currentContext!.findRenderObject() as RenderBox;
    final Size size = box.size;
    final Size absoluteImageSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;
    var faceRect = Rect.fromLTRB(
      face.boundingBox.left * scaleX,
      face.boundingBox.top * scaleY,
      face.boundingBox.right * scaleX,
      face.boundingBox.bottom * scaleY,
    );

    if (_facePercentage < -5.0 || _facePercentage > 5.0) {
      return false;
    }
    print('-------------------$_facePercentage----------------');
    print('FACE CONFIRMING = ' +
        faceRect.toString() +
        ' - ' +
        _customOvalRect.toString());
    // if (faceRect.left >= _customOvalRect.left - 30 &&
    //     faceRect.top >= _customOvalRect.top - 30 &&
    //     faceRect.bottom <= _customOvalRect.bottom + 30 &&
    //     faceRect.right <= _customOvalRect.right + 30) {
    if (faceRect.left >= 0 &&
        faceRect.top >= _customOvalRect!.top - 30 &&
        faceRect.bottom <= _customOvalRect!.bottom + 30 &&
        faceRect.right <= absoluteImageSize.width) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> _faceDetectingStep(Face face) async {
    setState(() {
      _faceStepType = FaceStepType.FACE_STEP_LIVENESS;
      _onStepChange(_faceStepType);
    });
  }

  Future<void> _faceLivenessStep(Face face) async {
    var _faceAngleX = face.headEulerAngleY;
    var _faceAngleY = face.headEulerAngleZ;
    var _faceEyeLeft = face.leftEyeOpenProbability;
    var _faceEyeRight = face.rightEyeOpenProbability;

    print(
        '_FACE X = $_faceAngleX; _FACE Z = $_faceAngleY; _FACE LEYE = $_faceEyeLeft; _FACE_REYE = $_faceEyeRight;');

    double? _faceAngle = 0.0;
    if (widget.livenessType == FaceLivenessType.FACE_ANGLE_RIGHT) {
      _faceAngle = Platform.isAndroid
          ? _faceAngleX! < 0.0
              ? _faceAngleX
              : 0.0
          : _faceAngleX! > 0.0
              ? _faceAngleX
              : 0.0;
    } else if (widget.livenessType == FaceLivenessType.FACE_ANGLE_LEFT) {
      _faceAngle = Platform.isAndroid
          ? _faceAngleX! > 0.0
              ? _faceAngleX
              : 0.0
          : _faceAngleX! < 0.0
              ? _faceAngleX
              : 0.0;
    } else if (widget.livenessType == FaceLivenessType.FACE_ANGLE_BOTTOM) {
      _faceAngle = _faceAngleY! > 0.0 ? _faceAngleY * 50 / 16.0 : 0.0;
    } else if (widget.livenessType == FaceLivenessType.FACE_ANGLE_BOTTOM) {
      _faceAngle = _faceAngleY! < 0.0 ? _faceAngleY * 50 / 16.0 : 0.0;
    }

    _faceAngle = _faceAngle.abs();

    _faceAngle = _faceAngle > 50.0 ? 50.0 : _faceAngle;
    double _facePercentage = _faceAngle * 100.0 / 50.0;

    _onPercentChange(_facePercentage);
    if (_facePercentage > 80.0) {
      await _captureAction();
      setState(() {
        _faceStepType = FaceStepType.FACE_STEP_CAPTURING;
        _onStepChange(_faceStepType);
      });
    }
  }

  Future<void> _captureAction() async {
    try {
      await _controller?.stopImageStream();

      var tmpDir = await getTemporaryDirectory();
      var rStr = DateTime.now().microsecondsSinceEpoch.toString();
      var imgPath = '${tmpDir.path}/${rStr}_liveness.jpg';
      var imgCopressedPath = '${tmpDir.path}/${rStr}_compressed_liveness.jpg';

      // RenderRepaintBoundary boundary = previewContainer.currentContext!
      //     .findRenderObject() as RenderRepaintBoundary;
      // ui.Image? image = await boundary.toImage();

      // ByteData? byteData =
      //     await image?.toByteData(format: ui.ImageByteFormat.png);
      // Uint8List? pngBytes = byteData?.buffer.asUint8List();
      // print(pngBytes);
      // File imgFile = new File(imgPath);
      // imgFile.writeAsBytes(pngBytes!);

      // setState(() {});

      await Future.delayed(Duration(milliseconds: 10));
      var imgFile = await _controller!.takePicture();
      // await imgFile.saveTo(imgPath);
      LoadingOverlay.showLoadingOverlay(context);

      var _port = ReceivePort();

      await FlutterIsolate.spawn<Map<String, dynamic>>(_compressFile, {
        'path': imgFile.path,
        'outPath': imgCopressedPath,
        'port': _port.sendPort
      });

      String compressedFile = await _port.first;

      _port.close();

      _onActionPhoto(compressedFile);
      Future.delayed(Duration(milliseconds: 200),
          () async => await _controller?.startImageStream(_streamWorker));
    } catch (err) {
      print(err);
      _onActionPhoto(null);
    } finally {
      LoadingOverlay.removeLoadingOverlay();
    }
  }

  Future<void> _faceCapturingStep(Face face) async {
    if (_isTakePhoto == true) return;

    setState(() {
      _face = face;
    });

    if (_isFaceInOval(face) == true) {
      _isTakePhoto = true;
      try {
        await _controller!.stopImageStream();

        _successImageAnimationController!.forward();
        setState(() => _isAnimRun = true);

        var tmpDir = await getTemporaryDirectory();
        var rStr = DateTime.now().microsecondsSinceEpoch.toString();
        var imgPath = '${tmpDir.path}/${rStr}_selfie.jpg';
        var imgCopressedPath = '${tmpDir.path}/${rStr}_compressed_selfie.jpg';

        await Future.delayed(Duration(milliseconds: 10));
        var imgFile = await _controller!.takePicture();
        // await imgFile.saveTo(imgPath);
        LoadingOverlay.showLoadingOverlay(context);

        var _port = ReceivePort();

        await FlutterIsolate.spawn<Map<String, dynamic>>(_compressFile, {
          'path': imgFile.path,
          'outPath': imgCopressedPath,
          'port': _port.sendPort
        });

        String compressedFile = await _port.first;

        _port.close();

        try {
          List<Face> _faces = await _faceDetector!
              .processImage(GoogleVisionImage.fromFilePath(compressedFile));
          var _faceForCheck = _faces.first;
          _onCapturePhoto(compressedFile);

          //if (_isFaceInOval(_faceForCheck) == true) {
          //  _onCapturePhoto(compressedFile);
          //} else {
          //  _onCapturePhoto(null);
          //}
        } catch (err) {
          print(err);
          _onCapturePhoto(null);
        }
        LoadingOverlay.removeLoadingOverlay();
      } catch (err) {
        LoadingOverlay.removeLoadingOverlay();
        print(err);

        _isTakePhoto = false;
      }
    }
  }

  Future<void> _faceProcessing(Face face) async {
    switch (_faceStepType) {
      case FaceStepType.FACE_STEP_LIVENESS:
        {
          _faceLivenessStep(face);
          break;
        }
      case FaceStepType.FACE_STEP_CAPTURING:
        {
          _faceCapturingStep(face);
          break;
        }
      case FaceStepType.FACE_STEP_FACEDETECTION:
      default:
        {
          _faceDetectingStep(face);
          break;
        }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // App state changed before we got the chance to initialize.
    if (_controller?.value.isInitialized == false) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      print('I am INACTIVE');
      try {
        print('Dispose detector');

        await _faceDetector?.close();
        await _controller?.stopImageStream();
        _controller = null;
      } catch (err) {
        print(err);
      } finally {
        try {
          _controller?.dispose();
        } catch (_) {}
      }
    } else if (state == AppLifecycleState.resumed) {
      print('I am RESUME');
      _initializeCamera();
    }
  }

  void _streamWorker(CameraImage image) {
    if (!mounted) return;
    if (_isDetecting) return;

    _isDetecting = true;

    print('Detect frame ---->');
    ScannerUtils.detect(
      image: image,
      detectInImage: _faceDetector!.processImage,
      imageRotation: _cameraDescription.sensorOrientation,
    )
        .then(
          (dynamic results) {
            if (!mounted) return;

            List<Face> faces = results as List<Face>;
            print('Face detected ---->  ${faces.length.toString()}');
            try {
              var _face = faces.first;
              // if (_true == false) {
              //   _true = true;
              //   var bytes = ScannerUtils.concatenatePlanes(image.planes);
              //   getTemporaryDirectory().then((value) {
              //     var rStr = DateTime.now().microsecondsSinceEpoch.toString();
              //     var imgPath = '${value.path}/${rStr}_ass.jpg';
              //     File(imgPath).writeAsBytesSync(bytes);
              //     _onActionPhoto(imgPath);
              //   });
              // }
              _faceProcessing(_face);
            } catch (err) {
              print(err);
            }
          },
        )
        .whenComplete(() => _isDetecting = false)
        .catchError((err) {
          print(err);
        });
  }

  @override
  void initState() {
    WidgetsBinding.instance?.addObserver(this);
    super.initState();

    _customOvalRect = widget.ovalRect ?? Rect.fromLTWH(50, 50, 250, 350);
    _ovalPath = Path()..addOval(_customOvalRect!);
    _ovalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = Colors.green;
    _successImageAnimationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    _successImageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _successImageAnimationController!,
            curve: Curves.slowMiddle));

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    print('Init camera');
    await Future.delayed(Duration(milliseconds: 100));

    try {
      await _controller?.stopImageStream();
    } catch (_) {}

    try {
      await _controller?.dispose();
      _faceDetector = GoogleVision.instance.faceDetector();
      print('Init description');
      _cameraDescription =
          await ScannerUtils.getCamera(CameraLensDirection.front);

      print('Create controller');
      _controller = CameraController(
        _cameraDescription,
        Platform.isIOS ? ResolutionPreset.veryHigh : ResolutionPreset.high,
        // imageFormatGroup: ImageFormatGroup.jpeg,
      );

      print('Create init controller');
      _initializeControllerFuture = _controller!.initialize();
    } catch (err) {
      print(err);
    }

    // 21307198500031

    if (!mounted) {
      return;
    }
    print('Before init');
    await _initializeControllerFuture;
    print('After init');

    if (!mounted) return;
    setState(() {});

    try {
      print('Start stream');
      await Future.delayed(Duration(milliseconds: 200));
      await _controller?.startImageStream(_streamWorker);
    } catch (err) {
      print(err);
    }
  }

  @override
  void dispose() async {
    WidgetsBinding.instance?.removeObserver(this);
    LoadingOverlay.removeLoadingOverlay();

    try {
      await _faceDetector?.close();

      await _controller?.stopImageStream();
    } catch (err) {
      print(err);
    } finally {
      await _controller?.dispose();
    }

    _successImageAnimationController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Container(
        child: FutureBuilder<void>(
      key: _keyBuilder,
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            _controller?.value.isInitialized == true) {
          final Size imageSize = Size(
            _controller!.value.previewSize!.height,
            _controller!.value.previewSize!.width,
          );
          return Stack(
            children: <Widget>[
              Center(
                  child: RepaintBoundary(
                      key: previewContainer,
                      child: CameraPreview(_controller!))),
              _isShowOvalArea()
                  ? CustomPaint(
                      foregroundPainter: FaceDetectorPainter(
                          imageSize, _face, _customOvalRect),
                      child: ClipPath(
                          clipper: OvalClipper(_customOvalRect),
                          child: Transform.scale(
                              scale:
                                  _controller!.value.aspectRatio / deviceRatio,
                              child: Center(
                                  child: Container(color: Colors.black54)))))
                  : SizedBox(height: 0, width: 0),
              Positioned(
                  top: _customOvalRect!.bottom + 40,
                  left: 0,
                  right: 0,
                  child: Container(child: _infoBlockBuilder(context))),
              _isShowAnimationArea()
                  ? AnimatedBuilder(
                      animation: _successImageAnimationController!,
                      builder: (context, child) {
                        return Positioned(
                            child: Opacity(
                                opacity: _successImageAnimation == null
                                    ? 0.0
                                    : _successImageAnimation!.value,
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 52,
                                )),
                            top: _customOvalRect!.center.dy - 26,
                            left: _customOvalRect!.center.dx - 26);
                      })
                  : SizedBox(height: 0, width: 0),
              _isShowAnimationArea()
                  ? Positioned(
                      top: 0,
                      left: 0,
                      child: AnimatedDrawing.paths(
                        <Path>[_ovalPath!],
                        paints: <Paint>[_ovalPaint!],
                        animationOrder: PathOrder.byLength(),
                        lineAnimation: LineAnimation.oneByOne,
                        animationCurve: Curves.easeInQuad,
                        scaleToViewport: false,
                        width: _customOvalRect!.width,
                        height: _customOvalRect!.height,
                        duration: Duration(milliseconds: 400),
                        run: _isAnimRun,
                        onFinish: () => setState(() => _isAnimRun = false),
                      ),
                    )
                  : SizedBox(height: 0, width: 0)
            ],
          );
        }
        if (snapshot.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Center(
                child: Text(
                  'Произошла ошибка при инициализации камеры. Возможно вы не дали нужные разрешения!',
                  textAlign: TextAlign.center,
                ),
              )
            ],
          );
        }
        return SizedBox(height: 0, width: 0);
      },
    ));
  }
}
