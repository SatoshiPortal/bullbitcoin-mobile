import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
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
    String? password,
    required bool isTestnet,
    required ScriptType walletType,
  }) async {
    try {
      final network = isTestnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final mn = await bdk.Mnemonic.fromString(mnemonic);
      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        network: network,
        mnemonic: mn,
        password: password,
      );

      String fgnr;

      switch (walletType) {
        case ScriptType.bip84:
          final externalDescriptor = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalDescriptor.asString();
          fgnr = fingerPrintFromXKey(edesc);

        case ScriptType.bip44:
          final externalDescriptor = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalDescriptor.asString();
          fgnr = fingerPrintFromXKey(edesc);

        case ScriptType.bip49:
          final externalDescriptor = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalDescriptor.asString();
          fgnr = fingerPrintFromXKey(edesc);
      }

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
      final mnemonicFingerprint = fingerPrintFromXKey(rootXprv.toString());
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

  Future<(List<Wallet>?, Err?)> walletsFromBIP39(
    String mnemonic,
    String passphrase,
    BBNetwork network,
  ) async {
    final bdkMnemonic = await bdk.Mnemonic.fromString(mnemonic);
    final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
    final rootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );
    final fingerprint = fingerPrintFromXKey(rootXprv.toString());
    final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
    const accountPath = '0h';

    final bdkXpriv44 = await rootXprv.derive(
      bdk.DerivationPath.create(path: 'm/44h/$networkPath/$accountPath') as bdk.DerivationPath,
    );
    final bdkXpriv49 = await rootXprv.derive(
      bdk.DerivationPath.create(path: 'm/49h/$networkPath/$accountPath') as bdk.DerivationPath,
    );
    final bdkXpriv84 = await rootXprv.derive(
      bdk.DerivationPath.create(path: 'm/84h/$networkPath/$accountPath') as bdk.DerivationPath,
    );

    final bdkXpub44 = await bdkXpriv44.asPublic();
    final bdkXpub49 = await bdkXpriv49.asPublic();
    final bdkXpub84 = await bdkXpriv84.asPublic();

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
        createDescriptorHashId(bdkDescriptor44External.toString()).substring(0, 12);
    final wallet44 = Wallet(
      descHashId: wallet44HashId,
      externalPublicDescriptor: bdkDescriptor44External.toString(),
      internalPublicDescriptor: bdkDescriptor44Internal.toString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip44,
    );
    final wallet49HashId =
        createDescriptorHashId(bdkDescriptor49External.toString()).substring(0, 12);
    final wallet49 = Wallet(
      descHashId: wallet49HashId,
      externalPublicDescriptor: bdkDescriptor49External.toString(),
      internalPublicDescriptor: bdkDescriptor49Internal.toString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip49,
    );
    final wallet84HashId =
        createDescriptorHashId(bdkDescriptor84External.toString()).substring(0, 12);
    final wallet84 = Wallet(
      descHashId: wallet84HashId,
      externalPublicDescriptor: bdkDescriptor84External.toString(),
      internalPublicDescriptor: bdkDescriptor84Internal.toString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip84,
    );

    return ([wallet44, wallet49, wallet84], null);
  }

  Future<(Wallet?, Err?)> passphraseWalletFromSeed(
    Seed seed,
    String passphrase,
    ScriptType scriptType,
    BBNetwork network,
    bool isImported,
  ) async {
    final bdkMnemonic = await bdk.Mnemonic.fromString(seed.mnemonic);
    final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
    final rootXprv = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: bdkMnemonic,
      password: passphrase,
    );
    final sourceFingerprint = fingerPrintFromXKey(rootXprv.toString());

    bdk.Descriptor? internal;
    bdk.Descriptor? external;
    final rootXpub = await rootXprv.asPublic();

    switch (scriptType) {
      case ScriptType.bip84:
        internal = await bdk.Descriptor.newBip84Public(
          publicKey: rootXpub,
          fingerPrint: sourceFingerprint,
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
          fingerPrint: sourceFingerprint,
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
          fingerPrint: sourceFingerprint,
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

    final descHashId = createDescriptorHashId(external.toString()).substring(0, 12);
    final wallet = Wallet(
      descHashId: descHashId,
      externalPublicDescriptor: external.toString(),
      internalPublicDescriptor: internal.toString(),
      mnemonicFingerprint: seed.mnemonicFingerprint,
      sourceFingerprint: sourceFingerprint,
      network: network,
      type: isImported ? BBWalletType.words : BBWalletType.newSeed,
      scriptType: scriptType,
    );

    return (wallet, null);
  }

  Future<(List<Wallet>?, Err?)> walletsFromColdCard(
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
        createDescriptorHashId(bdkDescriptor44External.toString()).substring(0, 12);
    final wallet44 = Wallet(
      descHashId: wallet44HashId,
      externalPublicDescriptor: bdkDescriptor44External.toString(),
      internalPublicDescriptor: bdkDescriptor44Internal.toString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip44,
    );
    final (_, w44Err) = await HiveStorage().getValue(wallet44HashId);
    if (w44Err != null) {
      // wallet does not exist
    } else {
      // wallet exists, error
      return (null, Err('Wallet 44 Exists'));
    }

    final wallet49HashId =
        createDescriptorHashId(bdkDescriptor49External.toString()).substring(0, 12);
    final wallet49 = Wallet(
      descHashId: wallet49HashId,
      externalPublicDescriptor: bdkDescriptor49External.toString(),
      internalPublicDescriptor: bdkDescriptor49Internal.toString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip49,
    );
    final (_, w49Err) = await HiveStorage().getValue(wallet49HashId);
    if (w49Err != null) {
      // wallet does not exist
    } else {
      // wallet exists, error
      return (null, Err('Wallet 49 Exists'));
    }

    final wallet84HashId =
        createDescriptorHashId(bdkDescriptor84External.toString()).substring(0, 12);
    final wallet84 = Wallet(
      descHashId: wallet84HashId,
      externalPublicDescriptor: bdkDescriptor84External.toString(),
      internalPublicDescriptor: bdkDescriptor84Internal.toString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip84,
    );
    final (_, w84Err) = await HiveStorage().getValue(wallet84HashId);
    if (w84Err != null) {
      // wallet does not exist
    } else {
      // wallet exists, error
      return (null, Err('Wallet 84 Exists'));
    }

    return ([wallet44, wallet49, wallet84], null);
  }

  Future<(Wallet?, Err?)> walletFromXpub(
    String xpub,
  ) async {
    try {
      final network = (xpub.startsWith('t') || xpub.startsWith('u') || xpub.startsWith('v'))
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet;
      final bdkNetwork = (xpub.startsWith('t') || xpub.startsWith('u') || xpub.startsWith('v'))
          ? bdk.Network.Testnet
          : bdk.Network.Bitcoin;
      final scriptType = xpub.startsWith('x') || xpub.startsWith('t')
          ? ScriptType.bip44
          : xpub.startsWith('y') || xpub.startsWith('u')
              ? ScriptType.bip49
              : ScriptType.bip84;
      final xPub = convertToXpubStr(xpub);
      final rootXpub = await bdk.DescriptorPublicKey.fromString(xPub);
      print(rootXpub);
      // check if this mnemonic exists in Seed
      // if exists; then add passphrase wallet; else create new

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
            descriptor: 'sh-wsh($xPub/1/*)',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'sh-wsh($xPub/0/*)',
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

      final descHashId = createDescriptorHashId(external.toString()).substring(0, 12);
      final wallet = Wallet(
        descHashId: descHashId,
        externalPublicDescriptor: external.toString(),
        internalPublicDescriptor: internal.toString(),
        mnemonicFingerprint: descHashId,
        sourceFingerprint: descHashId,
        network: network,
        type: BBWalletType.xpub,
        scriptType: scriptType,
      );

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
  //     return (null, Err(e.toString()));
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
}
