import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletSensitiveCreate {
  Future<(List<String>?, Err?)> createMnemonic() async {
    try {
      final mne = await bdk.Mnemonic.create(bdk.WordCount.Words12);
      final mneList = mne.asString().split(' ');

      return (mneList, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(String?, Err?)> getFingerprint({
    required String mnemonic,
    String? passphrase,
    required bool isTestnet,
    required ScriptType scriptType,
  }) async {
    try {
      final network = isTestnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final mn = await bdk.Mnemonic.fromString(mnemonic);
      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        network: network,
        mnemonic: mn,
        password: passphrase,
      );

      final externalDescriptor = await bdk.Descriptor.newBip84(
        secretKey: descriptorSecretKey,
        network: network,
        keychain: bdk.KeychainKind.External,
      );
      final edesc = await externalDescriptor.asString();
      final fgnr = fingerPrintFromXKeyDesc(edesc);

      return (fgnr, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Seed?, Err?)> mnemonicSeed(
    String mnemonic,
    BBNetwork network,
  ) async {
    try {
      final bdkMnemonic = await bdk.Mnemonic.fromString(mnemonic);
      final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
      final rootXprv = await bdk.DescriptorSecretKey.create(
        network: bdkNetwork,
        mnemonic: bdkMnemonic,
        password: '',
      );
      final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
      const accountPath = '0h';

      final mOnlybdkXpriv84 = await rootXprv.derive(
        await bdk.DerivationPath.create(path: 'm/84h/$networkPath/$accountPath'),
      );

      final mnemonicFingerprint = fingerPrintFromXKeyDesc(mOnlybdkXpriv84.asString());
      final seed = Seed(
        mnemonic: mnemonic,
        mnemonicFingerprint: mnemonicFingerprint,
        passphrases: [],
        network: network,
      );
      return (seed, null);
    } catch (e) {
      return (null, Err(e.toString()));
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

    final mOnlyrootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: '',
    );
    final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
    const accountPath = '0h';

    final mOnlybdkXpriv84 = await mOnlyrootXprv.derive(
      await bdk.DerivationPath.create(path: 'm/84h/$networkPath/$accountPath'),
    );

    final mOnlybdkXpub84 = await mOnlybdkXpriv84.asPublic();

    final mnemonicFingerprint = fingerPrintFromXKeyDesc(mOnlybdkXpub84.asString());

    final rootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );

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

    final sourceFingerprint = fingerPrintFromXKeyDesc(bdkXpub84.asString());

    final bdkDescriptor44External = await bdk.Descriptor.newBip44Public(
      publicKey: bdkXpub44,
      fingerPrint: sourceFingerprint,
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
      mnemonicFingerprint: mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: BBWalletType.words,
      scriptType: ScriptType.bip44,
      backupTested: isImported,
    );
    wallet44 = wallet44.copyWith(name: wallet44.defaultNameString());

    final wallet49HashId =
        createDescriptorHashId(await bdkDescriptor49External.asString()).substring(0, 12);
    var wallet49 = Wallet(
      id: wallet49HashId,
      externalPublicDescriptor: await bdkDescriptor49External.asString(),
      internalPublicDescriptor: await bdkDescriptor49Internal.asString(),
      mnemonicFingerprint: sourceFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: BBWalletType.words,
      scriptType: ScriptType.bip49,
    );
    wallet49 = wallet49.copyWith(name: wallet49.defaultNameString());

    final wallet84HashId =
        createDescriptorHashId(await bdkDescriptor84External.asString()).substring(0, 12);
    var wallet84 = Wallet(
      id: wallet84HashId,
      externalPublicDescriptor: await bdkDescriptor84External.asString(),
      internalPublicDescriptor: await bdkDescriptor84Internal.asString(),
      mnemonicFingerprint: sourceFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: BBWalletType.words,
      scriptType: ScriptType.bip84,
      backupTested: isImported,
    );
    wallet84 = wallet84.copyWith(name: wallet84.defaultNameString());

    return ([wallet44, wallet49, wallet84], null);
  }

  Future<(Wallet?, Err?)> oneFromBIP39(
    Seed seed,
    String passphrase,
    ScriptType scriptType,
    BBNetwork network,
    bool isImported,
  ) async {
    final isTestnet = network == BBNetwork.Testnet;
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
      isTestnet: isTestnet,
      scriptType: scriptType,
    );
    if (sfErr != null) {
      return (null, Err('Error Getting Fingerprint'));
    }
    bdk.Descriptor? internal;
    bdk.Descriptor? external;
    final rootXpub = await rootXprv.asPublic();

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
    var wallet = Wallet(
      id: descHashId,
      externalPublicDescriptor: await external.asString(),
      internalPublicDescriptor: await internal.asString(),
      mnemonicFingerprint: seed.mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: isImported ? BBWalletType.words : BBWalletType.newSeed,
      scriptType: scriptType,
      backupTested: isImported,
    );
    wallet = wallet.copyWith(name: wallet.defaultNameString());

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

      // final appDocDir = await getApplicationDocumentsDirectory();
      // final String dbDir = appDocDir.path + '/${wallet.getWalletStorageString()}_signer';

      const dbConfig = bdk.DatabaseConfig.memory();

      final bdkWallet = await bdk.Wallet.create(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        databaseConfig: dbConfig,
      );

      return (bdkWallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
