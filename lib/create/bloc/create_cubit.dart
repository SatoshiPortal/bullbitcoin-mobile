import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/create/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateWalletCubit extends Cubit<CreateWalletState> {
  CreateWalletCubit({
    required this.settingsCubit,
    required this.walletCreate,
    required this.storage,
    required this.secureStorage,
    required this.walletUpdate,
    bool fromHome = false,
  }) : super(const CreateWalletState()) {
    createMne(fromHome: fromHome);
  }

  final SettingsCubit settingsCubit;
  final WalletCreate walletCreate;
  final IStorage storage;
  final IStorage secureStorage;
  final WalletUpdate walletUpdate;

  void createMne({bool fromHome = false}) async {
    emit(state.copyWith(creatingNmemonic: true));
    final (mne, err) = await walletCreate.createMne();
    if (err != null) {
      emit(
        state.copyWith(
          errCreatingNmemonic: err.toString(),
          creatingNmemonic: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        mnemonic: mne,
        creatingNmemonic: false,
      ),
    );

    if (fromHome) firstTime();
  }

  void passPhraseChanged(String text) {
    emit(state.copyWith(passPhase: text));
  }

  void _showSavingErr(String err) {
    emit(
      state.copyWith(
        errSaving: err,
        creatingNmemonic: false,
      ),
    );
  }

  void confirmClicked() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final (fgnr, err) = await walletCreate.getMneFingerprint(
      mne: state.mnemonic!.join(' '),
      isTestnet: settingsCubit.state.testnet,
      walletPurpose: WalletPurpose.bip84,
    );
    if (err != null) {
      _showSavingErr(err.toString());
      return;
    }

    final (wallet, err2) = Wallet.fromMnemonic(
      mne: state.mnemonic!.join(' '),
      password: state.passPhase.isNotEmpty ? state.passPhase : null,
      walletPurpose: WalletPurpose.bip84,
      bbWalletType: BBWalletType.newSeed,
      isTestNet: settingsCubit.state.testnet,
      fngr: fgnr!,
      backupTested: false,
    );
    if (err2 != null) {
      _showSavingErr(err2.toString());
      return;
    }

    final errr = await walletUpdate.addWalletToList(
      wallet: wallet!,
      storage: storage,
      secureStorage: secureStorage,
    );
    if (errr != null) {
      _showSavingErr(errr.toString());
      return;
    }

    emit(
      state.copyWith(
        saving: false,
        saved: true,
        savedWallet: wallet,
      ),
    );
  }

  void firstTime() async {
    if (state.mnemonic == null) return;
    emit(state.copyWith(saving: true, errSaving: ''));

    final isTestNet = settingsCubit.state.testnet;
    bool testnet(int i) => i != 0;
    bool selectWallet(int i) => isTestNet ? i == 1 : i == 0;

    for (var i = 0; i < 2; i++) {
      final mne = state.mnemonic!.join(' ');
      final password = state.passPhase.isNotEmpty ? state.passPhase : null;

      final (fgnr, err) = await walletCreate.getMneFingerprint(
        mne: mne,
        isTestnet: settingsCubit.state.testnet,
        walletPurpose: WalletPurpose.bip84,
        password: password,
      );
      if (err != null) {
        _showSavingErr(err.toString());
        return;
      }

      var (wallet, err2) = Wallet.fromMnemonic(
        mne: state.mnemonic!.join(' '),
        password: state.passPhase.isNotEmpty ? state.passPhase : null,
        walletPurpose: WalletPurpose.bip84,
        bbWalletType: BBWalletType.newSeed,
        isTestNet: testnet(i),
        fngr: fgnr!,
        backupTested: false,
      );
      if (err2 != null) {
        _showSavingErr(err2.toString());
        return;
      }

      final label = testnet(i) ? 'Bull Wallet Testnet' : 'Bull Wallet';

      wallet = wallet!.copyWith(name: label);

      final errr = await walletUpdate.addWalletToList(
        wallet: wallet,
        storage: storage,
        secureStorage: secureStorage,
      );
      if (errr != null) {
        _showSavingErr(errr.toString());
        return;
      }

      if (selectWallet(i)) {
        emit(state.copyWith(savedWallet: wallet));
      }
    }

    emit(
      state.copyWith(
        saving: false,
        saved: true,
      ),
    );
  }
}


// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 
// 

// 

      // final internalPath = await bdk.DerivationPath.create(path: "m/84'/1'/0'/1'");
      // final dervExternal = await descriptorSecretKey.derive(path);
      // final dervInternal = await descriptorSecretKey.derive(internalPath);
      // final dervExternalStr = dervExternal.asString();
      // final dervInternalStr = dervInternal.asString();
      // final externalDescriptor = 'wpkh($dervExternalStr)';
      // final internalDescriptor = 'wpkh($dervInternalStr)';

      // final idesc = await internalDescriptor0.asPrivateString();
//pkh(tprv8ZgxMBicQKsPdWaX11g33Aimw1mzoaQZsRSRHmVZbhNbd5TfaofeXstFv518nqm5gbmB4J9XWqsJgNoML3XzQGmQeaDVp93rxRRnyCAqUu5/44'/1'/0'/1/*)#su6lh8zz
      // final iDesc = await bdk.Descriptor.create(
      //   descriptor: internalDescriptor,
      //   network: network,
      // );

      // final eDesc = await bdk.Descriptor.create(
      //   descriptor: externalDescriptor,
      //   network: network,
      // );

// 

    // scheduleMicrotask(init());

    // final xprv = await descriptorSecretKey.asString();
      // final sec = await descriptorSecretKey.secretBytes();
      // final xpub = await descriptorSecretKey.asPublic();
      // // final xpubString = xpub.asString();
      // final derivedXprv = await descriptorSecretKey.extend(path);
      // final derivedXpub = await xpub.extend(path);
      // final derivedXprvStr = await derivedXprv.asString();
      // final derivedXpubStr = derivedXpub.asString();

      // final wallet = await Wallet.create(
      //   descriptor: 'wpkh($derivedXprvStr)',
      //   // changeDescriptor: 'wpkh($derivedXprvStr)',
      //   network: Network.Bitcoin,
      //   databaseConfig: const DatabaseConfig.memory(),
      // );

      


      // final x =

      // final privKey = await derivedKey.asString();
      // final descrPubKey = await derivedKey.asPublic();
      // final pubKey = descrPubKey.asString();
      // final fingerPrint = _fingerPrintFromDescr(pubKey);

      // final wallet = Wallet.create(descriptor: descriptor, network: network, databaseConfig: databaseConfig)

      // final wallet1 = await Wallet.create(externalDescriptor, internalDescriptor, Network.TESTNET,
      //     databaseConfig: const DatabaseConfig.memory());

// Future<Result<w.WalletDetails>> createWalletDetailsForSelection({
//   required String xpub,
//   required Descriptor descriptorType,
// }) async {
//   try {
//     final descr = await createDescriptors(
//       type: Descriptor.P2WPKH,
//       xprv: xpub,
//     );

//     final fingerPrint = _fingerPrintFromDescr(descr.descriptor);

//     final walletDetails = w.WalletDetails(
//       name: '',
//       firstAddress: '',
//       fingerPrint: fingerPrint,
//       expandedPubKey: '',
//       derivationPath: '',
//     );

//     return Result(value: walletDetails);
//   } catch (e) {
//     return Result(error: e.toString());
//   }
// }

// xpub.asString();
// xkey.
// final xkey = await bdk.createExtendedKey(
//   network: bdk.Network.BITCOIN,
//   mnemonic: mne,
//   password: pssword,
// );

// final descr = await bdk.createDescriptors(
//   type: Descriptor.P2WPKH,
//   xprv: xkey.xprv,
//   password: pssword,
// );

// final fingerPrint = _fingerPrintFromDescr(descr.descriptor);

//  "[09fccb09/84'/0'/0']xpub6DH85AKamwfkx93JoEbJC4hviainNVPKDKfiWm8cPBUFrfPfVYbq41oEgdBjkbto14RcmqGyz6WbBXWh42QFFveJv97GURhGRLpx2Pnp…"
