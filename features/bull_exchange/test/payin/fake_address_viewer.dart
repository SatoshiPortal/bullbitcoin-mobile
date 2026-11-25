import 'package:flutter/widgets.dart';

/// Stands in for the app's AddressViewer with the same layout limit: it
/// measures itself with a [LayoutBuilder], so a page that hosts it inside an
/// intrinsic-height layout fails in tests as it does in the app.
Widget fakeAddressViewer(
  BuildContext context,
  String text, {
  TextStyle? style,
  Color? color,
  TextAlign? textAlign,
}) => LayoutBuilder(builder: (context, _) => Text(text, style: style));
