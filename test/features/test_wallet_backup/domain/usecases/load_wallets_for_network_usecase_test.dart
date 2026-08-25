import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockWalletRepository walletRepository;
  late LoadWalletsForNetworkUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    walletRepository = _MockWalletRepository();
    usecase = LoadWalletsForNetworkUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
    );
  });

  test(
    'returns only standard single-signature wallets with one local seed',
    () async {
      final eligible = _wallet(
        origin: 'eligible',
        signers: [
          WalletSigner.single(
            masterFingerprint: '11111111',
            xpubFingerprint: '11111112',
            xpub: 'xpub-eligible',
            derivationPath: "m/84'/0'/0'",
            descriptorPath: standardSingleSignatureDescriptorPath,
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
        scriptType: ScriptType.bip84,
        externalDescriptor: 'wpkh([11111111/84h/0h/0h]xpub-eligible/0/*)',
        internalDescriptor: 'wpkh([11111111/84h/0h/0h]xpub-eligible/1/*)',
      );
      final multisig = _wallet(
        origin: 'multisig',
        signers: [
          WalletSigner.single(
            masterFingerprint: '22222222',
            xpubFingerprint: '22222223',
            xpub: 'xpub-multisig-one',
            derivationPath: "m/48'/0'/0'/2'",
            signer: SignerEntity.local,
            signerDevice: null,
          ),
          WalletSigner.single(
            masterFingerprint: '33333333',
            xpubFingerprint: '33333334',
            xpub: 'xpub-multisig-two',
            derivationPath: "m/48'/0'/0'/2'",
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
        scriptType: null,
        externalDescriptor: 'wsh(sortedmulti(2,xpub-one/0/*,xpub-two/0/*))',
        internalDescriptor: 'wsh(sortedmulti(2,xpub-one/1/*,xpub-two/1/*))',
      );
      final miniscript = _wallet(
        origin: 'miniscript',
        signers: [
          WalletSigner.single(
            masterFingerprint: '44444444',
            xpubFingerprint: '44444445',
            xpub: 'xpub-miniscript',
            derivationPath: "m/84'/0'/0'",
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
        scriptType: null,
        externalDescriptor: 'wsh(and_v(v:pk(xpub-miniscript/0/*),older(10)))',
        internalDescriptor: 'wsh(and_v(v:pk(xpub-miniscript/1/*),older(10)))',
      );
      final missingFingerprint = _wallet(
        origin: 'missing-fingerprint',
        signers: [
          WalletSigner.single(
            masterFingerprint: '',
            xpubFingerprint: '55555555',
            xpub: 'xpub-missing-fingerprint',
            derivationPath: "m/84'/0'/0'",
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
        scriptType: ScriptType.bip84,
        externalDescriptor: 'wpkh(xpub-missing-fingerprint/0/*)',
        internalDescriptor: 'wpkh(xpub-missing-fingerprint/1/*)',
      );

      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(
        () => walletRepository.getWallets(
          environment: Environment.mainnet,
          onlyDefaults: false,
          onlyBitcoin: true,
        ),
      ).thenAnswer(
        (_) async => [multisig, miniscript, missingFingerprint, eligible],
      );

      expect(await usecase.execute(), [eligible]);
    },
  );
}

Wallet _wallet({
  required String origin,
  required List<WalletSigner> signers,
  required ScriptType? scriptType,
  required String externalDescriptor,
  required String internalDescriptor,
}) {
  final expectedInternalDescriptor = externalDescriptor.replaceAll(
    '/0/*',
    '/1/*',
  );
  final publicDescriptor = internalDescriptor == expectedInternalDescriptor
      ? externalDescriptor.replaceAll('/0/*', '/<0;1>/*')
      : externalDescriptor;

  return Wallet(
    origin: origin,
    network: Network.bitcoinMainnet,
    signers: signers,
    scriptType: scriptType,
    publicDescriptor: publicDescriptor,
    balanceSat: BigInt.zero,
  );
}
