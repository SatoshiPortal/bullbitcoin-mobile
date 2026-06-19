import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/data/trezor_connect_datasource.dart';
import 'package:bb_mobile/features/trezor/data/trezor_data_exceptions.dart';
import 'package:bb_mobile/features/trezor/domain/repositories/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_account.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_error.dart';
import 'package:trezor_connect/models.dart';
import 'package:trezor_connect/trezor_connect.dart' show TrezorLaunchException;

class TrezorDeviceRepositoryImpl implements TrezorDeviceRepository {
  final TrezorConnectDatasource _datasource;

  TrezorDeviceRepositoryImpl({required this._datasource});

  @override
  Future<TrezorAccount> getDefaultAccount({
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    // BIP-44/49/84 share `m/<purpose>'/<coinType>'/<account>'`. Bull
    // only consumes account 0 today.
    final purpose = scriptType.purpose;
    final coinType = isTestnet ? 1 : 0;
    final path = "m/$purpose'/$coinType'/0'";

    try {
      final raw = await _datasource.getPublicKeyBundle([
        path,
      ], isTestnet: isTestnet);
      if (raw.isEmpty) {
        // The datasource is plural-shaped; in practice it returns
        // one entry for one path. Guard defensively against a stub
        // that ever returns empty.
        throw Exception('Trezor returned no account for $path');
      }
      return _toAccount(raw.first);
    } on Exception catch (e) {
      throw _mapError(e);
    }
  }

  /// Extracts the master fingerprint from a Trezor-emitted output descriptor.
  /// Returns null if the descriptor is null or malformed.
  ///
  /// Format Trezor emits (BIP-380):
  ///   `wpkh([<8-hex-master-fp>/<purpose>h/<coin>h/<account>h]xpub…/<0;1>/*)#<checksum>`
  String? _extractMasterFingerprint(String? descriptor) {
    if (descriptor == null) return null;
    final match = RegExp(r'\[([0-9a-fA-F]{8})/').firstMatch(descriptor);
    return match?.group(1);
  }

  @override
  Future<bool> verifyAddress({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      return await _datasource.verifyAddress(
        address: address,
        derivationPath: derivationPath,
        scriptType: scriptType,
        isTestnet: isTestnet,
      );
    } on Exception catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<String> signPsbt({
    required String psbtBase64,
    required bool isTestnet,
    required ScriptType scriptType,
  }) async {
    try {
      final signed = await _datasource.signPsbt(
        psbtBase64: psbtBase64,
        isTestnet: isTestnet,
        scriptType: scriptType,
      );
      return signed.serializedTx;
    } on Exception catch (e) {
      throw _mapError(e);
    }
  }

  TrezorAccount _toAccount(TrezorAddressPublicKey raw) {
    // path[2] is the account index (hardened); unharden by subtracting
    // 0x80000000 to get the human-readable index (0, 1, 2, …).
    final hardened = raw.path[2];
    final accountIndex = hardened - 0x80000000;

    final fp = _extractMasterFingerprint(raw.descriptor);
    if (fp == null) {
      throw TrezorMissingDescriptorException(rawDescriptor: raw.descriptor);
    }

    return TrezorAccount(
      accountIndex: accountIndex,
      derivationPath: raw.serializedPath,
      xpub: raw.xpub,
      masterFingerprint: fp,
    );
  }

  TrezorError _mapError(Exception e) {
    if (e is TrezorAddressMismatchException) {
      return TrezorError.addressMismatch(
        expected: e.expected,
        returned: e.returned,
      );
    }
    if (e is TrezorMissingDescriptorException) {
      return const TrezorError.missingDescriptor();
    }
    if (e is TrezorLaunchException) {
      return const TrezorError.suiteNotInstalled();
    }
    final s = e.toString().toLowerCase();
    if (s.contains('user rejected') ||
        s.contains('cancelled') ||
        s.contains('user cancelled')) {
      return const TrezorError.userRejected();
    }
    if (s.contains('not installed') || s.contains('no app can handle')) {
      return const TrezorError.suiteNotInstalled();
    }
    return TrezorError.unknown(e.toString());
  }
}
