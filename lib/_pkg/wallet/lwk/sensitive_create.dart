import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/create.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LWKSensitiveCreate {
  LWKSensitiveCreate({
    required BDKSensitiveCreate bdkSensitiveCreate,
    required LWKCreate lwkCreate,
  })  : _bdkSensitiveCreate = bdkSensitiveCreate,
        _lwkCreate = lwkCreate;

  final BDKSensitiveCreate _bdkSensitiveCreate;
  final LWKCreate _lwkCreate;

  Future<(Wallet?, Err?)> oneLiquidFromBIP39({
    required Seed seed,
    required String passphrase,
    required ScriptType scriptType,
    required BBWalletType walletType,
    required BBNetwork network,
    required WalletCreate walletCreate,
    // bool isImported,
  }) async {
    final lwkNetwork = network == BBNetwork.Mainnet ? lwk.Network.mainnet : lwk.Network.testnet;
    final lwk.Descriptor descriptor = await lwk.Descriptor.newConfidential(
      network: lwkNetwork,
      mnemonic: seed.mnemonic,
    );

    final (sourceFingerprint, sfErr) = await _bdkSensitiveCreate.getFingerprint(
      mnemonic: seed.mnemonic,
      passphrase: passphrase,
    );
    if (sfErr != null) {
      return (null, Err('Error Getting Fingerprint'));
    }

    /*
    bdk.Descriptor? internal;
    bdk.Descriptor? external;

    final rootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );
    final mOnlybdkXpriv84 = await rootXprv.derive(
      await bdk.DerivationPath.create(path: 'm/84h/$networkPath/$accountPath'),
    );

    final bdkXpub84 = await mOnlybdkXpriv84.asPublic();

    internal = await bdk.Descriptor.newBip84Public(
      publicKey: bdkXpub84,
      fingerPrint: sourceFingerprint!,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );
    external = await bdk.Descriptor.newBip84Public(
      publicKey: bdkXpub84,
      fingerPrint: sourceFingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    */

    final descHashId = createDescriptorHashId(
      descriptor.ctDescriptor.substring(0, 12),
      network: network,
    );
    // final descHashId = createDescriptorHashId(await external.asString()).substring(0, 12);
    // final type = isImported ? BBWalletType.words : BBWalletType.newSeed;

    var wallet = Wallet(
      id: descHashId,
      externalPublicDescriptor: descriptor.ctDescriptor, // TODO: // await external.asString(),
      internalPublicDescriptor: descriptor.ctDescriptor, // TODO: // await internal.asString(),
      mnemonicFingerprint: seed.mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint!,
      network: network,
      type: walletType,
      scriptType: scriptType,
      baseWalletType: BaseWalletType.Liquid,
    );
    // final (bdkWallet, errBdk) = await WalletCreate().loadPublicBdkWallet(wallet);
    // final firstAddress = await bdkWallet!.getAddress(
    //   addressIndex: const bdk.AddressIndex.peek(index: 0),
    // );

    final (lwkWallet, errLwk) = await _lwkCreate.loadPublicLwkWallet(wallet);
    if (errLwk != null) return (null, errLwk);
    // final (lwkWallet, errLoading) = _walletsRepository.getLwkWallet(wallet);
    // if (errLoading != null) return (null, errLoading);
    final firstAddress = await lwkWallet?.address(index: 0);
    wallet = wallet.copyWith(
      name: wallet.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress?.confidential ?? '',
        standard: firstAddress?.standard ?? '',
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
        isLiquid: true,
      ),
    );
    return (wallet, null);
  }

  Future<(lwk.Wallet?, Err?)> loadPrivateLwkWallet(
    Wallet wallet,
    Seed seed,
  ) async {
    try {
      final network = wallet.network == BBNetwork.Mainnet ? lwk.Network.mainnet : lwk.Network.testnet;

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir = '${appDocDir.path}/db';

      final lwk.Descriptor descriptor = await lwk.Descriptor.newConfidential(
        network: network,
        mnemonic: seed.mnemonic,
      );

      final w = await lwk.Wallet.init(
        network: network,
        dbpath: dbDir,
        descriptor: descriptor,
      );

      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while creating wallet',
          solution: 'Please try again.',
        )
      );
    }
  }
}
