import 'package:go_router/go_router.dart';
import 'package:wallet_import/src/ui/coldcard_instructions.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;
import 'package:signers/signers.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

enum QrImportDevice {
  jade('importJade', '/import-jade', SignerDevice.jade),
  krux('importKrux', '/import-krux', SignerDevice.krux),
  keystone('importKeystone', '/import-keystone', SignerDevice.keystone),
  passport('importPassport', '/import-passport', SignerDevice.passport),
  seedsigner('importSeedSigner', '/import-seedsigner', SignerDevice.seedsigner),
  specter('importSpecter', '/import-specter', SignerDevice.specter);

  final String routeName;
  final String path;
  final SignerDevice signer;

  const QrImportDevice(this.routeName, this.path, this.signer);
}

typedef WatchOnlyImportRequest = ({WatchOnlyInput input, String label});

abstract final class ImportNavigation {
  // The scanner and confirmation routes are mounted in the app on storage-05.
  static const watchOnlyScannerName = 'scan';
  static const watchOnlyScannerPath = '/import-watch-only-scanner';
  static const watchOnlyConfirmationName = 'import';
  static const watchOnlyConfirmationPath = '/import-watch-only';

  static Future<void> showColdcardInstructions(
    BuildContext context,
    SignerDevice device,
  ) => switch (device) {
    SignerDevice.coldcardQ => ColdcardQInstructionsBottomSheet.show(context),
    SignerDevice.coldcardMk4 => ColdcardMk4InstructionsBottomSheet.show(
      context,
    ),
    _ => throw ArgumentError.value(device, 'device', 'Unsupported Coldcard'),
  };

  static Future<void> openQrInstructions(
    BuildContext context,
    QrImportDevice device,
  ) => context.pushNamed<void>(device.routeName);

  static Future<void> openWatchOnlyScanner(
    BuildContext context, {
    SignerDevice? device,
  }) => context.pushNamed<void>(watchOnlyScannerName, extra: device);

  static void replaceWithWatchOnlyScanner(BuildContext context) {
    context.replaceNamed(watchOnlyScannerName);
  }

  static Future<void> openWatchOnly(
    BuildContext context, {
    WatchOnlyInput? input,
    String label = '',
  }) => context.pushNamed<void>(
    watchOnlyConfirmationName,
    extra: input == null ? null : (input: input, label: label),
  );

  static void replaceWithWatchOnly(BuildContext context, WatchOnlyInput input) {
    context.replaceNamed(
      watchOnlyConfirmationName,
      extra: (input: input, label: ''),
    );
  }
}
