import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart'
    show
        BackgroundIsolateBinaryMessenger,
        DeviceOrientation,
        Offset,
        Rect,
        RootIsolateToken,
        Size;
import 'package:flutter_face_mlkit/isolates/face_detection_listener.dart';
import 'package:flutter_face_mlkit/providers/mlkit_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionIsolate {
  FaceDetectionIsolate();

  Isolate? _imageProcess;
  SendPort? _processSendPort;
  ReceivePort? _processRecievePort;

  Capability? _pauseCapability;

  RootIsolateToken token = RootIsolateToken.instance!;

  Future<void> spawn() async {
    ReceivePort receivePort = ReceivePort();
    if (_imageProcess != null) {
      _imageProcess?.kill();
    }
    _imageProcess = await Isolate.spawn<SendPort>(
        _isolateImageProcess, receivePort.sendPort);

    _processSendPort = await receivePort.first;
    _processRecievePort = ReceivePort();
  }

  void send(ProcessModel process) {
    _processSendPort?.send([process, _processRecievePort?.sendPort, token]);
  }

  StreamSubscription<dynamic>? listen(FaceDetectionListener listener) {
    return _processRecievePort?.listen(
      (message) => listener.onFaceDetect(message),
    );
  }

  void pause() {
    if (_pauseCapability == null) {
      _pauseCapability = Capability();
      _imageProcess?.pause(_pauseCapability);
    }
    _imageProcess?.terminateCapability;
  }

  void resume() {
    if (_pauseCapability != null) {
      _imageProcess?.resume(_pauseCapability!);
      _pauseCapability = null;
    }
  }

  Future<void> dispose() async {
    _imageProcess?.kill();
    _imageProcess = null;
    _pauseCapability = null;
  }
}

@pragma('vm:entry-point')
void _isolateImageProcess(SendPort port) {
  ReceivePort receivePort = ReceivePort();

  port.send(receivePort.sendPort);

  bool _faceInOval(Face face, CameraImage image) {
    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final double overlaylRelativeWidth = MlkitProvider.ovalRelativeWidth;
    final double overlayAspectRatio = MlkitProvider.ovalAspectRatio;
    final double overlaylWidth = imageSize.width * overlaylRelativeWidth;
    final double overlaylHeight = overlaylWidth / overlayAspectRatio;
    final Size ovalSize = Size(overlaylWidth, overlaylHeight);

    final Rect ovalRect = Rect.fromCenter(
        center: Offset(imageSize.width, imageSize.height) / 2,
        width: ovalSize.width,
        height: ovalSize.height);

    final Rect boundaryBox = face.boundingBox;

    if ((ovalRect.contains(boundaryBox.topLeft) &&
            ovalRect.contains(boundaryBox.bottomLeft) ||
        ovalRect.contains(boundaryBox.topRight) &&
            ovalRect.contains(boundaryBox.bottomRight) &&
            ovalRect.contains(boundaryBox.center))) {
      return true;
    }
    return false;
  }

  FaceDetector detector = FaceDetector(
      options: FaceDetectorOptions(
    performanceMode: FaceDetectorMode.accurate,
    enableClassification: true,
    enableContours: true,
    enableLandmarks: true,
    enableTracking: true,
  ));

  receivePort.listen((data) async {
    final ProcessModel process = data[0] as ProcessModel;
    final SendPort sendPort = data[1];
    BackgroundIsolateBinaryMessenger.ensureInitialized(data[2]);

    final CameraImage image = process.image;
    final int orientation = process.camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(orientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[process.orientation];
      if (rotationCompensation == null) return;
      rotationCompensation =
          (process.camera.sensorOrientation + rotationCompensation) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      rotation = InputImageRotation.rotation180deg;
      print('Rotation $rotation');
    }

    if (rotation == null) {
      sendPort.send(ProcessResponse(
          id: process.id, image: image, exception: Exception()));
      return;
    }
    final InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      sendPort.send(ProcessResponse(
          id: process.id, image: image, exception: Exception()));
      return;
    }

    if (image.planes.length != 1) {
      sendPort.send(ProcessResponse(
          id: process.id, image: image, exception: Exception()));
      return;
    }
    final plane = image.planes.first;

    InputImage res = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );

    try {
      List<Face> faces = await detector.processImage(res);
      if (faces.length == 1) {
        Face active = faces.first;
        final bool inOval = _faceInOval(active, image);
        sendPort.send(ProcessResponse(
            id: process.id,
            face: faces.first,
            image: image,
            detection: FaceDetection(inOval)));
      } else {
        sendPort.send(ProcessResponse(id: process.id, image: image));
      }
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
    }
  });
}

class ProcessModel {
  const ProcessModel({
    required this.id,
    required this.image,
    required this.camera,
    required this.orientation,
  });

  final int id;
  final CameraImage image;
  final DeviceOrientation orientation;
  final CameraDescription camera;
}

class ProcessResponse {
  const ProcessResponse(
      {this.id, this.detection, this.exception, this.face, this.image});

  final int? id;
  final CameraImage? image;
  final Face? face;
  final Exception? exception;
  final FaceDetection? detection;

  Size? get imageSize => image != null
      ? Size(image!.width.toDouble(), image!.height.toDouble())
      : null;

  Rect? get faceBoundaryBox => face?.boundingBox;
  bool get inOval => detection?.inOval == true;
}

final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

class FaceDetection {
  final bool inOval;
  const FaceDetection(this.inOval);
}
