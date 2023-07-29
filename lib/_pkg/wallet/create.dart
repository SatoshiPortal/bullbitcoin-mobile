import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class WalletCreate {
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

  Future<(bdk.Blockchain?, Err?)> createBlockChain({
    required int stopGap,
    required int timeout,
    required int retry,
    required String url,
    required bool validateDomain,
  }) async {
    try {
      final blockchain = await bdk.Blockchain.create(
        config: bdk.BlockchainConfig.electrum(
          config: bdk.ElectrumConfig(
            url: url,
            retry: retry,
            timeout: timeout,
            stopGap: stopGap,
            validateDomain: validateDomain,
          ),
        ),
      );

      return (blockchain, null);
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
        internal = await bdk.Descriptor.newBip84Public(
          publicKey: rootXpub,
          fingerPrint: sourceFingerprint!,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.Internal,
        );
        external = await bdk.Descriptor.newBip84Public(
          publicKey: rootXpub,
          fingerPrint: sourceFingerprint,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.External,
        );
      case ScriptType.bip49:
        internal = await bdk.Descriptor.newBip49Public(
          publicKey: rootXpub,
          fingerPrint: sourceFingerprint!,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.Internal,
        );
        external = await bdk.Descriptor.newBip49Public(
          publicKey: rootXpub,
          fingerPrint: sourceFingerprint,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.External,
        );
      case ScriptType.bip44:
        internal = await bdk.Descriptor.newBip44Public(
          publicKey: rootXpub,
          fingerPrint: sourceFingerprint!,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.Internal,
        );
        external = await bdk.Descriptor.newBip44Public(
          publicKey: rootXpub,
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

  Future<(List<Wallet>?, Err?)> allFromColdCard(
    ColdCard coldCard,
    BBNetwork network,
  ) async {
    // create all 3 coldcard wallets and return only the one requested
    final fingerprint = coldCard.xfp!;
    final bdkNetwork = network == BBNetwork.Mainnet ? bdk.Network.Bitcoin : bdk.Network.Testnet;
    final ColdWallet coldWallet44 = coldCard.bip44!;
    final xpub44 = coldWallet44.xpub;
    final ColdWallet coldWallet49 = coldCard.bip49!;
    final xpub49 = coldWallet49.xpub;
    final ColdWallet coldWallet84 = coldCard.bip84!;
    final xpub84 = coldWallet84.xpub;

    final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
    final accountPath = coldCard.account.toString() + 'h';

    final coldWallet44ExtendedPublic = '[$fingerprint/44h/$networkPath/$accountPath]$xpub44';
    final coldWallet49ExtendedPublic = '[$fingerprint/49h/$networkPath/$accountPath]$xpub49';
    final coldWallet84ExtendedPublic = '[$fingerprint/84h/$networkPath/$accountPath]$xpub84';

    final bdkXpub44 = await bdk.DescriptorPublicKey.fromString(coldWallet44ExtendedPublic);
    final bdkXpub49 = await bdk.DescriptorPublicKey.fromString(coldWallet49ExtendedPublic);
    final bdkXpub84 = await bdk.DescriptorPublicKey.fromString(coldWallet84ExtendedPublic);

    final bdkDescriptor44External = await bdk.Descriptor.newBip44Public(
      publicKey: bdkXpub44,
      fingerPrint: fingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    final bdkDescriptor44Internal = await bdk.Descriptor.newBip44Public(
      publicKey: bdkXpub44,
      fingerPrint: fingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );
    final bdkDescriptor49External = await bdk.Descriptor.newBip49Public(
      publicKey: bdkXpub49,
      fingerPrint: fingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    final bdkDescriptor49Internal = await bdk.Descriptor.newBip49Public(
      publicKey: bdkXpub49,
      fingerPrint: fingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );
    final bdkDescriptor84External = await bdk.Descriptor.newBip84Public(
      publicKey: bdkXpub84,
      fingerPrint: fingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.External,
    );
    final bdkDescriptor84Internal = await bdk.Descriptor.newBip84Public(
      publicKey: bdkXpub84,
      fingerPrint: fingerprint,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.Internal,
    );

    final wallet44HashId =
        createDescriptorHashId(await bdkDescriptor44External.asString()).substring(0, 12);
    var wallet44 = Wallet(
      id: wallet44HashId,
      externalPublicDescriptor: await bdkDescriptor44External.asString(),
      internalPublicDescriptor: await bdkDescriptor44Internal.asString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip44,
      backupTested: true,
    );
    wallet44 = wallet44.copyWith(name: wallet44.defaultNameString());

    final wallet49HashId =
        createDescriptorHashId(await bdkDescriptor49External.asString()).substring(0, 12);
    var wallet49 = Wallet(
      id: wallet49HashId,
      externalPublicDescriptor: await bdkDescriptor49External.asString(),
      internalPublicDescriptor: await bdkDescriptor49Internal.asString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip49,
      backupTested: true,
    );
    wallet49 = wallet49.copyWith(name: wallet49.defaultNameString());

    final wallet84HashId =
        createDescriptorHashId(await bdkDescriptor84External.asString()).substring(0, 12);
    var wallet84 = Wallet(
      id: wallet84HashId,
      externalPublicDescriptor: await bdkDescriptor84External.asString(),
      internalPublicDescriptor: await bdkDescriptor84Internal.asString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip84,
      backupTested: true,
    );
    wallet84 = wallet84.copyWith(name: wallet84.defaultNameString());

    return ([wallet44, wallet49, wallet84], null);
  }

  Future<(Wallet?, Err?)> oneFromSlip132Pub(
    String slip132Pub,
  ) async {
    try {
      final network =
          (slip132Pub.startsWith('t') || slip132Pub.startsWith('u') || slip132Pub.startsWith('v'))
              ? BBNetwork.Testnet
              : BBNetwork.Mainnet;
      final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
      final scriptType = slip132Pub.startsWith('x') || slip132Pub.startsWith('t')
          ? ScriptType.bip44
          : slip132Pub.startsWith('y') || slip132Pub.startsWith('u')
              ? ScriptType.bip49
              : ScriptType.bip84;
      final xPub = convertToXpubStr(slip132Pub);

      bdk.Descriptor? internal;
      bdk.Descriptor? external;
      switch (scriptType) {
        case ScriptType.bip84:
          internal = await bdk.Descriptor.create(
            descriptor: 'wpkh($xPub/1/*)',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'wpkh($xPub/0/*)',
            network: bdkNetwork,
          );
        case ScriptType.bip49:
          internal = await bdk.Descriptor.create(
            descriptor: 'sh(wpkh($xPub/1/*))',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'sh(wpkh($xPub/0/*))',
            network: bdkNetwork,
          );
        case ScriptType.bip44:
          internal = await bdk.Descriptor.create(
            descriptor: 'pkh($xPub/1/*)',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'pkh($xPub/0/*)',
            network: bdkNetwork,
          );
      }

      final descHashId = createDescriptorHashId(await external.asString()).substring(0, 12);
      var wallet = Wallet(
        id: descHashId,
        externalPublicDescriptor: await external.asString(),
        internalPublicDescriptor: await internal.asString(),
        mnemonicFingerprint: descHashId,
        sourceFingerprint: descHashId,
        network: network,
        type: BBWalletType.xpub,
        scriptType: scriptType,
        backupTested: true,
      );
      wallet = wallet.copyWith(name: wallet.defaultNameString());

      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  // Future<(Wallet?, Err?)> newWalletFromDescriptor(
  //   String descriptor,
  // ) async {
  //   try {

  //   } catch (e) {
  //     return (null, Err(e.asString()));
  //   }
  // }

  Future<(bdk.Wallet?, Err?)> loadPublicBdkWallet(
    Wallet wallet,
  ) async {
    try {
      final network =
          wallet.network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final external = await bdk.Descriptor.create(
        descriptor: wallet.externalPublicDescriptor,
        network: network,
      );
      final internal = await bdk.Descriptor.create(
        descriptor: wallet.internalPublicDescriptor,
        network: network,
      );

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir = appDocDir.path + '/${wallet.getWalletStorageString()}';

      final dbConfig = bdk.DatabaseConfig.sqlite(
        config: bdk.SqliteDbConfiguration(path: dbDir),
      );

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

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir = appDocDir.path + '/${wallet.getWalletStorageString()}';

      final dbConfig = bdk.DatabaseConfig.sqlite(
        config: bdk.SqliteDbConfiguration(path: dbDir),
      );

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
