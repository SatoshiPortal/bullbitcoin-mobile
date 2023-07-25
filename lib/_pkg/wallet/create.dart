import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class WalletCreate {
  Future<(List<String>?, Err?)> createMne() async {
    try {
      final mne = await bdk.Mnemonic.create(bdk.WordCount.Words12);
      final mneList = mne.asString().split(' ');

      return (mneList, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(String?, Err?)> getMneFingerprint({
    required String mne,
    required bool isTestnet,
    String? password,
    required ScriptType scriptType,
  }) async {
    try {
      final network = isTestnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;

      final mn = await bdk.Mnemonic.fromString(mne);
      final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
        network: network,
        mnemonic: mn,
        password: password,
      );

      String fgnr;

      switch (scriptType) {
        case ScriptType.bip84:
          final externalPublicDescriptor = await bdk.Descriptor.newBip84(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalPublicDescriptor.asString();
          fgnr = fingerPrintFromDescr(edesc, isTesnet: isTestnet);

        case ScriptType.bip44:
          final externalPublicDescriptor = await bdk.Descriptor.newBip44(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalPublicDescriptor.asString();
          fgnr = fingerPrintFromDescr(edesc, isTesnet: isTestnet);

        case ScriptType.bip49:
          final externalPublicDescriptor = await bdk.Descriptor.newBip49(
            secretKey: descriptorSecretKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
          final edesc = await externalPublicDescriptor.asString();
          fgnr = fingerPrintFromDescr(edesc, isTesnet: isTestnet);
      }

      return (fgnr, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<((Wallet, bdk.Wallet)?, Err?)> loadBdkWallet(
    Wallet wallet, {
    bool fromStorage = true,
    bool onlyPublic = false,
  }) async {
    try {
      final network =
          wallet.network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
      final scriptType = wallet.scriptType;

      bdk.Descriptor? internal;
      bdk.Descriptor? external;

      switch (wallet.type) {
        case BBWalletType.words:
        case BBWalletType.newSeed:
          final (descriptors, err) = await _buildDescriptorsForMnemonic(
            wallet: wallet,
            onlyPublic: onlyPublic,
          );

          if (err != null) throw err;

          internal = descriptors!.internal;
          external = descriptors.external;

        case BBWalletType.coldcard:
          final fngr = wallet.mnemonicFingerprint;
          final pubKey = await bdk.DescriptorPublicKey.fromString(wallet.xpub!);
          switch (scriptType) {
            case ScriptType.bip84:
              internal = await bdk.Descriptor.newBip84Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip84Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case ScriptType.bip49:
              internal = await bdk.Descriptor.newBip49Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip49Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case ScriptType.bip44:
              internal = await bdk.Descriptor.newBip44Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip44Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
          }
        case BBWalletType.xpub:
          // final fngr = fingerPrintFromDescr(
          //   eternalDescr,
          //   isTesnet: isTestNet,
          //   ignorePrefix: true,
          // );
          // final key = keyFromDescr(eternalDescr);

          final fngr = wallet.mnemonicFingerprint;

          var pubKey = await bdk.DescriptorPublicKey.fromString(wallet.xpub!);

          // final internalPublicDescriptor =
          //     await bdk.DescriptorPublicKey.fromString(wallet.internalPublicDescriptor);

          if (wallet.path != null) {
            final derivation = await bdk.DerivationPath.create(path: wallet.path!);
            pubKey = await pubKey.derive(derivation);
          }

          switch (scriptType) {
            case ScriptType.bip84:
              internal = await bdk.Descriptor.newBip84Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip84Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case ScriptType.bip49:
              internal = await bdk.Descriptor.newBip49Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip49Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
            case ScriptType.bip44:
              internal = await bdk.Descriptor.newBip44Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.Internal,
              );

              external = await bdk.Descriptor.newBip44Public(
                fingerPrint: fngr,
                publicKey: pubKey,
                network: network,
                keychain: bdk.KeychainKind.External,
              );
          }
        case BBWalletType.descriptors:
          external = await bdk.Descriptor.create(
            descriptor: wallet.externalPublicDescriptor,
            network: network,
          );
          internal = await bdk.Descriptor.create(
            descriptor: wallet.internalPublicDescriptor,
            network: network,
          );
      }

      bdk.DatabaseConfig dbConfig;
      if (!fromStorage || !onlyPublic)
        dbConfig = const bdk.DatabaseConfig.memory();
      else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbDir = appDocDir.path + '/${wallet.getStorageString()}';

        dbConfig = bdk.DatabaseConfig.sqlite(
          config: bdk.SqliteDbConfiguration(path: dbDir),
        );
      }

      final bdkWallet = await bdk.Wallet.create(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        databaseConfig: dbConfig,
      );

      return ((wallet, bdkWallet), null);
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

  Future<(({bdk.Descriptor internal, bdk.Descriptor external})?, Err?)>
      _buildDescriptorsForMnemonic({
    required Wallet wallet,
    required bool onlyPublic,
  }) async {
    try {
      final network =
          wallet.network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
      final isTestnet = wallet.network == BBNetwork.Testnet;
      final testnetPath = isTestnet ? '1' : '0';
      final scriptType = wallet.scriptType;

      final mnemo = await bdk.Mnemonic.fromString(wallet.mnemonic);

      var descriptor = await bdk.DescriptorSecretKey.create(
        network: network,
        mnemonic: mnemo,
        password: wallet.password,
      );

      if (wallet.path != null) {
        final derivation = await bdk.DerivationPath.create(path: wallet.path!);
        descriptor = await descriptor.derive(derivation);
      }

      bdk.Descriptor? internal;
      bdk.Descriptor? external;

      if (!onlyPublic) {
        switch (scriptType) {
          case ScriptType.bip84:
            internal = await bdk.Descriptor.newBip84(
              secretKey: descriptor,
              network: network,
              keychain: bdk.KeychainKind.Internal,
            );
            external = await bdk.Descriptor.newBip84(
              secretKey: descriptor,
              network: network,
              keychain: bdk.KeychainKind.External,
            );
          case ScriptType.bip49:
            internal = await bdk.Descriptor.newBip49(
              secretKey: descriptor,
              network: network,
              keychain: bdk.KeychainKind.Internal,
            );
            external = await bdk.Descriptor.newBip49(
              secretKey: descriptor,
              network: network,
              keychain: bdk.KeychainKind.External,
            );
          case ScriptType.bip44:
            internal = await bdk.Descriptor.newBip44(
              secretKey: descriptor,
              network: network,
              keychain: bdk.KeychainKind.Internal,
            );
            external = await bdk.Descriptor.newBip44(
              secretKey: descriptor,
              network: network,
              keychain: bdk.KeychainKind.External,
            );
        }

        return ((internal: internal, external: external), null);
      }

      var (fngr, err) = await getMneFingerprint(
        mne: wallet.mnemonic,
        isTestnet: isTestnet,
        scriptType: scriptType,
      );
      if (err != null) throw err;

      fngr = removeFngrPrefix(fngr!);

      switch (scriptType) {
        case ScriptType.bip84:
          final desc = await descriptor.derive(
            await bdk.DerivationPath.create(
              path: "m/84'/$testnetPath'/0'",
            ),
          );
          final pubKey = await desc.asPublic();

          internal = await bdk.Descriptor.newBip84Public(
            fingerPrint: fngr,
            publicKey: pubKey,
            network: network,
            keychain: bdk.KeychainKind.Internal,
          );

          external = await bdk.Descriptor.newBip84Public(
            fingerPrint: fngr,
            publicKey: pubKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
        case ScriptType.bip49:
          final desc = await descriptor.derive(
            await bdk.DerivationPath.create(
              path: "m/49'/$testnetPath'/0'",
            ),
          );
          final pubKey = await desc.asPublic();
          internal = await bdk.Descriptor.newBip49Public(
            fingerPrint: fngr,
            publicKey: pubKey,
            network: network,
            keychain: bdk.KeychainKind.Internal,
          );

          external = await bdk.Descriptor.newBip49Public(
            fingerPrint: fngr,
            publicKey: pubKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
        case ScriptType.bip44:
          final desc = await descriptor.derive(
            await bdk.DerivationPath.create(
              path: "m/44'/$testnetPath'/0'",
            ),
          );
          final pubKey = await desc.asPublic();

          internal = await bdk.Descriptor.newBip44Public(
            fingerPrint: fngr,
            publicKey: pubKey,
            network: network,
            keychain: bdk.KeychainKind.Internal,
          );

          external = await bdk.Descriptor.newBip44Public(
            fingerPrint: fngr,
            publicKey: pubKey,
            network: network,
            keychain: bdk.KeychainKind.External,
          );
      }

      return ((internal: internal, external: external), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
