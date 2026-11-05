import 'package:flutter/widgets.dart';

/// Disposes a dialog controller after the route's reverse transition. Disposing
/// immediately after `showDialog` returns can trip Flutter's `_dependents`
/// assertion while the closing dialog still references the controller.
void disposeControllerSoon(TextEditingController controller) {
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
}

/// Whether the viewport is in landscape or wide enough to treat as a tablet
/// layout. Mirrors [isWideLayout] from components.dart without importing it,
/// so files that already import both don't get a symbol clash.
bool _isWide(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height || size.shortestSide >= 600;
}

/// Compact AppBar height for landscape / wide layouts where vertical space is
/// scarce. Falls back to the caller's [defaultHeight] on portrait phones.
double compactAppBarHeight(BuildContext context, {double defaultHeight = 82}) {
  return _isWide(context) ? 52 : defaultHeight;
}

/// Title font size that shrinks in landscape so the AppBar doesn't dominate
/// the visible area.
double compactTitleFontSize(BuildContext context, {double defaultSize = 30}) {
  return _isWide(context) ? 20 : defaultSize;
}

/// Whether the AppBar title should drop its two-line layout.
bool isCompactAppBar(BuildContext context) => _isWide(context);

/// AppBar title paired with a secondary line (counts, view label, stats).
///
/// Portrait keeps the original stacked look. In landscape the two lines are
/// merged into a single row, since the extra line costs vertical space that
/// the page content needs more.
Widget compactAppBarTitle(
  BuildContext context, {
  required Widget title,
  required Widget subtitle,
  double gap = 10,
}) {
  if (!isCompactAppBar(context)) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [title, const SizedBox(height: 5), subtitle],
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      // The title never shrinks: it is short and must stay on one line.
      title,
      SizedBox(width: gap),
      // The subtitle absorbs whatever space is left and ellipsises instead of
      // pushing the title around.
      Expanded(child: subtitle),
    ],
  );
}
