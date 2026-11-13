import 'package:flutter/widgets.dart';

/// Bitcoin presentation unit, independent of application storage.
enum BullAmountUnit { sats, btc }

/// Application-provided defaults and localized feedback for amount controls.
@immutable
class BullAmountPreferences {
  const BullAmountPreferences({
    required this.defaultUnit,
    required this.changeDefaultUnit,
    required this.globalActionLabel,
    required this.tooltip,
    required this.satsEverywhereMessage,
    required this.btcEverywhereMessage,
    required this.undoLabel,
    required this.failureMessage,
  });

  final BullAmountUnit defaultUnit;
  final Future<bool> Function(BullAmountUnit) changeDefaultUnit;
  final String globalActionLabel;
  final String tooltip;
  final String satsEverywhereMessage;
  final String btcEverywhereMessage;
  final String undoLabel;
  final String failureMessage;
}

/// Supplies amount preferences without coupling bull_ui to application state.
class BullAmountPreferencesScope extends StatefulWidget {
  const BullAmountPreferencesScope({
    super.key,
    required this.preferences,
    required this.child,
  });

  final BullAmountPreferences preferences;
  final Widget child;

  static BullAmountPreferences? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AmountPreferencesData>()
      ?.preferences;

  static int? revisionOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AmountPreferencesData>()
      ?.revision;

  static VoidCallback? resetterOf(BuildContext context) => context
      .findAncestorStateOfType<_BullAmountPreferencesScopeState>()
      ?.resetOverrides;

  @override
  State<BullAmountPreferencesScope> createState() =>
      _BullAmountPreferencesScopeState();
}

class _BullAmountPreferencesScopeState
    extends State<BullAmountPreferencesScope> {
  int _revision = 0;

  void resetOverrides() {
    if (mounted) setState(() => _revision++);
  }

  @override
  void didUpdateWidget(BullAmountPreferencesScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.defaultUnit != widget.preferences.defaultUnit) {
      _revision++;
    }
  }

  @override
  Widget build(BuildContext context) => _AmountPreferencesData(
    preferences: widget.preferences,
    revision: _revision,
    child: widget.child,
  );
}

class _AmountPreferencesData extends InheritedWidget {
  const _AmountPreferencesData({
    required this.preferences,
    required this.revision,
    required super.child,
  });

  final BullAmountPreferences preferences;
  final int revision;

  @override
  bool updateShouldNotify(_AmountPreferencesData oldWidget) =>
      preferences != oldWidget.preferences || revision != oldWidget.revision;
}
