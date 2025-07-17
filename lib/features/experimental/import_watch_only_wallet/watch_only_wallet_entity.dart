import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

part 'watch_only_wallet_entity.freezed.dart';

@freezed
abstract class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity.descriptor({
    required satoshifier.WatchOnlyDescriptor watchOnlyDescriptor,
    @Default(Signer.remote) Signer signer,
    @Default('') String label,
    @Default(null) SignerDevice? signerDevice,
  }) = WatchOnlyDescriptorEntity;

  const factory WatchOnlyWalletEntity.xpub({
    required satoshifier.WatchOnlyXpub watchOnlyXpub,
    @Default(Signer.none) Signer signer,
    @Default('') String label,
  }) = WatchOnlyXpubEntity;

  const WatchOnlyWalletEntity._();

  T when<T>({
    required T Function(
      satoshifier.WatchOnlyDescriptor watchOnlyDescriptor,
      Signer signer,
      String label,
    )
    descriptor,
    required T Function(
      satoshifier.WatchOnlyXpub watchOnlyXpub,
      Signer signer,
      String label,
    )
    xpub,
  }) {
    if (this is WatchOnlyDescriptorEntity) {
      final entity = this as WatchOnlyDescriptorEntity;
      return descriptor(
        entity.watchOnlyDescriptor,
        entity.signer,
        entity.label,
      );
    } else if (this is WatchOnlyXpubEntity) {
      final entity = this as WatchOnlyXpubEntity;
      return xpub(entity.watchOnlyXpub, entity.signer, entity.label);
    }
    throw UnimplementedError();
  }

  static Future<WatchOnlyWalletEntity> parse(String value) async {
    final satoshified = await satoshifier.Satoshifier.parse(value);
    if (satoshified is satoshifier.WatchOnlyDescriptor) {
      return WatchOnlyWalletEntity.descriptor(watchOnlyDescriptor: satoshified);
    } else if (satoshified is satoshifier.WatchOnlyXpub) {
      return WatchOnlyWalletEntity.xpub(watchOnlyXpub: satoshified);
    }
    throw Exception('Unsupported watch only format');
  }

  String get pubkey => when(
    descriptor: (x, _, _) => x.descriptor.pubkey,
    xpub: (x, _, _) => x.extendedPubkey.pubBase58,
  );

  Network get network => when(
    descriptor: (x, _, _) => Network.fromName(x.descriptor.network.name),
    xpub: (x, _, _) => Network.fromName(x.extendedPubkey.network.name),
  );

  ScriptType get scriptType => when(
    descriptor: (x, _, _) => ScriptType.fromName(x.descriptor.derivation.name),
    xpub: (x, _, _) => ScriptType.fromName(x.extendedPubkey.derivation.name),
  );
}

extension WatchOnlyXpubEntityExtension on WatchOnlyXpubEntity {
  satoshifier.ExtendedPubkey get extendedPubkey => watchOnlyXpub.extendedPubkey;
}

extension WatchOnlyDescriptorEntityExtension on WatchOnlyDescriptorEntity {
  satoshifier.Descriptor get descriptor => watchOnlyDescriptor.descriptor;
  String get masterFingerprint => watchOnlyDescriptor.masterFingerprint;
  String get pubkeyFingerprint => watchOnlyDescriptor.pubkeyFingerprint;
}
