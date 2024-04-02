// ignore_for_file: unused_local_variable

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class WalletSensitiveCreate {
  Future<(List<String>?, Err?)> createMnemonic() async {
    try {
      final mne = await bdk.Mnemonic.create(bdk.WordCount.Words12);
      final mneList = mne.asString().split(' ');

      return (mneList, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while creating mnemonic',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(String?, Err?)> getFingerprint({
    required String mnemonic,
    String? passphrase,
  }) async {
    try {
      final mn = await bdk.Mnemonic.fromString(mnemonic);
      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        network: bdk.Network.Bitcoin,
        mnemonic: mn,
        password: passphrase,
      );

      final externalDescriptor = await bdk.Descriptor.newBip84(
        secretKey: descriptorSecretKey,
        network: bdk.Network.Bitcoin,
        keychain: bdk.KeychainKind.External,
      );
      final edesc = await externalDescriptor.asString();
      final fgnr = fingerPrintFromXKeyDesc(edesc);

      return (fgnr, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while creating fingerprint',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Seed?, Err?)> mnemonicSeed(
    String mnemonic,
    BBNetwork network,
  ) async {
    try {
      final (mnemonicFingerprint, err) = await getFingerprint(
        mnemonic: mnemonic,
        passphrase: '',
      );
      if (err != null) throw err;

      final seed = Seed(
        mnemonic: mnemonic,
        mnemonicFingerprint: mnemonicFingerprint!,
        passphrases: [],
        network: network,
      );
      return (seed, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while creating seed',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(List<Wallet>?, Err?)> allFromBIP39(
    String mnemonic,
    String passphrase,
    BBNetwork network,
    bool isImported,
  ) async {
    final bdkMnemonic = await bdk.Mnemonic.fromString(mnemonic);
    final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

    final rootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );
    final (mnemonicFingerprint, _) = await getFingerprint(
      mnemonic: mnemonic,
      passphrase: '',
    );
    final (sourceFingerprint, _) = await getFingerprint(
      mnemonic: mnemonic,
      passphrase: passphrase,
    );

    final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
    const accountPath = '0h';

    final bdkXpriv44 = await rootXprv.derive(
      await bdk.DerivationPath.create(path: 'm/44h/$networkPath/$accountPath'),
    );
    final bdkXpriv49 = await rootXprv.derive(
      await bdk.DerivationPath.create(path: 'm/49h/$networkPath/$accountPath'),
    );
    final bdkXpriv84 = await rootXprv.derive(
      await bdk.DerivationPath.create(path: 'm/84h/$networkPath/$accountPath'),
    );

    final bdkXpub44 = await bdkXpriv44.asPublic();
    final bdkXpub49 = await bdkXpriv49.asPublic();
    final bdkXpub84 = await bdkXpriv84.asPublic();

    final bdkDescriptor44External = await bdk.Descriptor.newBip44Public(
      publicKey: bdkXpub44,
      fingerPrint: sourceFingerprint!,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    final bdkDescriptor44Internal = await bdk.Descriptor.newBip44Public(
      publicKey: bdkXpub44,
      fingerPrint: sourceFingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );
    final bdkDescriptor49External = await bdk.Descriptor.newBip49Public(
      publicKey: bdkXpub49,
      fingerPrint: sourceFingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    final bdkDescriptor49Internal = await bdk.Descriptor.newBip49Public(
      publicKey: bdkXpub49,
      fingerPrint: sourceFingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );
    final bdkDescriptor84External = await bdk.Descriptor.newBip84Public(
      publicKey: bdkXpub84,
      fingerPrint: sourceFingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    final bdkDescriptor84Internal = await bdk.Descriptor.newBip84Public(
      publicKey: bdkXpub84,
      fingerPrint: sourceFingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );

    final wallet44HashId =
        createDescriptorHashId(await bdkDescriptor44External.asString()).substring(0, 12);
    var wallet44 = Wallet(
      id: wallet44HashId,
      externalPublicDescriptor: await bdkDescriptor44External.asString(),
      internalPublicDescriptor: await bdkDescriptor44Internal.asString(),
      mnemonicFingerprint: mnemonicFingerprint!,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: BBWalletType.words,
      scriptType: ScriptType.bip44,
      backupTested: isImported,
    );
    final (bdkWallet44, errBdk44) = await WalletCreate().loadPublicBdkWallet(wallet44);
    final firstAddress44 = await bdkWallet44!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet44 = wallet44.copyWith(
      name: wallet44.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress44.address,
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );
    final wallet49HashId =
        createDescriptorHashId(await bdkDescriptor49External.asString()).substring(0, 12);
    var wallet49 = Wallet(
      id: wallet49HashId,
      externalPublicDescriptor: await bdkDescriptor49External.asString(),
      internalPublicDescriptor: await bdkDescriptor49Internal.asString(),
      mnemonicFingerprint: mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: BBWalletType.words,
      scriptType: ScriptType.bip49,
      backupTested: isImported,
    );
    final (bdkWallet49, errBdk49) = await WalletCreate().loadPublicBdkWallet(wallet49);
    final firstAddress49 = await bdkWallet49!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet49 = wallet49.copyWith(
      name: wallet49.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress49.address,
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );
    final wallet84HashId =
        createDescriptorHashId(await bdkDescriptor84External.asString()).substring(0, 12);
    var wallet84 = Wallet(
      id: wallet84HashId,
      externalPublicDescriptor: await bdkDescriptor84External.asString(),
      internalPublicDescriptor: await bdkDescriptor84Internal.asString(),
      mnemonicFingerprint: mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: BBWalletType.words,
      scriptType: ScriptType.bip84,
      backupTested: isImported,
    );
    final (bdkWallet84, errBdk84) = await WalletCreate().loadPublicBdkWallet(wallet84);
    final firstAddress84 = await bdkWallet84!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet84 = wallet84.copyWith(
      name: wallet84.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress84.address,
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );
    return ([wallet44, wallet49, wallet84], null);
  }

  Future<(Wallet?, Err?)> oneFromBIP39({
    required Seed seed,
    required String passphrase,
    required ScriptType scriptType,
    required BBWalletType walletType,
    required BBNetwork network,
  }) async {
    final bdkMnemonic = await bdk.Mnemonic.fromString(seed.mnemonic);
    final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
    final rootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );
    final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
    const accountPath = '0h';

    // final sourceFingerprint = fing/erPrintFromXKeyDesc(bdkXpub84.asString());
    final (sourceFingerprint, sfErr) = await getFingerprint(
      mnemonic: seed.mnemonic,
      passphrase: passphrase,
    );
    if (sfErr != null) {
      return (null, Err('Error Getting Fingerprint'));
    }
    bdk.Descriptor? internal;
    bdk.Descriptor? external;

    switch (scriptType) {
      case ScriptType.bip84:
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
      case ScriptType.bip49:
        final bdkXpriv49 = await rootXprv.derive(
          await bdk.DerivationPath.create(path: 'm/49h/$networkPath/$accountPath'),
        );

        final bdkXpub49 = await bdkXpriv49.asPublic();
        internal = await bdk.Descriptor.newBip49Public(
          publicKey: bdkXpub49,
          fingerPrint: sourceFingerprint!,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.Internal,
        );
        external = await bdk.Descriptor.newBip49Public(
          publicKey: bdkXpub49,
          fingerPrint: sourceFingerprint,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.External,
        );
      case ScriptType.bip44:
        final bdkXpriv44 = await rootXprv.derive(
          await bdk.DerivationPath.create(path: 'm/44h/$networkPath/$accountPath'),
        );
        final bdkXpub44 = await bdkXpriv44.asPublic();
        internal = await bdk.Descriptor.newBip44Public(
          publicKey: bdkXpub44,
          fingerPrint: sourceFingerprint!,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.Internal,
        );
        external = await bdk.Descriptor.newBip44Public(
          publicKey: bdkXpub44,
          fingerPrint: sourceFingerprint,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.External,
        );
    }

    final descHashId = createDescriptorHashId(await external.asString()).substring(0, 12);
    // final type = isImported ? BBWalletType.words : BBWalletType.newSeed;

    var wallet = Wallet(
      id: descHashId,
      externalPublicDescriptor: await external.asString(),
      internalPublicDescriptor: await internal.asString(),
      mnemonicFingerprint: seed.mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: walletType,
      // type: isImported ? BBWalletType.words : BBWalletType.newSeed,
      scriptType: scriptType,
      // backupTested: false,
      // backupTested: isImported,
    );
    final (bdkWallet, errBdk) = await WalletCreate().loadPublicBdkWallet(wallet);
    final firstAddress = await bdkWallet!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet = wallet.copyWith(
      name: wallet.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress.address,
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );
    return (wallet, null);
  }

  Future<(Wallet?, Err?)> oneLiquidFromBIP39({
    required Seed seed,
    required String passphrase,
    required ScriptType scriptType,
    required BBWalletType walletType,
    required BBNetwork network,
    // bool isImported,
  }) async {
    final lwkNetwork = network == BBNetwork.LMainnet ? lwk.Network.Mainnet : lwk.Network.Testnet;
    final lwk.Descriptor descriptor = await lwk.Descriptor.create(
      network: lwkNetwork,
      mnemonic: seed.mnemonic,
    );

    final (sourceFingerprint, sfErr) = await getFingerprint(
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

    final descHashId =
        createDescriptorHashId(descriptor.descriptor.substring(0, 12), network: network);
    // final descHashId = createDescriptorHashId(await external.asString()).substring(0, 12);
    // final type = isImported ? BBWalletType.words : BBWalletType.newSeed;

    var wallet = Wallet(
      id: descHashId,
      externalPublicDescriptor: descriptor.descriptor, // TODO: // await external.asString(),
      internalPublicDescriptor: descriptor.descriptor, // TODO: // await internal.asString(),
      mnemonicFingerprint: seed.mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint!,
      network: network,
      type: walletType,
      scriptType: scriptType,
    );
    // final (bdkWallet, errBdk) = await WalletCreate().loadPublicBdkWallet(wallet);
    // final firstAddress = await bdkWallet!.getAddress(
    //   addressIndex: const bdk.AddressIndex.peek(index: 0),
    // );

    final (lwkWallet, errLwk) = await WalletCreate().loadPublicLwkWallet(wallet, seed);
    final firstAddress = await lwkWallet?.addressAtIndex(0);
    wallet = wallet.copyWith(
      name: wallet.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress?.standard ?? '',
        confidential: firstAddress?.confidential ?? '',
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );
    return (wallet, null);
  }

  Future<(bdk.Wallet?, Err?)> loadPrivateBdkWallet(
    Wallet wallet,
    Seed seed,
  ) async {
    try {
      final network =
          wallet.network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final mn = await bdk.Mnemonic.fromString(seed.mnemonic);
      final pp = wallet.hasPassphrase()
          ? seed.passphrases
              .firstWhere((element) => element.sourceFingerprint == wallet.sourceFingerprint)
          : Passphrase(
              sourceFingerprint: wallet.mnemonicFingerprint,
            );

      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        network: network,
        mnemonic: mn,
        password: pp.passphrase,
      );

      bdk.Descriptor? internal;
      bdk.Descriptor? external;

      switch (wallet.scriptType) {
        case ScriptType.bip84:
          external = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          internal = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.Internal,
          );

        case ScriptType.bip44:
          external = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          internal = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.Internal,
          );

        case ScriptType.bip49:
          external = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          internal = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.Internal,
          );
      }

      const dbConfig = bdk.DatabaseConfig.memory();

      final bdkWallet = await bdk.Wallet.create(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        databaseConfig: dbConfig,
      );

      return (bdkWallet, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while loading wallet',
          solution: 'Please try again.',
        )
      );
    }
  }
}
