import 'package:flutter/widgets.dart';

/// Opens the app's support channel from [context].
///
/// [message] is an optional draft the support channel pre-fills; `null` means
/// "no draft", and the app decides what that looks like.
typedef BullContactSupport =
    void Function(BuildContext context, {String? message});

/// Injects the app's "contact support" action into the widget tree.
///
/// `bull_ui` does not know what support means: the app decides (a chat route,
/// a web page, a messaging app) and registers it once, above every screen that
/// offers support. [BullSupportButton] reads the nearest scope and calls
/// [onContactSupport] with its own [BuildContext], so the action can navigate
/// from where the button sits.
class BullSupportScope extends InheritedWidget {
  const BullSupportScope({
    super.key,
    required this.onContactSupport,
    required super.child,
  });

  /// The app's support action.
  final BullContactSupport onContactSupport;

  /// The nearest [BullSupportScope] above [context], or `null` when the app
  /// registered none.
  static BullSupportScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BullSupportScope>();
  }

  @override
  bool updateShouldNotify(BullSupportScope oldWidget) {
    return onContactSupport != oldWidget.onContactSupport;
  }
}
