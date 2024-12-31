import 'dart:async';
import 'dart:io';

// import 'package:camera/camera.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_mlkit/isolates/face_detection_isolate.dart';
import 'package:flutter_face_mlkit/isolates/face_detection_listener.dart';
import 'package:flutter_face_mlkit/utils/camera_type.dart';
import 'package:rxdart/rxdart.dart';

class FaceScanner {
  CameraController? _camera;

  List<CameraDescription>? _cameras;

  final FaceDetectionIsolate _detector = FaceDetectionIsolate();
  StreamSubscription<dynamic>? _detectorSub;

  final BehaviorSubject<ProcessResponse> _streamFace =
      BehaviorSubject<ProcessResponse>();
  ValueStream<ProcessResponse> get streamFace => _streamFace.stream;
  StreamSubscription<ProcessResponse>? _faceSub;

  final BehaviorSubject<ProcessModel> _streamCamera =
      BehaviorSubject<ProcessModel>();

  StreamSubscription<ProcessModel>? _cameraSub;

  bool initialized = false;

  late final _faceDetectingListener = FaceDetectionListenerImpl(
    onFaceDetecting: (response) {
      if (!_streamFace.isClosed) {
        _streamFace.add(response);
      }
    },
  );

  FaceScanner();

  bool get isInitialized => _camera?.value.isInitialized == true;
  CameraController? get controller => _camera;

 

  Future<void> initial(CameraType type) async {
    if (_camera != null && initialized) {
      await dispose();
      _camera == null;
    }

    _cameras = _cameras ?? await availableCameras();
    if (_cameras?.isEmpty == true) {
      throw Exception();
    }

    final CameraDescription cameraDescription =
        findCamera(cameras: _cameras!, type: type);
    _camera = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _detector.spawn();
    await _camera?.initialize();
    await _camera?.setFlashMode(FlashMode.off);
    _detectorSub = _detector.listen(_faceDetectingListener);
    _faceSub = _streamFace.listen(_faceListen);
    _cameraSub = _streamCamera
        .throttleTime(Duration(milliseconds: 500))
        .listen(_cameraListen);
    initialized = true;
  }

  void _cameraListen(ProcessModel process) {
    print('------------------------------------------------------------');
    print('Frame in process ${process.id} ${DateTime.now()}');
    _detector.send(process);
  }

  void _faceListen(ProcessResponse process) {
    print('Face finded ${process.id} ${process.face} ${DateTime.now()}');
  }

  Future<void> startRecord() async {
    if (_camera == null || _camera?.value.isRecordingVideo == true) return;
    await _camera?.lockCaptureOrientation(DeviceOrientation.portraitUp);

    await _camera?.startImageStream(_recordingListener);

    // await _camera?.prepareForVideoRecording();
    // await _camera?.startVideoRecording(onAvailable: _recordingListener);
  }

  void _recordingListener(CameraImage image) {
    if (_streamCamera.isClosed) return;
    _streamCamera.add(ProcessModel(
      id: DateTime.now().millisecondsSinceEpoch,
      image: image,
      camera: _camera!.description,
      orientation: _camera!.value.deviceOrientation,
    ));
  }

  void pause() {
    _detector.pause();
    _detectorSub?.pause();
    _cameraSub?.pause();
    _faceSub?.pause();
  }

  void resume() {
    _detectorSub?.resume();
    _cameraSub?.resume();
    _faceSub?.resume();
    _detector.resume();
  }

  Future<XFile?> stopVideo() async {
    if (_camera?.value.isRecordingVideo == true) {
      print('STOPPING VIDEO');
      return await _camera?.stopVideoRecording();
    }
    return null;
  }

  void pauseCamera() {
    _camera?.pausePreview();
    if (_camera?.value.isRecordingVideo == true) {
      _camera?.pauseVideoRecording();
    }
    pause();
  }

  void resumeCamera() {
    _camera?.resumePreview();
    if (_camera?.value.isRecordingVideo == true) {
      _camera?.resumeVideoRecording();
    }
    resume();
  }

  Future<void> dispose() async {
    initialized = false;
    await _cameraSub?.cancel();
    await _detectorSub?.cancel();
    await _faceSub?.cancel();
    await _detector.dispose();
    await _camera?.dispose();
    await _streamCamera.close();
    await _streamFace.close();
    _camera = null;
    _faceSub = null;
    _detectorSub = null;
  }
}
