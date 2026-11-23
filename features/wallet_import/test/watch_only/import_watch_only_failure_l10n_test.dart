import 'package:wallet_import/src/presentation/watch_only/import_watch_only_failure_l10n.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/wallet_import.dart' show ImportLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _translate(
  WidgetTester tester,
  ImportWatchOnlyFailure failure,
) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: ImportLocalizations.localizationsDelegates,
      supportedLocales: ImportLocalizations.supportedLocales,
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
    final l10n = await ImportLocalizations.delegate.load(const Locale('en'));

    expect(alreadyExists, l10n.importWatchOnlyErrorAlreadyExists);
    expect(alreadyExists, isNot(generic));
  });

  testWidgets('network mismatch maps to its localized message', (tester) async {
    final mismatch = await _translate(tester, const NetworkMismatchFailure());
    final generic = await _translate(tester, const ImportFailedFailure());
    final l10n = await ImportLocalizations.delegate.load(const Locale('en'));

    expect(mismatch, l10n.importWatchOnlyErrorNetworkMismatch);
    expect(mismatch, isNot(generic));
  });
}
