import 'package:flutter/material.dart';

class TriageDeskLogo extends StatelessWidget {
  final double size;

  const TriageDeskLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'TriageDesk logo',
      image: true,
      child: Image.asset(
        'assets/images/triagedesk_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
