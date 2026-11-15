import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_failure_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _translate(
  WidgetTester tester,
  ImportWatchOnlyFailure failure,
) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          message = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  testWidgets('existing wallet maps to its localized message', (tester) async {
    final alreadyExists = await _translate(
      tester,
      const WalletAlreadyExistsFailure(),
    );
    final generic = await _translate(tester, const ImportFailedFailure());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(alreadyExists, l10n.importWatchOnlyErrorAlreadyExists);
    expect(alreadyExists, isNot(generic));
  });

  testWidgets('network mismatch maps to its localized message', (tester) async {
    final mismatch = await _translate(tester, const NetworkMismatchFailure());
    final generic = await _translate(tester, const ImportFailedFailure());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(mismatch, l10n.importWatchOnlyErrorNetworkMismatch);
    expect(mismatch, isNot(generic));
  });
}
