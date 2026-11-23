import 'package:wallet_import/wallet_import.dart';
import 'package:bip32_keys/bip32_keys.dart'
    show changeVersionBytes, Slip132Format;
import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart'
    show
        BitcoinNetwork,
        Err,
        NetworkEnv,
        Ok,
        ScriptType,
        UnsupportedNetworkException;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

part 'watch_only_wallet_entity.freezed.dart';

@freezed
sealed class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity.descriptor({
    required satoshifier.WatchOnlyDescriptor watchOnlyDescriptor,
    Network? selectedNetwork,
    @Default(SignerEntity.remote) SignerEntity signer,
    @Default('') String label,
    SignerDevice? signerDevice,
    String? keyOrigin,
  }) = WatchOnlyDescriptorEntity;

  const factory WatchOnlyWalletEntity.xpub({
    required satoshifier.WatchOnlyXpub watchOnlyXpub,
    Network? selectedNetwork,
    String? keyOrigin,
    SignerDevice? signerDevice,
    @Default(SignerEntity.none) SignerEntity signer,
    @Default('') String label,
  }) = WatchOnlyXpubEntity;

  const WatchOnlyWalletEntity._();

  T when<T>({
    required T Function(
      satoshifier.WatchOnlyDescriptor watchOnlyDescriptor,
      SignerEntity signer,
      String label,
    )
    descriptor,
    required T Function(
      satoshifier.WatchOnlyXpub watchOnlyXpub,
      SignerEntity signer,
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

  /// The app's confirmation and storage representation also carries the
  /// editable label and legacy signer classification.
  factory WatchOnlyWalletEntity.fromInput(WatchOnlyInput input) {
    final selected = input.selectedNetwork;
    final network = selected == null ? null : _legacyNetwork(selected);
    return switch (input) {
      WatchOnlyDescriptorInput() => WatchOnlyWalletEntity.descriptor(
        watchOnlyDescriptor: input.value,
        selectedNetwork: network,
        signerDevice: input.signerDevice,
        keyOrigin: input.keyOrigin,
        signer: network == Network.bitcoinRegtest
            ? SignerEntity.none
            : SignerEntity.remote,
      ),
      WatchOnlyXpubInput() => WatchOnlyWalletEntity.xpub(
        watchOnlyXpub: input.value,
        selectedNetwork: network,
        signerDevice: input.signerDevice,
        keyOrigin: input.keyOrigin,
      ),
    };
  }

  String get pubkey => when(
    descriptor: (x, _, _) => x.descriptor.pubkey,
    xpub: (x, _, _) => x.extendedPubkey.pubBase58,
  );

  Network get network => selectedNetwork ?? keyNetwork;

  Network get keyNetwork => when(
    descriptor: (x, _, _) => Network.fromName(x.descriptor.network.name),
    xpub: (x, _, _) => Network.fromName(x.extendedPubkey.network.name),
  );

  WatchOnlyWalletEntity captureEnvironment(NetworkEnv environment) {
    final captured = selectedNetwork;
    if (captured != null && captured.environment != environment) {
      throw const WatchOnlyNetworkMismatchException();
    }
    final entity = this;
    final input = switch (entity) {
      WatchOnlyDescriptorEntity() => WatchOnlyInput.fromDescriptor(
        entity.watchOnlyDescriptor,
        signerDevice: entity.signerDevice,
        keyOrigin: entity.keyOrigin,
      ),
      WatchOnlyXpubEntity() => WatchOnlyInput.fromXpub(
        entity.watchOnlyXpub,
        signerDevice: entity.signerDevice,
        keyOrigin: entity.keyOrigin,
      ),
    };
    final bound = switch (input) {
      Ok(:final value) => value.captureEnvironment(environment),
      Err() => input,
    };
    return switch (bound) {
      Ok(:final value) => WatchOnlyWalletEntity.fromInput(value).copyWith(
        label: label,
        signer: environment == NetworkEnv.regtest ? SignerEntity.none : signer,
      ),
      Err(failure: WatchOnlyNetworkMismatchFailure()) =>
        throw const WatchOnlyNetworkMismatchException(),
      Err() => throw const FormatException('Invalid watch-only wallet'),
    };
  }

  WatchOnlyWalletEntity captureNetwork(Network selected) {
    if (!selected.isBitcoin) throw const WatchOnlyNetworkMismatchException();
    return captureEnvironment(selected.environment);
  }

  static Network _legacyNetwork(BitcoinNetwork network) => switch (network) {
    BitcoinNetwork.mainnet => Network.bitcoinMainnet,
    BitcoinNetwork.testnet => Network.bitcoinTestnet,
    BitcoinNetwork.regtest => Network.bitcoinRegtest,
    BitcoinNetwork.signet => throw const UnsupportedNetworkException(),
  };

  ScriptType get scriptType => when(
    descriptor: (x, _, _) => ScriptType.fromName(x.descriptor.derivation.name),
    xpub: (x, _, _) => ScriptType.fromName(x.extendedPubkey.derivation.name),
  );
}

extension WatchOnlyXpubEntityExtension on WatchOnlyXpubEntity {
  satoshifier.ExtendedPubkey get extendedPubkey => watchOnlyXpub.extendedPubkey;

  String get bip32Pubkey => changeVersionBytes(
    pubkey,
    network.isMainnet ? Slip132Format.xpub : Slip132Format.tpub,
  );
}

extension WatchOnlyDescriptorEntityExtension on WatchOnlyDescriptorEntity {
  satoshifier.Descriptor get descriptor => watchOnlyDescriptor.descriptor;
  String get masterFingerprint => watchOnlyDescriptor.masterFingerprint;
  String get pubkeyFingerprint => watchOnlyDescriptor.pubkeyFingerprint;
}

final class WatchOnlyNetworkMismatchException implements Exception {
  const WatchOnlyNetworkMismatchException();
}
