import 'package:flutter/material.dart';

class CaptureButton extends StatelessWidget {
  final VoidCallback? onTap;
  const CaptureButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        padding: EdgeInsets.all(1),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Color(0xFF1F2328),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
