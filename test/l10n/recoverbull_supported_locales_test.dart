import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RecoverBull and app localizations support the same locales', () {
    expect(
      RecoverBullLocalizations.supportedLocales.toSet(),
      AppLocalizations.supportedLocales.toSet(),
    );
  });
}
