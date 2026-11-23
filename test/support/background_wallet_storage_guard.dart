import 'package:flutter_test/flutter_test.dart';

void expectOnlyBackgroundWalletStorage({
  required String bootstrap,
  required String walletSetup,
}) {
  for (final (source, allowedImport) in [
    (bootstrap, "import 'package:secrets/migration.dart' show SecretsImport;"),
    (
      walletSetup,
      "import 'package:secrets/storage.dart' show BackgroundWalletDescriptors;",
    ),
  ]) {
    expect(source, contains(allowedImport));
    expect(
      source.replaceFirst(allowedImport, ''),
      isNot(contains('package:secrets')),
    );
    expect(
      source,
      isNot(
        matches(
          RegExp(
            r'\b(?:ExclusiveAdmission|PreparedOwner|prepare|importLegacy|initializeFresh)\b',
          ),
        ),
      ),
    );
  }
  expect(
    bootstrap,
    matches(
      RegExp(r'if \(task == BackgroundTask\.walletsSync\)\s*SecretsImport\('),
    ),
  );
  expect(bootstrap, contains('await cutover.admit()'));
  expect(walletSetup, contains('await BackgroundWalletDescriptors.open('));
}
