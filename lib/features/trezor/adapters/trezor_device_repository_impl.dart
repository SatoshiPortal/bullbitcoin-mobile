import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';
import 'package:trezor_connect/models.dart';

class TrezorDeviceRepositoryImpl implements TrezorDeviceRepository {
  final TrezorConnectDatasource _datasource;

  String? _cachedMasterFingerprint;

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

      // Trezor includes the master fingerprint in the descriptor field of
      // every returned account: `wpkh([<masterFp>/84h/0h/<idx>h]xpub.../<0;1>/*)`.
      // Parse it once and cache for the session. This avoids a second
      // deeplink round-trip for `m` — which Trezor refuses with "Invalid
      // parameters from calling app".

      if (_cachedMasterFingerprint == null && raw.isNotEmpty) {
        final fp = _extractMasterFingerprint(raw.first.descriptor);
        if (fp != null) {
          _cachedMasterFingerprint = fp;
        } else {
          log.warning(
            'could not parse master fingerprint from '
            'descriptor: ${raw.first.descriptor}',
          );
        }
      }

      final accounts = raw.map(_toAccount).toList();
      return accounts;
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
  Future<String> getMasterFingerprint() async {
    final cached = _cachedMasterFingerprint;
    if (cached != null) {
      return cached;
    }
    // No deeplink fallback: Trezor refuses path "m" with "Invalid
    // parameters from calling app". The master fingerprint is parsed from
    // any account's descriptor in getAccounts above. If we get here, the
    // caller forgot to call getAccounts first.
    throw Exception(
      'master fingerprint not yet cached — call getAccounts first so '
      'descriptor parsing can extract it',
    );
  }

  TrezorAccount _toAccount(TrezorAddressPublicKey raw) {
    // path[2] is the account index (hardened); unharden by subtracting
    // 0x80000000 to get the human-readable index (0, 1, 2, …).
    final hardened = raw.path[2];
    final accountIndex = hardened - 0x80000000;

    // Compact, stable label for the account picker: "0 - zpub6q…ab12cd".
    // A real first-receive address would need a heavyweight bdk_dart Wallet
    // construction (Persister + DB); deferred until needed for confirm-on-
    // device receive flows. The xpub prefix uniquely identifies the account.
    final xpubPreview = raw.xpub.length > 12
        ? '${raw.xpub.substring(0, 6)}…${raw.xpub.substring(raw.xpub.length - 6)}'
        : raw.xpub;

    return TrezorAccount(
      accountIndex: accountIndex,
      derivationPath: raw.serializedPath,
      xpub: raw.xpub,
      previewAddress: xpubPreview,
    );
  }

  TrezorApplicationError _mapError(Exception e) {
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
