import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/viewport_service.dart';

class ViewportWrapper extends StatelessWidget {
  final Widget child;
  const ViewportWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Toggle phone/desktop view on pressing F9 key
          if (event.logicalKey == LogicalKeyboardKey.f9) {
            ViewportService.instance.toggle();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: ViewportService.instance.isPhoneView,
        builder: (context, isPhone, _) {
          if (!isPhone) return child;

          return Scaffold(
            backgroundColor: const Color(0xFF1A1A1A),
            body: Center(
              child: Container(
                width: 410,
                height: 844,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(42),
                  border: Border.all(color: const Color(0xFF2C2C2C), width: 12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
