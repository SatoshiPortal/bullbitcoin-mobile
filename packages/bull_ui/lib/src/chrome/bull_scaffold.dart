import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A thin themed [Scaffold] whose background comes from the injected
/// [BullTheme].
class BullScaffold extends StatelessWidget {
  const BullScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.backgroundColor,
  });

  /// Optional top bar (typically a [PreferredSizeWidget] or a sized box).
  final PreferredSizeWidget? appBar;

  /// The main content.
  final Widget body;

  /// Optional sticky bottom bar (e.g. a selection action bar).
  final Widget? bottomNavigationBar;

  /// Forwarded to [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  /// An optional theme role for pages with a background behind surface cards.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? context.bull.surface,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
