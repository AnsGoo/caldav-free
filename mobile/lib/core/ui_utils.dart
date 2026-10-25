import 'package:flutter/widgets.dart';

/// Disposes a dialog controller after the route's reverse transition. Disposing
/// immediately after `showDialog` returns can trip Flutter's `_dependents`
/// assertion while the closing dialog still references the controller.
void disposeControllerSoon(TextEditingController controller) {
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
}
