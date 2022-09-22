import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/camera_view.dart';
import 'package:flutter_face_mlkit/flutter_face_mlkit.dart';
import 'package:flutter_face_mlkit/liveness_component.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _photoPath;
  String? _photoAction;
  var _scaffoldState = GlobalKey<ScaffoldState>();

  var _livenessSelectStatus;

  var _livenessStatus = [
    FaceLivenessType.FACE_ANGLE_LEFT,
    FaceLivenessType.FACE_ANGLE_RIGHT,
    // FaceLivenessType.FACE_ANGLE_TOP,
    // FaceLivenessType.FACE_ANGLE_BOTTOM
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldState,
      appBar: AppBar(
        title: Text('Flutter ML Kit FaceDetector'),
      ),
      body: ListView(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                    child: Text('Start Camera'),
                    onPressed: () async {
                      setState(() {
                        _photoPath = null;
                      });
                      var result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CameraScreen()));
                      if (result != null && result is String) {
                        setState(() {
                          _photoPath = result;
                        });
                      }
                    }),
                ElevatedButton(
                    child: Text('Start face Camera'),
                    onPressed: () async {
                      setState(() {
                        _photoPath = null;
                      });
                      var result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CameraFaceScreen()));
                      if (result != null && result is String) {
                        setState(() {
                          _photoPath = result;
                        });
                      }
                    }),
                ElevatedButton(
                    child: Text('Start liveness Camera'),
                    onPressed: () async {
                      final random = Random();

                      var index = random.nextInt(_livenessStatus.length);
                      _livenessSelectStatus = _livenessStatus[index];

                      setState(() {
                        _photoPath = null;
                      });
                      var result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CameraLivenessFaceScreen(
                                    livenessType: _livenessSelectStatus,
                                  )));
                      if (result == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Лицо не определено'),
                        ));
                        // _scaffoldState.currentState(SnackBar(
                        //   content: Text('Лицо не определено'),
                        // ));
                        return;
                      }
                      if (result != null && result is List<String?>) {
                        setState(() {
                          _photoPath = result[0];
                          _photoAction = result[1];
                        });
                      }
                    }),
                _photoPath != null
                    ? Image.file(File(_photoPath!))
                    : SizedBox(
                        height: 0,
                        width: 0,
                      ),
                _photoAction != null
                    ? Image.file(File(_photoAction!))
                    : SizedBox(
                        width: 0,
                        height: 0,
                      )
              ],
            ),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('MakeCapture'),
        ),
        body: CameraView(
          cameraLensType: CameraLensType.CAMERA_FRONT,
          onError: print,
          onCapture: (path, _) {
            print(path);
            Navigator.pop(context, path);
          },
          overlayBuilder: (context) {
            return Center(
                child: Container(color: Colors.green, width: 50, height: 50));
          },
          captureButtonBuilder: (context, onCapture, _) {
            return Container(
                color: Colors.red,
                child: Center(
                    child: ElevatedButton(
                  onPressed: () => onCapture(),
                  child: Text('BTN'),
                )));
          },
        ));
  }
}

class CameraFaceScreen extends StatefulWidget {
  @override
  _CameraFaceScreenState createState() => _CameraFaceScreenState();
}

class _CameraFaceScreenState extends State<CameraFaceScreen> {
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var ovalRect = Rect.fromLTWH(((size.width / 2) - (250 / 2)), 50, 250, 350);

    return Scaffold(
      appBar: AppBar(
        title: Text('MakeCapture'),
      ),
      body: SelfieAutocapture(
        ovalRect: ovalRect,
        infoBlockBuilder: (BuildContext context) => Center(
            child: Text(
          'Поместите лицо в овал',
          style: TextStyle(fontSize: 18, color: Colors.white),
        )),
        onCapturePhoto: (path) {
          print(path);
          Navigator.pop(context, path);
        },
      ),
    );
  }
}

class CameraLivenessFaceScreen extends StatefulWidget {
  final FaceLivenessType? livenessType;

  CameraLivenessFaceScreen({required this.livenessType});

  @override
  _CameraLivenessFaceScreen createState() => _CameraLivenessFaceScreen();
}

class _CameraLivenessFaceScreen extends State<CameraLivenessFaceScreen> {
  FaceStepType _faceStepType = FaceStepType.FACE_STEP_FACEDETECTION;
  double _livenessPercentage = 0.0;
  String? _actionPath;

  Map<FaceLivenessType, String> _livenessTexts = {
    FaceLivenessType.FACE_ANGLE_LEFT: 'Поверните голову влево.',
    FaceLivenessType.FACE_ANGLE_RIGHT: 'Поверните голову вправо.',
    FaceLivenessType.FACE_ANGLE_TOP: 'Посмотрите вверх',
    FaceLivenessType.FACE_ANGLE_BOTTOM: 'Посмотрите вниз',
    FaceLivenessType.FACE_SMILE: 'Улыбнитесь',
  };

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var ovalRect = Rect.fromLTWH(((size.width / 2) - (250 / 2)), 50, 250, 350);

    return Scaffold(
      appBar: AppBar(
        title: Text('MakeCapture'),
      ),
      body: LivenessComponent(
        ovalRect: ovalRect,
        livenessType: widget.livenessType!,
        onStepChanged: (FaceStepType faceType) {
          setState(() {
            _faceStepType = faceType;
          });
          print('FACE TYPE CHANGED = ${faceType.toString()}');
        },
        onLivenessPercentChange: (percentage) {
          setState(() => _livenessPercentage = percentage / 100);
          print('LIVENESS PERCENTAGE = $percentage');
        },
        infoBlockBuilder: (BuildContext context, _) {
          switch (_faceStepType) {
            case FaceStepType.FACE_STEP_CAPTURING:
              {
                return Center(
                  child: Text(
                    'ШАГ 3: Поместите лицо в овал. Для проверки.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                );
              }
            case FaceStepType.FACE_STEP_LIVENESS:
              {
                return Center(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    LinearProgressIndicator(
                      value: _livenessPercentage,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    Text(
                      'ШАГ 2: ${_livenessTexts[widget.livenessType!]}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ));
              }
            case FaceStepType.FACE_STEP_FACEDETECTION:
            default:
              {
                return Center(
                    child: Text(
                  'ШАГ 1: Посмотрите на камеру.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ));
              }
          }
        },
        onCapturePhoto: (path, _) {
          Navigator.pop(context, [path, _actionPath]);
        },
        onActionPhoto: (path, _) {
          // Navigator.pop(context, path);
          _actionPath = path;
        },
      ),
    );
  }
}
