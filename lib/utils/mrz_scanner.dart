import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MrzModel {
  final String? inn;
  final String? number;
  const MrzModel({this.inn, this.number});
}

class MrzScanner {
  MrzScanner();

  late final TextRecognizer _detector;

  bool _initialized = false;

  void initial() {
    _detector = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    _initialized = true;
  }

  Future<MrzModel> detect(String path) async {
    if (_initialized) {
      RecognizedText text =
          await _detector.processImage(InputImage.fromFile(File(path)));

      if (text.text.isEmpty) {
        throw Exception('Text not found');
      } else {
        String? inn;
        String? number;
        text.blocks.forEach((e) {
          String text = e.text.replaceAll(' ', '');
          if (text.startsWith('IDKGZ')) {
            List<String> list = text.split('\n');
            if (list.isNotEmpty) {
              String text = list.first.replaceAll(RegExp('IDKGZ|<'), '');
              number = text.substring(0, 9);
              inn = text.substring(10);
            }
          }
        });
        return MrzModel(inn: inn, number: number);
      }
    }
    throw Exception('Not initialized');
  }

  void dispose() async {
    if (_initialized) {
      _initialized = false;
      await _detector.close();
    }
  }
}
