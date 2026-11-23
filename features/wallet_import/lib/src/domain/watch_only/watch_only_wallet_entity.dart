import 'package:wallet_import/src/domain/watch_only_input.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:bip32_keys/bip32_keys.dart'
    show changeVersionBytes, Slip132Format;
import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:primitives/primitives.dart'
    show
        BitcoinNetwork,
        Err,
        NetworkEnv,
        Ok,
        Result,
        ScriptType,
        UnsupportedNetworkException;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

part 'watch_only_wallet_entity.freezed.dart';

@freezed
sealed class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity.descriptor({
    required satoshifier.WatchOnlyDescriptor watchOnlyDescriptor,
    BitcoinNetwork? selectedNetwork,
    @Default(SignerEntity.remote) SignerEntity signer,
    @Default('') String label,
    SignerDevice? signerDevice,
    String? keyOrigin,
  }) = WatchOnlyDescriptorEntity;

  const factory WatchOnlyWalletEntity.xpub({
    required satoshifier.WatchOnlyXpub watchOnlyXpub,
    BitcoinNetwork? selectedNetwork,
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

  /// The confirmation form carries the editable label and signer selection.
  factory WatchOnlyWalletEntity.fromInput(WatchOnlyInput input) {
    final network = input.selectedNetwork;
    return switch (input) {
      WatchOnlyDescriptorInput() => WatchOnlyWalletEntity.descriptor(
        watchOnlyDescriptor: input.value,
        selectedNetwork: network,
        signerDevice: input.signerDevice,
        keyOrigin: input.keyOrigin,
        signer: network == BitcoinNetwork.regtest
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

  BitcoinNetwork get network => selectedNetwork ?? keyNetwork;

  BitcoinNetwork get keyNetwork => when(
    descriptor: (x, _, _) => _bitcoinNetwork(x.descriptor.network),
    xpub: (x, _, _) => _bitcoinNetwork(x.extendedPubkey.network),
  );

  Result<WatchOnlyInput, ImportWatchOnlyFailure> validatedInput(
    NetworkEnv environment,
  ) {
    final captured = selectedNetwork;
    if (captured != null && captured.env != environment) {
      return const Err(NetworkMismatchFailure());
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
    return bound.mapErr(
      (failure) => failure is WatchOnlyNetworkMismatchFailure
          ? const NetworkMismatchFailure()
          : const InvalidFormatFailure(),
    );
  }

  static BitcoinNetwork _bitcoinNetwork(satoshifier.Network network) =>
      switch (network) {
        satoshifier.Network.bitcoinMainnet => BitcoinNetwork.mainnet,
        satoshifier.Network.bitcoinTestnet => BitcoinNetwork.testnet,
        satoshifier.Network.bitcoinRegtest => BitcoinNetwork.regtest,
        _ => throw const UnsupportedNetworkException(),
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
}
