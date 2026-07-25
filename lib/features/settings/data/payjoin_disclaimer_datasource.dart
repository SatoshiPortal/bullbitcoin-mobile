import 'package:shared_preferences/shared_preferences.dart';

/// Typed accessor over the payjoin disclaimer's slice of [SharedPreferences]
/// (same pattern as WizardLocalDatasource): the only file that knows the
/// pref key name. Tracks whether the one-time payjoin disclaimer pop-up has
/// already been shown, so enabling payjoin only interrupts the user once.
abstract class PayjoinDisclaimerDatasource {
  Future<bool> readDisclaimerShown();
  Future<void> writeDisclaimerShown();
}

class PayjoinDisclaimerDatasourceImpl implements PayjoinDisclaimerDatasource {
  static const _shownKey = 'payjoin_disclaimer_shown';

  @override
  Future<bool> readDisclaimerShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shownKey) ?? false;
  }

  @override
  Future<void> writeDisclaimerShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey, true);
  }
}
