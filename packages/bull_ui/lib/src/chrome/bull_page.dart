import 'package:bull_ui/src/chrome/bull_scaffold.dart';
import 'package:bull_ui/src/chrome/bull_top_bar.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// A standard page shell with one safe-area boundary and token-based content
/// padding.
///
/// [topBar] is placed inside the safe area, so callers should not wrap it in a
/// second [SafeArea]. A [BullTopBar] is the recommended default, but any
/// caller-owned chrome can be supplied for dynamic states such as selection.
/// Set [safeArea] to false when the parent already owns the system-inset
/// boundary. [child] is either laid out as-is or made scrollable when
/// [scrollable] is true. The optional [bottomBar] stays pinned by the
/// scaffold and is expected to handle its own bottom safe area.
class BullPage extends StatelessWidget {
  const BullPage({
    super.key,
    required this.child,
    this.topBar,
    this.bottomBar,
    this.scrollable = false,
    this.padding,
    this.safeArea = true,
    this.resizeToAvoidBottomInset,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });

  final Widget child;
  final Widget? topBar;
  final Widget? bottomBar;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;
  final bool? resizeToAvoidBottomInset;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    final contentPadding =
        padding ??
        const EdgeInsets.symmetric(
          vertical: BullSpacing.md,
          horizontal: BullSpacing.md,
        );
    final content = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: keyboardDismissBehavior,
            padding: contentPadding,
            child: child,
          )
        : Padding(padding: contentPadding, child: child);
    final body = Column(
      children: [
        ?topBar,
        Expanded(child: content),
      ],
    );

    return BullScaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomBar,
      body: safeArea ? SafeArea(child: body) : body,
    );
  }
}
