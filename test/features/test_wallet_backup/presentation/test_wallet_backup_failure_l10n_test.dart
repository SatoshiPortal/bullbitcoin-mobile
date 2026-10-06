import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/test_wallet_backup_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A raw reason shaped like the worst thing this flow could leak: the seed
/// path is one layer below every failure here, so the fixture embeds mnemonic
/// words and a passphrase. Every variant carries it in `logMessage` so the
/// assertions prove none of it survives into the translated string.
const _secretWords = ['legal', 'winner', 'thank', 'year'];
const _passphrase = 'correct-horse-battery-staple';
const _rawReason =
    'KeychainException: read failed for seed '
    'legal winner thank year (passphrase correct-horse-battery-staple)';

/// One instance of every [TestWalletBackupFailure].
///
/// The `sealed` switch in `toTranslated` already gives compile-time coverage:
/// add a variant and the switch stops compiling. What the compiler cannot
/// check is that each arm resolves to a real, non-empty `.arb` value and that
/// no arm echoes the raw reason.
final _everyFailure = <TestWalletBackupFailure>[
  const TestWalletBackupWalletsUnavailableFailure(_rawReason),
  const TestWalletBackupNoWalletsFailure(_rawReason),
  const TestWalletBackupNoWalletSelectedFailure(_rawReason),
  const TestWalletBackupSeedUnavailableFailure(_rawReason),
  const TestWalletBackupSeedNotMnemonicFailure(_rawReason),
  const TestWalletBackupCompletionFailure(_rawReason),
  const TestWalletBackupUnexpectedFailure(_rawReason),
];

Future<String> _translate(
  WidgetTester tester,
  TestWalletBackupFailure failure,
) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  group('TestWalletBackupFailureL10n.toTranslated', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} resolves to a user-safe message', (
        tester,
      ) async {
        final message = await _translate(tester, failure);

        expect(
          message,
          isNotEmpty,
          reason: 'the .arb key for ${failure.runtimeType} resolved to nothing',
        );
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('Exception')));
        // The reason quotes seed material. None of it may reach the screen.
        expect(message, isNot(contains(_passphrase)));
        for (final word in _secretWords) {
          expect(message, isNot(contains(word)));
        }
      });
    }

    testWidgets('the catch-all reads identically with and without a reason', (
      tester,
    ) async {
      final withReason = await _translate(
        tester,
        const TestWalletBackupUnexpectedFailure(_rawReason),
      );
      final without = await _translate(
        tester,
        const TestWalletBackupUnexpectedFailure(),
      );

      expect(withReason, without);
    });

    testWidgets('an empty wallet list reads differently from a failed read', (
      tester,
    ) async {
      final none = await _translate(
        tester,
        const TestWalletBackupNoWalletsFailure(),
      );
      final failed = await _translate(
        tester,
        const TestWalletBackupWalletsUnavailableFailure(),
      );

      // "You have no wallet" and "we could not load your wallets" call for
      // different actions, so they must not collapse into one message.
      expect(none, isNot(failed));
    });
  });
}
