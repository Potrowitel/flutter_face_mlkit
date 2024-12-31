import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_mlkit/ui/photo_scanner_view.dart';
import 'package:flutter_face_mlkit/ui/photo_view.dart';

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

  void push(BuildContext context, bool nested) {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          body: PhotoView(
            onCapture: (image) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (context) {
                  return Scaffold(
                    body: PhotoScannerView(
                      onRetry: () {
                        push(context, true);
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

  @override
  Widget build(BuildContext context) {
    double sin = 1;
    double cos = 0;

    final Matrix4 result = Matrix4.zero();
    result.storage[0] = cos;
    result.storage[1] = sin;
    result.storage[4] = -sin;
    result.storage[5] = cos;
    result.storage[10] = 1.0;
    result.storage[15] = 1.0;

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
              child: FilledButton(
            onPressed: () {
              push(context, false);
            },
            child: Text('Push to camera'),
          )),
          SizedBox(height: 100),
          Transform.rotate(
            angle: math.pi / 2,
            // transform: result,
            child: Container(
              height: 100,
              width: 200,
              decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [Colors.red, Colors.orange])),
            ),
          ),
          SizedBox(height: 100),
          Container(
            height: 100,
            width: 200,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red, Colors.orange])),
          ),
        ],
      ),
    );
  }
}
