// ignore_for_file: unused_local_variable

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:lwk_dart/lwk_dart.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class WalletCreate {
  Set<({String id, bdk.Wallet wallet})> bdkWallets = {};
  Set<({String id, lwk.Wallet wallet})> lwkWallets = {};

  (bdk.Wallet?, Err?) getBdkWallet(Wallet wallet) {
    for (final bdkWallet in bdkWallets)
      if (bdkWallet.id == wallet.id) return (bdkWallet.wallet, null);

    return (null, Err('Wallet not found'));
  }

  (lwk.Wallet?, Err?) getLwkWallet(Wallet wallet) {
    for (final lwkWallet in lwkWallets)
      if (lwkWallet.id == wallet.id) return (lwkWallet.wallet, null);

    return (null, Err('Wallet not found'));
  }

  Err? setLwkWallet(Wallet wallet, lwk.Wallet lwkWallet) {
    final added = lwkWallets.add((id: wallet.id, wallet: lwkWallet));
    if (!added) return Err('Wallet already exists');
    return null;
  }

  Err? setBdkWallet(Wallet wallet, bdk.Wallet bdkWallet) {
    final added = bdkWallets.add((id: wallet.id, wallet: bdkWallet));
    if (!added) return Err('Wallet already exists');
    return null;
  }

  Err? removeLwkWallet(Wallet wallet) {
    final exits = lwkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    lwkWallets.removeWhere((element) => element.id == wallet.id);
    return null;
  }

  Err? removeBdkWallet(Wallet wallet) {
    final exits = bdkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    bdkWallets.removeWhere((element) => element.id == wallet.id);
    return null;
  }

  Err? replaceBdkWallet(Wallet wallet, bdk.Wallet bdkWallet) {
    final exits = bdkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    bdkWallets.removeWhere((element) => element.id == wallet.id);
    bdkWallets.add((id: wallet.id, wallet: bdkWallet));
    return null;
  }

  Err? replaceLwkWallet(Wallet wallet, lwk.Wallet lwkWallet) {
    final exits = lwkWallets.any((element) => element.id == wallet.id);
    if (!exits) return Err('Wallet does not exist');
    lwkWallets.removeWhere((element) => element.id == wallet.id);
    lwkWallets.add((id: wallet.id, wallet: lwkWallet));
    return null;
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
      baseWalletType: BaseWalletType.Bitcoin,
    );
    final errBdk44 = await loadPublicBdkWallet(wallet44);
    if (errBdk44 != null) return (null, errBdk44);
    final (bdkWallet44, errLoading) = getBdkWallet(wallet44);
    if (errLoading != null) return (null, errLoading);
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
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip49,
      backupTested: true,
      baseWalletType: BaseWalletType.Bitcoin,
    );
    final errBdk49 = await loadPublicBdkWallet(wallet49);
    if (errBdk49 != null) return (null, errBdk49);
    final (bdkWallet49, errLoading49) = getBdkWallet(wallet49);
    if (errLoading49 != null) return (null, errLoading49);
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
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip84,
      backupTested: true,
      baseWalletType: BaseWalletType.Bitcoin,
    );
    final errBdk84 = await loadPublicBdkWallet(wallet84);
    if (errBdk84 != null) return (null, errBdk84);
    final (bdkWallet84, errLoading84) = getBdkWallet(wallet84);
    if (errLoading84 != null) return (null, errLoading84);
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

    removeBdkWallet(wallet44);
    removeBdkWallet(wallet49);
    removeBdkWallet(wallet84);

    if (firstAddress44.address == coldWallet44.first &&
        firstAddress49.address == coldWallet49.first &&
        firstAddress84.address == coldWallet84.first)
      return ([wallet44, wallet49, wallet84], null);
    else
      return (
        null,
        Err('First Addresses Did Not Match!'),
      );
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
        mnemonicFingerprint: 'Unknown',
        sourceFingerprint: 'Unknown',
        network: network,
        type: BBWalletType.xpub,
        scriptType: scriptType,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );
      final errBdk = await loadPublicBdkWallet(wallet);
      if (errBdk != null) return (null, errBdk);
      final (bdkWallet, errLoading) = getBdkWallet(wallet);
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

      wallet = wallet.copyWith(name: wallet.defaultNameString());

      removeBdkWallet(wallet);

      return (wallet, null);
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

  Future<(Wallet?, Err?)> oneFromXpubWithOrigin(
    String xpubWithOrigin,
  ) async {
    try {
      final network = (xpubWithOrigin.contains('tpub')) ? BBNetwork.Testnet : BBNetwork.Mainnet;
      final bdkNetwork = network == BBNetwork.Testnet ? bdk.Network.Testnet : bdk.Network.Bitcoin;
      final scriptType = xpubWithOrigin.contains('/44')
          ? ScriptType.bip44
          : xpubWithOrigin.contains('/49')
              ? ScriptType.bip49
              : ScriptType.bip84;
      bdk.Descriptor? internal;
      bdk.Descriptor? external;
      switch (scriptType) {
        case ScriptType.bip84:
          internal = await bdk.Descriptor.create(
            descriptor: 'wpkh($xpubWithOrigin/1/*)',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'wpkh($xpubWithOrigin/0/*)',
            network: bdkNetwork,
          );
        case ScriptType.bip49:
          internal = await bdk.Descriptor.create(
            descriptor: 'sh(wpkh($xpubWithOrigin/1/*))',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'sh(wpkh($xpubWithOrigin/0/*))',
            network: bdkNetwork,
          );
        case ScriptType.bip44:
          internal = await bdk.Descriptor.create(
            descriptor: 'pkh($xpubWithOrigin/1/*)',
            network: bdkNetwork,
          );
          external = await bdk.Descriptor.create(
            descriptor: 'pkh($xpubWithOrigin/0/*)',
            network: bdkNetwork,
          );
      }

      final descHashId = createDescriptorHashId(await external.asString()).substring(0, 12);
      var wallet = Wallet(
        id: descHashId,
        externalPublicDescriptor: await external.asString(),
        internalPublicDescriptor: await internal.asString(),
        mnemonicFingerprint: fingerPrintFromXKeyDesc(xpubWithOrigin),
        sourceFingerprint: fingerPrintFromXKeyDesc(xpubWithOrigin),
        network: network,
        type: BBWalletType.xpub,
        scriptType: scriptType,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );
      final errBdk = await loadPublicBdkWallet(wallet);
      if (errBdk != null) return (null, errBdk);
      final (bdkWallet, errLoading) = getBdkWallet(wallet);
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

  Future<Err?> loadPublicBdkWallet(
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

      final err = setBdkWallet(wallet, bdkWallet);
      if (err != null) return err;

      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while creating wallet',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> loadPublicLwkWallet(Wallet wallet) async {
    try {
      final network =
          wallet.network == BBNetwork.LMainnet ? lwk.Network.Mainnet : lwk.Network.Testnet;

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir = '${appDocDir.path}/db';

      final w = await lwk.Wallet.create(
        network: network,
        dbPath: dbDir,
        descriptor: wallet.externalPublicDescriptor,
      );

      final err = setLwkWallet(wallet, w);
      if (err != null) return err;

      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while creating wallet',
        solution: 'Please try again.',
      );
    }
  }
}

// i "wpkh([2e9795fd/84'/1'/0']tpubDCHrHCLCpsLQLL7nbAaKM5WCZNy1uXwJoFin6xm2vHH8rgwUnErx7qQftrm2ayxALfLTgv8EvoJ2FL1pppBVyt1ciEtF8rbUngA…"

// e "wpkh([2e9795fd/84'/1'/0']tpubDCHrHCLCpsLQLL7nbAaKM5WCZNy1uXwJoFin6xm2vHH8rgwUnErx7qQftrm2ayxALfLTgv8EvoJ2FL1pppBVyt1ciEtF8rbUngA…"
