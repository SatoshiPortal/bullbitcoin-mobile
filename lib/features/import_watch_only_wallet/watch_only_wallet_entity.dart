import 'package:bip32_keys/bip32_keys.dart'
    show changeVersionBytes, Slip132Format;
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show NetworkEnv, ScriptType;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

part 'watch_only_wallet_entity.freezed.dart';

@freezed
abstract class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity.descriptor({
    required satoshifier.WatchOnlyDescriptor watchOnlyDescriptor,
    Network? selectedNetwork,
    @Default(SignerEntity.remote) SignerEntity signer,
    @Default('') String label,
    @Default(null) SignerDeviceEntity? signerDevice,
  }) = WatchOnlyDescriptorEntity;

  const factory WatchOnlyWalletEntity.xpub({
    required satoshifier.WatchOnlyXpub watchOnlyXpub,
    Network? selectedNetwork,
    String? keyOrigin,
    @Default(false) bool hardwareRequested,
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

  static Future<WatchOnlyWalletEntity> parse(
    String value, {
    SignerDeviceEntity? signerDevice,
    Network? selectedNetwork,
    NetworkEnv? environment,
  }) async {
    selectedNetwork ??= environment == null
        ? null
        : Network.fromEnvironment(environment: environment, isLiquid: false);
    if (selectedNetwork?.environment == NetworkEnv.regtest &&
        signerDevice != null) {
      throw const FormatException('Hardware import is unavailable on regtest');
    }
    final privateVersion = RegExp(
      r'(?<![A-Za-z0-9])(xprv|yprv|zprv|tprv|uprv|vprv)[1-9A-HJ-NP-Za-km-z]+',
    );
    if (privateVersion.hasMatch(value)) {
      throw FormatException('Watch-only imports require public extended keys');
    }
    final trimmed = value.trim();
    final origin = RegExp(r'^\[[^\]]+\]').firstMatch(trimmed)?.group(0);
    if (selectedNetwork == Network.bitcoinRegtest) {
      _validateRegtestKeyOrigin(origin, declared: trimmed.startsWith('['));
    }
    final normalized = trimmed.replaceFirst(RegExp(r'^\[[^\]]+\]'), '');
    final satoshified = await satoshifier.Satoshifier.parse(normalized);
    if (satoshified is satoshifier.WatchOnlyDescriptor) {
      if (!satoshified.descriptor.network.isBitcoin) {
        throw FormatException('Only Bitcoin watch-only wallets are supported');
      }
      final entity = WatchOnlyWalletEntity.descriptor(
        watchOnlyDescriptor: satoshified,
        signerDevice: signerDevice,
      );
      return selectedNetwork == null
          ? entity
          : entity.captureNetwork(selectedNetwork);
    } else if (satoshified is satoshifier.WatchOnlyXpub) {
      final entity = WatchOnlyWalletEntity.xpub(
        watchOnlyXpub: satoshified,
        keyOrigin: origin,
        hardwareRequested: signerDevice != null,
      );
      return selectedNetwork == null
          ? entity
          : entity.captureNetwork(selectedNetwork);
    }
    throw Exception('Unsupported watch only format');
  }

  static void _validateRegtestKeyOrigin(
    String? origin, {
    bool declared = false,
  }) {
    if ((origin == null && declared) ||
        (origin != null &&
            !RegExp(r"^\[[0-9a-fA-F]{8}/84[h']/1[h']/[0-9]+[h']\]$")
                .hasMatch(origin))) {
      throw const FormatException(
        'Regtest key origin must be BIP84 test-family',
      );
    }
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

  WatchOnlyWalletEntity captureEnvironment(NetworkEnv environment) =>
      captureNetwork(
        Network.fromEnvironment(environment: environment, isLiquid: false),
      );

  /// Test public versions encode a family, not testnet versus regtest.
  /// Only an explicit selected context can resolve that ambiguity.
  WatchOnlyWalletEntity captureNetwork(Network selected) {
    final captured = selectedNetwork;
    if (captured != null && captured != selected) {
      throw const WatchOnlyNetworkMismatchException();
    }
    final encoded = keyNetwork;
    if (!selected.isBitcoin ||
        !encoded.isBitcoin ||
        selected.isMainnet != encoded.isMainnet) {
      throw const WatchOnlyNetworkMismatchException();
    }
    if (selected.environment == NetworkEnv.regtest) {
      var entity = this;
      if (entity is WatchOnlyXpubEntity) {
        if (entity.hardwareRequested) {
          throw const FormatException(
            'Hardware import is unavailable on regtest',
          );
        }
        _validateRegtestKeyOrigin(entity.keyOrigin);
        // A plain tpub has no script declaration. Only this explicit
        // BIP84 context may resolve it, preserving the original public key.
        if (entity.pubkey.startsWith('tpub')) {
          final key = entity.extendedPubkey;
          entity = entity.copyWith(
            watchOnlyXpub: satoshifier.WatchOnlyXpub(
              extendedPubkey: satoshifier.ExtendedPubkey(
                pubkey: key.pubkey,
                derivation: satoshifier.Derivation.bip84,
                network: key.network,
              ),
            ),
          );
        }
      }
      final hasDevice =
          entity is WatchOnlyDescriptorEntity && entity.signerDevice != null;
      if (entity.scriptType != ScriptType.bip84 || hasDevice) {
        throw const FormatException(
          'Regtest requires software BIP84 watch-only input',
        );
      }
      return entity.copyWith(
        selectedNetwork: selected,
        signer: SignerEntity.none,
      );
    }
    if (selected != encoded) throw const WatchOnlyNetworkMismatchException();
    return copyWith(selectedNetwork: selected);
  }

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
