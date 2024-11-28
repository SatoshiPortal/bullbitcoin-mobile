import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BDKCreate {
  BDKCreate({required WalletsRepository walletsRepository})
      : _walletsRepository = walletsRepository;

  final WalletsRepository _walletsRepository;

  Future<(bdk.Wallet?, Err?)> loadPublicBdkWallet(
    Wallet wallet,
  ) async {
    try {
      final network = wallet.network == BBNetwork.Testnet
          ? bdk.Network.testnet
          : bdk.Network.bitcoin;

      final external = await bdk.Descriptor.create(
        descriptor: wallet.externalPublicDescriptor,
        network: network,
      );
      final internal = await bdk.Descriptor.create(
        descriptor: wallet.internalPublicDescriptor,
        network: network,
      );

      final appDocDir = await getApplicationDocumentsDirectory();
      final String dbDir =
          appDocDir.path + '/${wallet.getWalletStorageString()}';

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

  Future<(List<Wallet>?, Err?)> allFromColdCard(
    ColdCard coldCard,
    BBNetwork network, {
    bool checkFirstAddress = true,
  }) async {
    // create all 3 coldcard wallets and return only the one requested
    final fingerprint = coldCard.xfp!;
    final bdkNetwork = network == BBNetwork.Mainnet
        ? bdk.Network.bitcoin
        : bdk.Network.testnet;
    final ColdWallet coldWallet44 = coldCard.bip44!;
    final xpub44 = coldWallet44.xpub;
    final ColdWallet coldWallet49 = coldCard.bip49!;
    final xpub49 = coldWallet49.xpub;
    final ColdWallet coldWallet84 = coldCard.bip84!;
    final xpub84 = coldWallet84.xpub;

    final networkPath = network == BBNetwork.Mainnet ? '0h' : '1h';
    final accountPath = coldCard.account.toString() + 'h';

    final coldWallet44ExtendedPublic =
        '[$fingerprint/44h/$networkPath/$accountPath]$xpub44';
    final coldWallet49ExtendedPublic =
        '[$fingerprint/49h/$networkPath/$accountPath]$xpub49';
    final coldWallet84ExtendedPublic =
        '[$fingerprint/84h/$networkPath/$accountPath]$xpub84';

    final bdkDescriptor44External = await bdk.Descriptor.create(
      descriptor: 'pkh($coldWallet44ExtendedPublic/0/*)',
      network: bdkNetwork,
    );
    final bdkDescriptor44Internal = await bdk.Descriptor.create(
      descriptor: 'pkh($coldWallet44ExtendedPublic/1/*)',
      network: bdkNetwork,
    );
    final bdkDescriptor49External = await bdk.Descriptor.create(
      descriptor: 'sh(wpkh($coldWallet49ExtendedPublic/0/*))',
      network: bdkNetwork,
    );
    final bdkDescriptor49Internal = await bdk.Descriptor.create(
      descriptor: 'sh(wpkh($coldWallet49ExtendedPublic/1/*))',
      network: bdkNetwork,
    );
    final bdkDescriptor84External = await bdk.Descriptor.create(
      descriptor: 'wpkh($coldWallet84ExtendedPublic/0/*)',
      network: bdkNetwork,
    );
    final bdkDescriptor84Internal = await bdk.Descriptor.create(
      descriptor: 'wpkh($coldWallet84ExtendedPublic/1/*)',
      network: bdkNetwork,
    );

    final wallet44HashId =
        createDescriptorHashId(bdkDescriptor44External.asString())
            .substring(0, 12);
    var wallet44 = Wallet(
      id: wallet44HashId,
      externalPublicDescriptor: bdkDescriptor44External.asString(),
      internalPublicDescriptor: bdkDescriptor44Internal.asString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip44,
      backupTested: true,
      baseWalletType: BaseWalletType.Bitcoin,
    );
    final (bdkWallet44, errBdk44) = await loadPublicBdkWallet(wallet44);
    if (errBdk44 != null) return (null, errBdk44);
    // final (bdkWallet44, errLoading) = _walletsRepository.getBdkWallet(wallet44);
    // if (errLoading != null) return (null, errLoading);
    final firstAddress44 = bdkWallet44!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet44 = wallet44.copyWith(
      name: wallet44.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress44.address.asString(),
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );

    final wallet49HashId =
        createDescriptorHashId(bdkDescriptor49External.asString())
            .substring(0, 12);
    var wallet49 = Wallet(
      id: wallet49HashId,
      externalPublicDescriptor: bdkDescriptor49External.asString(),
      internalPublicDescriptor: bdkDescriptor49Internal.asString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip49,
      backupTested: true,
      baseWalletType: BaseWalletType.Bitcoin,
    );
    final (bdkWallet49, errBdk49) = await loadPublicBdkWallet(wallet49);
    if (errBdk49 != null) return (null, errBdk49);
    // final (bdkWallet49, errLoading49) = _walletsRepository.getBdkWallet(wallet49);
    // if (errLoading49 != null) return (null, errLoading49);
    final firstAddress49 = bdkWallet49!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet49 = wallet49.copyWith(
      name: wallet49.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress49.address.asString(),
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );

    final wallet84HashId =
        createDescriptorHashId(bdkDescriptor84External.asString())
            .substring(0, 12);
    var wallet84 = Wallet(
      id: wallet84HashId,
      externalPublicDescriptor: bdkDescriptor84External.asString(),
      internalPublicDescriptor: bdkDescriptor84Internal.asString(),
      mnemonicFingerprint: fingerprint,
      sourceFingerprint: fingerprint,
      network: network,
      type: BBWalletType.coldcard,
      scriptType: ScriptType.bip84,
      backupTested: true,
      baseWalletType: BaseWalletType.Bitcoin,
    );
    final (bdkWallet84, errBdk84) = await loadPublicBdkWallet(wallet84);
    if (errBdk84 != null) return (null, errBdk84);
    // final (bdkWallet84, errLoading84) = _walletsRepository.getBdkWallet(wallet84);
    // if (errLoading84 != null) return (null, errLoading84);
    final firstAddress84 = bdkWallet84!.getAddress(
      addressIndex: const bdk.AddressIndex.peek(index: 0),
    );
    wallet84 = wallet84.copyWith(
      name: wallet84.defaultNameString(),
      lastGeneratedAddress: Address(
        address: firstAddress84.address.asString(),
        index: 0,
        kind: AddressKind.deposit,
        state: AddressStatus.unused,
      ),
    );

    _walletsRepository.removeBdkWallet(wallet44.id);
    _walletsRepository.removeBdkWallet(wallet49.id);
    _walletsRepository.removeBdkWallet(wallet84.id);

    if (checkFirstAddress) {
      if (firstAddress44.address.toString() == coldWallet44.first &&
          firstAddress49.address.toString() == coldWallet49.first &&
          firstAddress84.address.toString() == coldWallet84.first) {
        return ([wallet44, wallet49, wallet84], null);
      } else {
        return (
          null,
          Err('First Addresses Did Not Match!'),
        );
      }
    }

    return ([wallet44, wallet49, wallet84], null);
  }

  Future<(Wallet?, Err?)> oneFromSlip132Pub(
    String slip132Pub,
  ) async {
    try {
      final network = (slip132Pub.startsWith('t') ||
              slip132Pub.startsWith('u') ||
              slip132Pub.startsWith('v'))
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet;
      final bdkNetwork = network == BBNetwork.Testnet
          ? bdk.Network.testnet
          : bdk.Network.bitcoin;
      final scriptType =
          slip132Pub.startsWith('x') || slip132Pub.startsWith('t')
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

      final descHashId =
          createDescriptorHashId(external.asString()).substring(0, 12);
      var wallet = Wallet(
        id: descHashId,
        externalPublicDescriptor: external.asString(),
        internalPublicDescriptor: internal.asString(),
        mnemonicFingerprint: 'Unknown',
        sourceFingerprint: 'Unknown',
        network: network,
        type: BBWalletType.xpub,
        scriptType: scriptType,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );
      final (bdkWallet, errBdk) = await loadPublicBdkWallet(wallet);
      if (errBdk != null) return (null, errBdk);
      // final (bdkWallet, errLoading) = _walletsRepository.getBdkWallet(wallet);
      final firstAddress = bdkWallet!.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );
      wallet = wallet.copyWith(
        name: wallet.defaultNameString(),
        lastGeneratedAddress: Address(
          address: firstAddress.address.asString(),
          index: 0,
          kind: AddressKind.deposit,
          state: AddressStatus.unused,
        ),
      );

      wallet = wallet.copyWith(name: wallet.defaultNameString());

      _walletsRepository.removeBdkWallet(wallet.id);

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

  Future<(List<Wallet>?, Err?)> allFromMasterXpub(
    String xpub,
  ) async {
    try {
      if (!xpub.startsWith('x')) return (null, Err('Invalid - only for xpub'));
      final network =
          (xpub.startsWith('t') || xpub.startsWith('u') || xpub.startsWith('v'))
              ? BBNetwork.Testnet
              : BBNetwork.Mainnet;
      final bdkNetwork = network == BBNetwork.Testnet
          ? bdk.Network.testnet
          : bdk.Network.bitcoin;

      // final scriptType = xpub.startsWith('x') || xpub.startsWith('t')
      //     ? ScriptType.bip44
      //     : xpub.startsWith('y') || xpub.startsWith('u')
      //         ? ScriptType.bip49
      //         : ScriptType.bip84;
      // final xPub = convertToXpubStr(xpub);

      final internal84 = await bdk.Descriptor.create(
        descriptor: 'wpkh($xpub/1/*)',
        network: bdkNetwork,
      );
      final external84 = await bdk.Descriptor.create(
        descriptor: 'wpkh($xpub/0/*)',
        network: bdkNetwork,
      );
      final internal49 = await bdk.Descriptor.create(
        descriptor: 'sh(wpkh($xpub/1/*))',
        network: bdkNetwork,
      );
      final external49 = await bdk.Descriptor.create(
        descriptor: 'sh(wpkh($xpub/0/*))',
        network: bdkNetwork,
      );
      final internal44 = await bdk.Descriptor.create(
        descriptor: 'pkh($xpub/1/*)',
        network: bdkNetwork,
      );
      final external44 = await bdk.Descriptor.create(
        descriptor: 'pkh($xpub/0/*)',
        network: bdkNetwork,
      );

      final wallet84 = Wallet(
        id: createDescriptorHashId(external84.asString()).substring(0, 12),
        externalPublicDescriptor: external84.asString(),
        internalPublicDescriptor: internal84.asString(),
        mnemonicFingerprint: 'Unknown',
        sourceFingerprint: 'Unknown',
        network: network,
        type: BBWalletType.xpub,
        scriptType: ScriptType.bip84,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );

      final wallet49 = Wallet(
        id: createDescriptorHashId(external49.asString()).substring(0, 12),
        externalPublicDescriptor: external49.asString(),
        internalPublicDescriptor: internal49.asString(),
        mnemonicFingerprint: 'Unknown',
        sourceFingerprint: 'Unknown',
        network: network,
        type: BBWalletType.xpub,
        scriptType: ScriptType.bip49,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );

      final wallet44 = Wallet(
        id: createDescriptorHashId(external44.asString()).substring(0, 12),
        externalPublicDescriptor: external44.asString(),
        internalPublicDescriptor: internal44.asString(),
        mnemonicFingerprint: 'Unknown',
        sourceFingerprint: 'Unknown',
        network: network,
        type: BBWalletType.xpub,
        scriptType: ScriptType.bip44,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );

      return ([wallet84, wallet49, wallet44], null);
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
      final network = (xpubWithOrigin.contains('tpub'))
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet;
      final bdkNetwork = network == BBNetwork.Testnet
          ? bdk.Network.testnet
          : bdk.Network.bitcoin;
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

      final descHashId =
          createDescriptorHashId(external.asString()).substring(0, 12);
      var wallet = Wallet(
        id: descHashId,
        externalPublicDescriptor: external.asString(),
        internalPublicDescriptor: internal.asString(),
        mnemonicFingerprint: fingerPrintFromXKeyDesc(xpubWithOrigin),
        sourceFingerprint: fingerPrintFromXKeyDesc(xpubWithOrigin),
        network: network,
        type: BBWalletType.xpub,
        scriptType: scriptType,
        backupTested: true,
        baseWalletType: BaseWalletType.Bitcoin,
      );
      final (bdkWallet, errBdk) = await loadPublicBdkWallet(wallet);
      if (errBdk != null) return (null, errBdk);
      // final (bdkWallet, errLoading) = _walletsRepository.getBdkWallet(wallet);
      final firstAddress = bdkWallet!.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );
      wallet = wallet.copyWith(
        name: wallet.defaultNameString(),
        lastGeneratedAddress: Address(
          address: firstAddress.address.asString(),
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
}
