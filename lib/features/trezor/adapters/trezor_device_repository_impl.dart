import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_signed_psbt.dart';
import 'package:bb_mobile/features/trezor/frameworks/framework_errors.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';
import 'package:trezor_connect/models.dart';

class TrezorDeviceRepositoryImpl implements TrezorDeviceRepository {
  final TrezorConnectDatasource _datasource;

  TrezorDeviceRepositoryImpl({required TrezorConnectDatasource datasource})
    : _datasource = datasource;

  @override
  Future<List<TrezorAccount>> getAccounts({
    required int startIndex,
    required int count,
    required ScriptType scriptType,
  }) async {
    final indices = List.generate(count, (i) => startIndex + i);
    // BIP-44/49/84 share the same shape `m/<purpose>'/0'/<account>'`.
    // The purpose ID is what Trezor Suite uses to label the account family
    // ("Standard wallet" for 84, "SegWit account" for 49, "Legacy account"
    // for 44) and what determines the SLIP-0132 magic bytes on the returned
    // zpub/ypub/xpub.
    final purpose = scriptType.purpose;
    final paths = indices.map((i) => "m/$purpose'/0'/$i'").toList();

    try {
      final raw = await _datasource.getPublicKeyBundle(paths);
      return raw.map(_toAccount).toList();
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
  }) async {
    try {
      return await _datasource.verifyAddress(
        address: address,
        derivationPath: derivationPath,
        scriptType: scriptType,
      );
    } on Exception catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TrezorSignedPsbt> signPsbt({
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
      return TrezorSignedPsbt(
        serializedTxHex: signed.serializedTx,
        txid: signed.txid,
      );
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
      throw Exception(
        'Could not parse master fingerprint from Trezor descriptor: '
        '${raw.descriptor}',
      );
    }

    return TrezorAccount(
      accountIndex: accountIndex,
      derivationPath: raw.serializedPath,
      xpub: raw.xpub,
      masterFingerprint: fp,
    );
  }

  TrezorApplicationError _mapError(Exception e) {
    if (e is TrezorAddressMismatchException) {
      return TrezorApplicationError.addressMismatch(
        expected: e.expected,
        returned: e.returned,
      );
    }
    final s = e.toString().toLowerCase();
    if (s.contains('user rejected') ||
        s.contains('cancelled') ||
        s.contains('user cancelled')) {
      return const TrezorApplicationError.userRejected();
    }
    if (s.contains('not installed') || s.contains('no app can handle')) {
      return const TrezorApplicationError.suiteNotInstalled();
    }
    return TrezorApplicationError.unknown(e.toString());
  }
}
