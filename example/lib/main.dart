import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_mlkit/ui/doc_photo_view.dart';
import 'package:flutter_face_mlkit/ui/photo_scanner_view.dart';
import 'package:flutter_face_mlkit/ui/photo_view.dart';
import 'package:flutter_face_mlkit/ui/video_view.dart';
import 'package:flutter_face_mlkit/utils/camera_type.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void pushToDoc(BuildContext context, bool nested) {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          body: DocPhotoView(
            aspectRatio: 1.586,
            cameraType: CameraType.back,
            bottom: Text('Сфотографируйте лицевую сторону паспорта'),
            onCroppedImage: (image) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) {
                  return Scaffold(
                    body: PhotoScannerView(
                      aspectRatio: 1.586,
                      onRetry: () {
                        pushToDoc(context, true);
                      },
                      path: image.path,
                    ),
                  );
                },
              ));
            },
            onCapture: (image) {},
          ),
        );
      },
    );
    if (nested) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void pushToSelfie(BuildContext context, bool nested) {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          body: PhotoView(
            cameraType: CameraType.front,
            onCapture: (image) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) {
                  return Scaffold(
                    body: PhotoScannerView(
                      onRetry: () {
                        pushToSelfie(context, true);
                      },
                      path: image.path,
                    ),
                  );
                },
              ));
            },
          ),
        );
      },
    );
    if (nested) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void pushToVideo(BuildContext context, bool nested) {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          body: VideoView(
            cameraType: CameraType.front,
            timer: 5,
            onComplete: (video) {},
          ),
        );
      },
    );
    if (nested) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 40,
        children: [
          Center(
              child: FilledButton(
            onPressed: () {
              pushToDoc(context, false);
            },
            child: Text('Push to doc camera'),
          )),
          Center(
              child: FilledButton(
            onPressed: () {
              pushToSelfie(context, false);
            },
            child: Text('Push to selfie camera'),
          )),
          Center(
              child: FilledButton(
            onPressed: () {
              pushToVideo(context, false);
            },
            child: Text('Push to selfie camera'),
          )),
        ],
      ),
    );
  }
}
