import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/utils/mrz_scanner.dart';

class PhotoScannerView extends StatefulWidget {
  final String path;
  final VoidCallback? onRetry;
  final Function(String path, {MrzModel? mrz})? onSuccess;
  final double aspectRatio;
  final bool detectMrz;
  const PhotoScannerView({
    super.key,
    this.onSuccess,
    required this.path,
    this.onRetry,
    this.aspectRatio = 0.7,
    this.detectMrz = false,
  });

  @override
  State<PhotoScannerView> createState() => _PhotoScannerViewState();
}

class _PhotoScannerViewState extends State<PhotoScannerView> {
  final MrzScanner _scanner = MrzScanner();

  @override
  void initState() {
    super.initState();
    if (widget.detectMrz) {
      _scanner.initial();
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF1F2328),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Spacer(),
            Container(
              margin: EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: Image.file(
                    File(widget.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RetryButton(
                  onTap: widget.onRetry,
                ),
                _SuccessButton(
                  onTap: widget.onSuccess != null
                      ? () async {
                          try {
                            MrzModel mrz = await _scanner.detect(widget.path);
                            widget.onSuccess!(widget.path, mrz: mrz);
                            return;
                          } catch (e) {}
                          widget.onSuccess!(widget.path);
                        }
                      : null,
                ),
              ],
            ),
            SizedBox(height: 16)
          ],
        ),
      ),
    );
  }
}

class _SuccessButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _SuccessButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: 64,
      child: Material(
        color: Color(0xFF347DEA),
        borderRadius: BorderRadius.circular(64),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(64),
          child: Icon(
            Icons.check_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _RetryButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: 64,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(64),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(64),
          child: Transform.flip(
            flipX: true,
            child: Icon(
              Icons.refresh_rounded,
              size: 36,
              color: Color(0xFF323232),
            ),
          ),
        ),
      ),
    );
  }
}
