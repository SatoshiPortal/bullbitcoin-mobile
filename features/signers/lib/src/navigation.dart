import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart' show NetworkEnv, ScriptType;

import 'signer_device.dart';
import 'ledger_flow/domain/signer_account.dart';
import 'ledger_flow/ui/screens/ledger_action_screen.dart';
import 'bitbox_flow/ui/screens/bitbox_action_screen.dart';
import 'psbt_flow/show_psbt/show_psbt_screen.dart';
import 'ledger_routes.dart';
import 'bitbox_routes.dart';
import 'psbt_routes.dart';

/// Typed caller API; the shell mounts the routes and supplies platform UI.
abstract final class SignersNavigation {
  static Future<SignerAccount?> importLedger(
    BuildContext context, {
    required NetworkEnv network,
    SignerDevice? requestedDeviceType,
  }) => context.pushNamed<SignerAccount>(
    LedgerRoute.importLedger.name,
    extra: LedgerRouteParams(
      network: network,
      requestedDeviceType: requestedDeviceType,
    ),
  );
  static Future<String?> signLedger(
    BuildContext context, {
    required NetworkEnv network,
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    SignerDevice? requestedDeviceType,
  }) => context.pushNamed<String>(
    LedgerRoute.ledgerSignTransaction.name,
    extra: LedgerRouteParams(
      network: network,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      requestedDeviceType: requestedDeviceType,
    ),
  );
  static Future<void> verifyLedger(
    BuildContext context, {
    required NetworkEnv network,
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    SignerDevice? requestedDeviceType,
  }) => context.pushNamed<void>(
    LedgerRoute.ledgerVerifyAddress.name,
    extra: LedgerRouteParams(
      network: network,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
      requestedDeviceType: requestedDeviceType,
    ),
  );
  static Future<SignerAccount?> importBitBox(
    BuildContext context, {
    required NetworkEnv network,
    SignerDevice? requestedDeviceType,
  }) => context.pushNamed<SignerAccount>(
    BitBoxRoute.importBitBox.name,
    extra: BitBoxRouteParams(
      network: network,
      requestedDeviceType: requestedDeviceType,
    ),
  );
  static Future<String?> signBitBox(
    BuildContext context, {
    required NetworkEnv network,
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    SignerDevice? requestedDeviceType,
  }) => context.pushNamed<String>(
    BitBoxRoute.bitboxSignTransaction.name,
    extra: BitBoxRouteParams(
      network: network,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
      requestedDeviceType: requestedDeviceType,
    ),
  );
  static Future<void> verifyBitBox(
    BuildContext context, {
    required NetworkEnv network,
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    SignerDevice? requestedDeviceType,
  }) => context.pushNamed<void>(
    BitBoxRoute.bitboxVerifyAddress.name,
    extra: BitBoxRouteParams(
      network: network,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
      requestedDeviceType: requestedDeviceType,
    ),
  );
  static Future<PsbtHandoffResult?> showPsbt(
    BuildContext context, {
    required String psbt,
    SignerDevice? signerDevice,
  }) => context.pushNamed<PsbtHandoffResult>(
    PsbtFlowRoutes.show.name,
    extra: (psbt: psbt, signerDevice: signerDevice),
  );
}
