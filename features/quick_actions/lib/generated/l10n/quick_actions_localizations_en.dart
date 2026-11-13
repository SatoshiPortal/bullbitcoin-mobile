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
  String get map => 'Maps';

  @override
  String get settings => 'Settings';

  @override
  String get more => 'More';

  @override
  String get customize => 'Customize';

  @override
  String get title => 'Quick actions';

  @override
  String get save => 'Save';

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
  String get priceHistory => 'Price history';

  @override
  String get quickActionTrade => 'Trade';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }
}
