import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart';

part 'watch_only_wallet_entity.freezed.dart';

@freezed
abstract class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity({
    required WatchOnly watchOnly,
    required WalletSource source,
    @Default('') String label,
    @Default('') String masterFingerprint,
  }) = _WatchOnlyWalletEntity;

  factory WatchOnlyWalletEntity.fromSatoshifier({
    required WatchOnly watchOnly,
    String label = '',
    String masterFingerprint = '',
  }) {
    return WatchOnlyWalletEntity(
      watchOnly: watchOnly,
      source:
          watchOnly.canGenerateValidPsbt
              ? WalletSource.descriptors
              : WalletSource.xpub,
      label: label,
      masterFingerprint: masterFingerprint,
    );
  }

  static Future<WatchOnlyWalletEntity> parse(String input) async {
    try {
      final watchOnly = await Satoshifier.parse(input);

      if (watchOnly is! WatchOnly) {
        throw 'Unsupported watch only format';
      }

      final masterFingerprint =
          watchOnly.masterFingerprint.isNotEmpty
              ? watchOnly.masterFingerprint
              : watchOnly.pubkeyFingerprint;

      final source =
          watchOnly.canGenerateValidPsbt
              ? WalletSource.descriptors
              : WalletSource.xpub;

      return WatchOnlyWalletEntity(
        watchOnly: watchOnly,
        masterFingerprint: masterFingerprint,
        source: source,
      );
    } catch (e) {
      rethrow;
    }
  }

  const WatchOnlyWalletEntity._();

  Descriptor get descriptor => watchOnly.descriptor;
  ExtendedPubkey? get extendedPublicKey => watchOnly.extendedPubkey;
  String get pubkeyFingerprint => watchOnly.pubkeyFingerprint;
  bool get canGenerateValidPsbt =>
      masterFingerprint.isNotEmpty && masterFingerprint != pubkeyFingerprint;
}
