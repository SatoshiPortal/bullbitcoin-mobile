import 'package:bb_mobile/core/primitives/network/network_environment.dart';
import 'package:bb_mobile/core/primitives/signer/signer.dart';
import 'package:bb_mobile/core/primitives/signer/signer_device.dart';
import 'package:bb_mobile/features/wallets/domain/errors/wallet_errors_dart';

sealed class WalletConfigEntity {
  final int _walletId;

  WalletConfigEntity({required int walletId}) : _walletId = walletId;

  int get walletId => _walletId;
}

class BitcoinWalletConfigEntity extends WalletConfigEntity {
  final BitcoinNetworkEnvironment _networkEnvironment;
  final String _masterFingerprint;
  final String _xpub;
  final String _externalPublicDescriptor;
  final String _internalPublicDescriptor;
  final Signer _signer;
  final SignerDevice? _signerDevice;

  BitcoinWalletConfigEntity._({
    required int walletId,
    required BitcoinNetworkEnvironment networkEnvironment,
    required String masterFingerprint,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required Signer signer,
    SignerDevice? signerDevice,
  }) : _networkEnvironment = networkEnvironment,
       _masterFingerprint = masterFingerprint,
       _xpub = xpub,
       _externalPublicDescriptor = externalPublicDescriptor,
       _internalPublicDescriptor = internalPublicDescriptor,
       _signer = signer,
       _signerDevice = signerDevice,
       super(walletId: walletId);

  factory BitcoinWalletConfigEntity.createNew({
    required int walletId,
    required BitcoinNetworkEnvironment networkEnvironment,
    required String masterFingerprint,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required Signer signer,
    SignerDevice? signerDevice,
  }) {
    final config = BitcoinWalletConfigEntity._(
      walletId: walletId,
      networkEnvironment: networkEnvironment,
      masterFingerprint: masterFingerprint,
      xpub: xpub,
      externalPublicDescriptor: externalPublicDescriptor,
      internalPublicDescriptor: internalPublicDescriptor,
      signer: signer,
      signerDevice: signerDevice,
    );

    config.validate();

    return config;
  }

  factory BitcoinWalletConfigEntity.rehydrate({
    required int walletId,
    required BitcoinNetworkEnvironment networkEnvironment,
    required String masterFingerprint,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required Signer signer,
    SignerDevice? signerDevice,
  }) {
    return BitcoinWalletConfigEntity._(
      walletId: walletId,
      networkEnvironment: networkEnvironment,
      masterFingerprint: masterFingerprint,
      xpub: xpub,
      externalPublicDescriptor: externalPublicDescriptor,
      internalPublicDescriptor: internalPublicDescriptor,
      signer: signer,
      signerDevice: signerDevice,
    );
  }

  void validate() {
    if (_signer == Signer.remote && _signerDevice == null) {
      throw MissingSignerDeviceError(walletId: walletId);
    }
    if ((_signer == Signer.local || _signer == Signer.none) &&
        _signerDevice != null) {
      throw WrongSignerForDeviceError(
        walletId: walletId,
        signer: _signer,
        signerDevice: _signerDevice,
      );
    }
  }

  BitcoinNetworkEnvironment get networkEnvironment => _networkEnvironment;
  String get masterFingerprint => _masterFingerprint;
  String get xpub => _xpub;
  String get externalPublicDescriptor => _externalPublicDescriptor;
  String get internalPublicDescriptor => _internalPublicDescriptor;
  Signer get signer => _signer;
  SignerDevice? get signerDevice => _signerDevice;
}
