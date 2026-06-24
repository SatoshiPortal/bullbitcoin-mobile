import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A thin themed [Scaffold] whose background comes from the injected
/// [BullTheme]. No generic scaffold exists in `lib/core/widgets`, so this is a
/// new (thin) primitive.
class BullScaffold extends StatelessWidget {
  const BullScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  /// Optional top bar (typically a [PreferredSizeWidget] or a sized box).
  final PreferredSizeWidget? appBar;

  /// The main content.
  final Widget body;

  /// Optional sticky bottom bar (e.g. a selection action bar).
  final Widget? bottomNavigationBar;

  /// Forwarded to [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bull.surface,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
