import 'package:flutter/foundation.dart';

class ViewportService {
  static final ViewportService instance = ViewportService._();
  ViewportService._();

  final ValueNotifier<bool> isPhoneView = ValueNotifier<bool>(false);

  void toggle() {
    isPhoneView.value = !isPhoneView.value;
  }
}
