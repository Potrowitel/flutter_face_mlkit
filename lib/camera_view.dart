import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/utils/camera_info.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_face_mlkit/utils/loading_overlay.dart';
import 'package:flutter_face_mlkit/utils/scanner_utils.dart';

typedef Widget OverlayBuilder(BuildContext context);

typedef Widget CaptureButtonBuilder(
    BuildContext context, VoidCallback onCapture, CameraInfo cameraInfo);

typedef void CaptureResult(String path, CameraInfo info);

enum CameraLensType { CAMERA_FRONT, CAMERA_BACK }

void _compressFile(Map<String, dynamic> param) async {
  print('Param - $param');
  var sendPort = param['port'] as SendPort;
  var file = await FlutterImageCompress.compressAndGetFile(
      param['path']!, param['outPath']!,
      quality: 75);

  sendPort.send(file!.path);
}

class CameraView extends StatefulWidget {
  final CameraLensType cameraLensType;
  final OverlayBuilder? overlayBuilder;
  final CaptureButtonBuilder? captureButtonBuilder;
  final ValueChanged? onError;
  final CaptureResult? onCapture;

  CameraView(
      {this.cameraLensType = CameraLensType.CAMERA_BACK,
      this.captureButtonBuilder,
      this.overlayBuilder,
      this.onCapture,
      this.onError});

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future? _cameraInitializer;
  bool _isTakePhoto = false;

  Future<void> _initializeCamera() async {
    try {
      await _cameraController?.dispose();
      CameraDescription cameraDesc = await ScannerUtils.getCamera(
          _getCameraLensDirection(widget.cameraLensType));

      _cameraController = CameraController(
          cameraDesc,
          Platform.isIOS
              ? ResolutionPreset.veryHigh
              : ResolutionPreset.veryHigh);
    } catch (err) {
      print(err);
    }

    try {
      _cameraInitializer = _cameraController!.initialize();

      await _cameraInitializer;
    } catch (err) {
      print(err);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _takePhoto() async {
    try {
      if (_isTakePhoto) return;
      _isTakePhoto = true;
      var tmpDir = await getTemporaryDirectory();
      var rStr = DateTime.now().microsecondsSinceEpoch.toString();
      var imgPath = '${tmpDir.path}/${rStr}_photo.jpg';
      var imgCopressedPath = '${tmpDir.path}/${rStr}_compressed_photo.jpg';

      ReceivePort _port = ReceivePort();

      await Future.delayed(Duration(milliseconds: 300));
      var imgFile = await _cameraController!.takePicture();
      await imgFile.saveTo(imgPath);
      LoadingOverlay.showLoadingOverlay(context);

      await FlutterIsolate.spawn<Map<String, dynamic>>(_compressFile, {
        'path': imgPath,
        'outPath': imgCopressedPath,
        'port': _port.sendPort
      });

      String compressedFile = await _port.first;

      _port.close();

      LoadingOverlay.removeLoadingOverlay();
      _isTakePhoto = false;
      _onCapture(compressedFile);
    } catch (err) {
      _isTakePhoto = false;
      _onError(err);
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
    try {
      _initializeCamera();
    } catch (err) {
      _onError(err);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    LoadingOverlay.removeLoadingOverlay();

    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      // if (_cameraController != null) {
      //   _cameraInitializer = _cameraController!.initialize();

      //   _initializeCamera(null);
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Container(
      child: FutureBuilder(
        future: _cameraInitializer,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _cameraController?.value.isInitialized == true) {
              var cameraInfo = CameraInfo(
        widget.cameraLensType,
        _cameraController?.value?.aspectRatio ?? 1.0,
        _cameraController?.value?.previewSize ?? Size(1, 1));
            return Stack(
              children: <Widget>[
                Center(child: CameraPreview(_cameraController!)),
                _overlayBuilder(context),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child:
                        _captureButtonBuilder(context, _takePhoto, cameraInfo))
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
                    style: TextStyle(color: Colors.red),
                  ),
                )
              ],
            );
          }
          return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Center(
                  child: Text(
                    'Произошла ошибка при инициализации камеры. Возможно вы не дали нужные разрешения!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                )
              ],
            );
        },
      ),
    );
  }

  Widget _overlayBuilder(context) {
    if (widget.overlayBuilder != null) {
      return widget.overlayBuilder!(context);
    } else {
      return SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget _captureButtonBuilder(
      BuildContext context, VoidCallback onCapture, CameraInfo cameraInfo) {
    if (widget.captureButtonBuilder != null) {
      return widget.captureButtonBuilder!(context, onCapture, cameraInfo);
    } else {
      return SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  void _onError(error) {
    if (widget.onError != null) {
      widget.onError!(error);
    }
  }

  void _onCapture(path) {
    var cameraInfo = CameraInfo(
        widget.cameraLensType,
        _cameraController?.value.aspectRatio ?? 1.0,
        _cameraController?.value.previewSize ?? Size(1, 1));
    widget.onCapture?.call(path, cameraInfo);
  }

  CameraLensDirection _getCameraLensDirection(CameraLensType type) {
    switch (type) {
      case CameraLensType.CAMERA_FRONT:
        return CameraLensDirection.front;
      case CameraLensType.CAMERA_BACK:
      default:
        return CameraLensDirection.back;
    }
  }
}
