// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'quick_actions_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class QuickActionsLocalizationsEn extends QuickActionsLocalizations {
  QuickActionsLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get buy => 'Buy';

  @override
  String get sell => 'Sell';

  @override
  String get pay => 'Pay';

  @override
  String get transfer => 'Transfer';

  @override
  String get map => 'Map';

  @override
  String get settings => 'Settings';

  @override
  String get more => 'More';

  @override
  String get customize => 'Customize';

  @override
  String get title => 'Quick actions';

  @override
  String get save => 'Save changes';

  @override
  String get reset => 'Restore defaults';

  @override
  String get unavailable => 'Currently unavailable';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get saveFailed => 'Could not save changes. Please try again.';

  @override
  String get loading => 'Loading';

  @override
  String get history => 'History';

  @override
  String get support => 'Support';

  @override
  String get priceHistory => 'Price';

  @override
  String get quickActionTrade => 'Trade';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String get onHome => 'On Home';

  @override
  String get inMore => 'In More';

  @override
  String get preview => 'Preview';

  @override
  String get maximumHint =>
      'Up to 4 cells on Home. When More is needed, your first 3 available favorites appear beside it.';

  @override
  String get overflowHint => 'These favorites appear in More';

  @override
  String addAction(String name) {
    return 'Add $name to favorites';
  }

  @override
  String removeAction(String name) {
    return 'Remove $name from favorites';
  }

  @override
  String reorderAction(String name) {
    return 'Reorder $name';
  }

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get priceHistoryFull => 'Price history';

  @override
  String get saving => 'Saving…';

  @override
  String get emptyHint => 'No favorites selected. Settings remains on Home.';

  @override
  String get transferFull => 'Transfer between wallets';

  @override
  String get supportFull => 'Support';
}
