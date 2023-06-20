import 'dart:convert';

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWalletCubit extends Cubit<ImportState> {
  ImportWalletCubit({
    required this.barcode,
    required this.filePicker,
    required this.nfc,
    required this.settingsCubit,
    required this.walletCreate,
    required this.storage,
    required this.walletUpdate,
  }) : super(
          const ImportState(
              // words: [
              //   ...r2,
              // ],
              ),
        );

  final Barcode barcode;
  final FilePick filePicker;
  final NFCPicker nfc;

  final SettingsCubit settingsCubit;
  final WalletCreate walletCreate;
  final IStorage storage;
  final WalletUpdate walletUpdate;

  void backClicked() {
    switch (state.importStep) {
      case ImportSteps.importWords:
      case ImportSteps.selectImportType:
      case ImportSteps.importXpub:
        emit(
          state.copyWith(
            importStep: ImportSteps.selectCreateType,
            importType: ImportTypes.notSelected,
            // words: [for (int i = 0; i < 12; i++) ''],
          ),
        );

      case ImportSteps.scanningNFC:
      case ImportSteps.scanningWallets:
      case ImportSteps.selectWalletType:
        if (state.importType == ImportTypes.xpub)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        else if (state.importType == ImportTypes.words)
          emit(
            state.copyWith(
              importStep: ImportSteps.importWords,
              importType: state.importType,
            ),
          );
        else if (state.importType == ImportTypes.coldcard)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        emit(state.copyWith(errSavingWallet: ''));

        nfc.stopSession();

      default:
        break;
    }
  }

  void importClicked() {
    emit(
      state.copyWith(
        importStep: ImportSteps.importXpub,
        importType: ImportTypes.xpub,
      ),
    );
  }

  void recoverClicked() {
    emit(
      state.copyWith(
        importStep: ImportSteps.importWords,
        importType: ImportTypes.words,
      ),
    );
  }

  void scanQRClicked() async {
    emit(state.copyWith(loadingFile: true));
    final (res, err) = await barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errImporting: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    if (state.importStep == ImportSteps.importXpub) emit(state.copyWith(xpub: res!));

    emit(state.copyWith(loadingFile: false));
  }

  void wordChanged(int idx, String text) {
    final words = state.words.toList();
    words[idx] = text;
    emit(state.copyWith(words: words));
  }

  void passwordChanged(String text) {
    emit(state.copyWith(password: text));
  }

  void xpubChanged(String text) {
    emit(state.copyWith(xpub: text));
  }

  void descriptorChanged(String text) {
    emit(state.copyWith(manualDescriptor: text));
  }

  void cDescriptorChanged(String text) {
    emit(state.copyWith(manualChangeDescriptor: text));
  }

  void combinedDescriptorChanged(String text) {
    emit(state.copyWith(manualCombinedDescriptor: text));

    final desc = splitCombinedChanged(text, false);
    final cdesc = splitCombinedChanged(text, true);

    emit(state.copyWith(manualDescriptor: desc, manualChangeDescriptor: cdesc));
  }

  void fingerprintChanged(String text) {
    emit(state.copyWith(fingerprint: text));
  }

  void customDerivationChanged(String text) {
    emit(state.copyWith(customDerivation: text));
  }

  void coldCardNFCClicked() async {
    emit(
      state.copyWith(
        importStep: ImportSteps.scanningNFC,
        loadingFile: true,
        errLoadingFile: '',
      ),
    );

    final err = await nfc.startSession(coldCardNFCReceived);
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );

      final errStopping = nfc.stopSession();
      if (errStopping != null)
        emit(
          state.copyWith(
            errLoadingFile: errStopping.toString(),
            loadingFile: false,
          ),
        );
    }
  }

  void stopScanningNFC() async {
    final err = nfc.stopSession();
    if (err != null) emit(state.copyWith(errLoadingFile: err.toString()));
    emit(state.copyWith(loadingFile: false));
  }

  void coldCardNFCReceived(String jsnStr) async {
    final ccObj = jsonDecode(jsnStr) as Map<String, dynamic>;
    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      final errStoppping = nfc.stopSession();
      if (errStoppping != null)
        emit(
          state.copyWith(
            errLoadingFile: errStoppping.toString(),
            loadingFile: false,
          ),
        );
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: state.errImporting,
          loadingFile: false,
        ),
      );

      return;
    }

    emit(
      state.copyWith(
        importStep: ImportSteps.scanningWallets,
        loadingFile: false,
        importType: ImportTypes.coldcard,
      ),
    );
  }

  void coldCardFileClicked() async {
    emit(
      state.copyWith(
        loadingFile: true,
        errLoadingFile: '',
      ),
    );
    final (file, err) = await filePicker.pickFile();
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    final ccObj = jsonDecode(file!) as Map<String, dynamic>;

    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: state.errImporting,
          loadingFile: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        importStep: ImportSteps.scanningWallets,
        loadingFile: false,
        importType: ImportTypes.coldcard,
      ),
    );
  }

  void xpubSaveClicked() async {
    emit(state.copyWith(errImporting: ''));
    if (state.xpub.isEmpty) {
      emit(state.copyWith(errImporting: 'Please enter xpub'));
      return;
    }

    emit(
      state.copyWith(
        tempXpub: state.xpub,
        xpub: convertToXpubStr(state.xpub),
        importType: ImportTypes.xpub,
      ),
    );

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  void recoverWalletClicked() async {
    for (final word in state.words)
      if (word.isEmpty) {
        emit(state.copyWith(errImporting: 'Please fill all words'));
        return;
      }

    emit(state.copyWith(importType: ImportTypes.words));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  Future _updateWalletDetailsForSelection() async {
    try {
      final isTesnet = settingsCubit.state.testnet;
      final type = state.importType;

      final wallets = <Wallet>[];

      switch (type) {
        case ImportTypes.words:
          final mne = state.words.join(' ');
          final password = state.password.isEmpty ? null : state.password;
          final path = state.customDerivation.isEmpty ? null : state.customDerivation;

          final (fingerPrint, errr) = await walletCreate.getMneFingerprint(
            mne: mne,
            isTestnet: isTesnet,
            walletType: WalletType.bip84,
          );
          if (errr != null) throw errr;

          final (w, err) = Wallet.fromMnemonicAll(
            mne: mne,
            password: password,
            path: path,
            isTestNet: isTesnet,
            bbWalletType: BBWalletType.words,
            fngr: fingerPrint!,
          );

          if (err != null) throw err;
          wallets.addAll(w!);

        case ImportTypes.xpub:
          if (state.manualChangeDescriptor != null &&
              state.manualDescriptor != null &&
              state.manualChangeDescriptor!.isNotEmpty &&
              state.manualDescriptor!.isNotEmpty) {
            var fngr = fingerPrintFromDescr(
              state.manualChangeDescriptor!,
              isTesnet: isTesnet,
            );

            if (fngr.isEmpty) fngr = generateFingerPrint(6);

            final (w, err) = Wallet.fromDescrAll(
              changeDescriptor: state.manualChangeDescriptor!,
              descriptor: state.manualDescriptor!,
              isTestNet: isTesnet,
              bbWalletType: BBWalletType.descriptors,
              fngr: fngr,
            );

            if (err != null) throw err;
            wallets.addAll(w!);
          } else if (state.fingerprint.isEmpty) {
            final randFngr = generateFingerPrint(6);

            final (w, err) = Wallet.fromXpubNoPathAll(
              xpub: state.xpub,
              isTestNet: isTesnet,
              bbWalletType: BBWalletType.descriptors,
              fngr: randFngr,
            );

            if (err != null) throw err;
            wallets.addAll(w!);
          } else {
            final path = state.customDerivation;
            final fingerprint = state.fingerprint;

            final (w, err) = Wallet.fromXpubWithPathAll(
              xpub: state.xpub,
              isTestNet: isTesnet,
              bbWalletType: BBWalletType.xpub,
              fngr: fingerprint,
              path: path,
            );

            if (err != null) throw err;
            wallets.addAll(w!);
          }

        case ImportTypes.coldcard:
          final coldcard = state.coldCard!;

          final (w, err) = Wallet.fromColdCardAll(
            coldCard: coldcard,
            isTestNet: isTesnet,
          );

          if (err != null) throw err;
          wallets.addAll(w!);

        default:
          break;
      }

      if (wallets.isEmpty) throw 'Unable to create a wallet';

      emit(state.copyWith(walletDetails: wallets));
    } catch (e) {
      emit(state.copyWith(errImporting: e.toString()));
    }
  }

  void syncingComplete() {
    emit(
      state.copyWith(
        importStep: ImportSteps.selectWalletType,
      ),
    );
  }

  void walletTypeChanged(WalletType type) {
    emit(state.copyWith(walletType: type));
  }

  void saveClicked() async {
    emit(state.copyWith(savingWallet: true, errSavingWallet: ''));
    final selectedWallet = state.getSelectWalletDetails();

    final err = await walletUpdate.addWalletToList(wallet: selectedWallet!, storage: storage);

    if (err != null) {
      emit(
        state.copyWith(
          errSavingWallet: err.toString(),
          savingWallet: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        savingWallet: false,
        savedWallet: selectedWallet,
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

//
//

//
//

//
//

const r1 = [
  'trust',
  'gift',
  'fiber',
  'stove',
  'subject',
  'reject',
  'kite',
  'pride',
  'jewel',
  'expose',
  'shield',
  'cinnamon',
];

const r2 = [
  'upper',
  'suffer',
  'lab',
  'cute',
  'ostrich',
  'uniform',
  'flame',
  'team',
  'swing',
  'road',
  'tilt',
  'ugly',
];

const x = '''
1. arrive
2. term
3. same
4. weird
5. genuine
6. year
7. trash
8. autumn
9. fancy
10. need
11. olive
12. earn
''';

const cc1 = <String, dynamic>{
  'xpub':
      'xpub661MyMwAqRbcEzCZywtqgKFrkkR6ipfo1sZdeA2GX4rM6JAFkxywjvDpr6etojTXwxviZaCRBsZXuwPRiR9TL62GJftddaqEbvuqdYwoedW',
  'xfp': 'BF92D765',
  'account': 0,
  'bip49': {
    'name': 'p2sh-p2wpkh',
    'deriv': "m/49'/1'/0'",
    'xpub':
        'tpubDDUipoanutCM8mgkDtPLnJeAs9XJi3gTfunxaYijjc2MNoGW1QStBuM9gFrfxbBJoJRGcCarhoSLg2Qr3X7DV9uTQuDP5uECURNn2gg4b2f',
    'xfp': '8E2CBC58',
    'first': '2MyJ2MEMNAk6Hz8hnXfhAKrQ7b2YUNQGuv2',
    '_pub':
        'upub5EcJPZkMkZcTK5vYGd3Nx82J27zJtoCuNwdzsoywFg8pUDA7BD77BGhuNbu8SNGJnUXwkCHJniYeKz5YVa1wD1QMkHNoee7W5HbS71TgHLL'
  },
  'bip44': {
    'name': 'p2pkh',
    'deriv': "m/44'/1'/0'",
    'xpub':
        'tpubDDHphAqEiFfSfr9q6rVesL4zf1qL67c8yBTvADUFvk8Ftzvsa5LuJtkEcvC991ryxUSnFtPjd2wmQaUGEZ3t5VEGDd86aUaZXbabvG4RMum',
    'xfp': 'E81E86DD',
    'first': 'mpifJzYEbbzdD3AQkNaJieCxAmpTJLThY5'
  },
  'bip84': {
    'name': 'p2wpkh',
    'deriv': "m/84'/1'/0'",
    'xpub':
        'tpubDDVEizHCA5heDZCWQmB8B4pLApHcS4FpyVZaeqUjH6t3oy1C2JJ9MbqcewWo74JqExwjByZFUzUeUqft2kmtwvJo3iJenKcYmnzEWcMZ3ka',
    'xfp': '96714FC3',
    'first': 'tb1qn4z7da2pvwfppmkznshys0qlyusem5mfgl252a',
    '_pub':
        'vpub5ZT5bR7g9SfEFAdRHrcnYyHxVku4ZRmmbdvqjVdpBBNPxUi2Sm7vy2rWNVWqak3kdnBD5SrG2ZwW25x9CW6dU1VJFSAVvyKLePGXyUnmDST'
  },
  'bip48_2': {
    'name': 'p2wsh',
    'deriv': "m/48'/1'/0'/2'",
    'xpub':
        'tpubDFmob2uz1jLeccpK2qodwuC8EguVTRxJ1FWjH59jPy43nMXAgiH2PaHkwgJ1sBK3buCTSs1UfF9m1UV8ZPkwsQACfUG1jeFM3ms2FBa1arL',
    'xfp': 'ED958636',
    '_pub':
        'Vpub5ndjahUua3rc4oQbrbiH9t1ZHRZCoA9pwfXfGzaMfpNoZ3nusaV668AaTwFXuJGsEBVvCvJc6317ftPA2NEdXyTNhfEGHhR8p6RCHxv6j3g'
  },
  'bip45': {
    'name': 'p2sh',
    'deriv': "m/45'",
    'xpub':
        'tpubD9foCicw3JcXAM8ofSb8SRHN2h5JN3KqcQd6F6jwSo15wXfX21TfuiR1WYns1QRPLAuSkz9TZZuKuEzoJsFeWBwpgms4LjZ2VGYzWGBCV48',
    'xfp': 'A2E45A42',
    '_pub':
        'tpubD9foCicw3JcXAM8ofSb8SRHN2h5JN3KqcQd6F6jwSo15wXfX21TfuiR1WYns1QRPLAuSkz9TZZuKuEzoJsFeWBwpgms4LjZ2VGYzWGBCV48'
  },
  'chain': 'XTN',
  'bip48_1': {
    'name': 'p2sh-p2wsh',
    'deriv': "m/48'/1'/0'/1'",
    'xpub':
        'tpubDFmob2uz1jLeYY6Ksehdoqx4sZSf9DTbG46rw9LaDtXjgHo6AB1oXUXmCc2GwG9uQ1vrepAhk1J5Jm4Dwth1ahERropqBB9LXvn933LwPH1',
    'xfp': '3E272003',
    '_pub':
        'Upub5ToUH2ozRNK89RVVs3peojfzkKwvYKfdHMba9fsK7jUcPtFc6P4JbxkShf2CyUTocf7WfPsGi8nt5tLghAkgT2r12f6f9KVe2XGfhBTbQqY',
  },
};



//
//

//
//

//
  // void importTypeSelected(ImportTypes type) {
  //   switch (type) {
  //     case ImportTypes.xpub:
  //       emit(
  //         state.copyWith(
  //           importStep: ImportSteps.importXpub,
  //           importType: ImportTypes.xpub,
  //           xpub: '',
  //           errImporting: '',
  //         ),
  //       );
  //     case ImportTypes.coldcard:
  //       emit(
  //         state.copyWith(
  //           importStep: ImportSteps.importXpub,
  //           importType: ImportTypes.coldcard,

  //           // coldCardFile: '',
  //           coldCard: null,
  //           errImporting: '',
  //         ),
  //       );
  //     case ImportTypes.words:
  //       emit(
  //         state.copyWith(
  //           importStep: ImportSteps.importWords,
  //           importType: ImportTypes.words,
  //           xpub: '',
  //           errImporting: '',
  //         ),
  //       );
  //     case ImportTypes.notSelected:
  //       break;
  //   }
  // }


  // void coldCardClicked() {
  //   emit(
  //     state.copyWith(
  //       importStep: ImportSteps.selectColdCard,
  //       importType: ImportTypes.coldcard,
  //     ),
  //   );
  // }

  // void accountNumberChanged(String text) {
  //   emit(state.copyWith(accountNumber: int.tryParse(text) ?? 0));
  // }

  // void saveDerivationClicked() async {
  //   emit(state.copyWith(customDerivation: state.customDerivation));
  //   await _updateWalletDetailsForSelection();
  //   if (state.errImporting.isNotEmpty) clearDerivation();
  // }

  // void clearDerivation() {
  //   emit(state.copyWith(customDerivation: ''));
  // }

// void recoverWalletClicked() async {
//   try {
//     emit(state.copyWith(savingWallet: true));
//     final network = settingsCubit.state.getBdkNetwork();

//     final mne = await bdk.Mnemonic.fromString(state.words.join(' '));

//     final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
//       network: network,
//       mnemonic: mne,
//       password: state.password,
//     );

//     // bdk.DescriptorPublicKey();

//     final externalDescriptor = await bdk.Descriptor.newBip44(
//       secretKey: descriptorSecretKey,
//       network: bdk.Network.Testnet,
//       keychain: bdk.KeychainKind.External,
//     );

//     final internalDescriptor = await bdk.Descriptor.newBip44(
//       secretKey: descriptorSecretKey,
//       network: bdk.Network.Testnet,
//       keychain: bdk.KeychainKind.Internal,
//     );

//     final x = await bdk.Wallet.create(
//       descriptor: externalDescriptor,
//       changeDescriptor: internalDescriptor,
//       network: bdk.Network.Testnet,
//       databaseConfig: const bdk.DatabaseConfig.memory(),
//     );

//     // final path = await bdk.DerivationPath.create(path: "m/84'/1'/0'/0'");
//     // final internalPath = await bdk.DerivationPath.create(path: "m/84'/1'/0'/1'");
//     // final dervExternal = await descriptorSecretKey.derive(path);
//     // final dervInternal = await descriptorSecretKey.derive(internalPath);
//     // final dervExternalStr = dervExternal.asString();
//     // final dervInternalStr = dervInternal.asString();
//     // final externalDescriptor = 'wpkh($dervExternalStr)';
//     // final internalDescriptor = 'wpkh($dervInternalStr)';
//     // final fingerPrint = fingerPrintFromDescr(externalDescriptor);

//     // final iDesc = await bdk.Descriptor.create(
//     //   descriptor: internalDescriptor,
//     //   network: network,
//     // );

//     // final eDesc = await bdk.Descriptor.create(
//     //   descriptor: externalDescriptor,
//     //   network: network,
//     // );

//     // final appDocDir = await getApplicationDocumentsDirectory();
//     // final dbDir = appDocDir.path + '/bb_store';

//     // await bdk.Wallet.create(
//     //   descriptor: eDesc,
//     //   changeDescriptor: iDesc,
//     //   network: network,
//     //   databaseConfig: bdk.DatabaseConfig.sqlite(
//     //     config: bdk.SqliteDbConfiguration(path: dbDir),
//     //   ),
//     // );

//     // final wallet = Wallet(
//     //   fingerprint: fingerPrint,
//     //   xpub: externalDescriptor,
//     //   xpriv: internalDescriptor,
//     //   mnemonic: state.words.join(' '),
//     //   password: state.password,
//     //   network: BBNetwork.Testnet,
//     // );

//     // final saved = await walletStorage.addWalletToList(wallet);
//     // if (saved.hasError) throw saved.error!;

//     emit(
//       state.copyWith(
//         // savedWallet: wallet,
//         savingWallet: false,
//       ),
//     );
//   } catch (e) {
//     print(e);
//   }
// }

// void pickFileClicked() async {
//   emit(state.copyWith(loadingFile: true));
//   final res = await filePicker.pickColdCardFile();
//   if (res.hasError) {
//     emit(state.copyWith(
//       errImporting: res.error!,
//       loadingFile: false,
//     ));
//     return;
//   }

//   emit(state.copyWith(
//     coldCardFile: res.value!,
//     loadingFile: false,
//     importStep: ImportSteps.selectWalletType,
//   ));
//   getWalletDetailsForSelection();
// }

// void scanNFCClicked() async {
//   emit(state.copyWith(loadingFile: true));
//   nfc.startSession((coldcardFile) {
//     emit(state.copyWith(
//       importStep: ImportSteps.selectWalletType,
//       coldCardFile: coldcardFile,
//       loadingFile: false,
//     ));
//     getWalletDetailsForSelection();
//   });
// }

// void stopNFCSession() {
//   nfc.stopSession();
// }

// final descr = await createDescriptors(
//   type: bdk.Descriptor.P2WPKH,
//   xprv: xpub,
// );

// final path = await bdk.DerivationPath.create(path: "m/84'/1'/0'/0'");

// final eDesc = await bdk.Descriptor.create(
//   descriptor: xpub,
//   network: bdk.Network.Testnet,
// );

// final descriptor = await bdk.Descriptor.newBip44Public(
//   publicKey: xpub,
//   network: bdk.Network.Testnet,
//   keyChainKind: bdk.KeychainKind.External,
// );
// final d = await descriptor.asString();

// final externalDescriptor = 'wpkh($d)';

// final fingerPrint = fingerPrintFromDescr(externalDescriptor);

// final w = await bdk.Wallet.create(
//   descriptor: eDesc,
//   network: bdk.Network.Testnet,
//   databaseConfig: const bdk.DatabaseConfig.memory(),
// );
// final a = await w.getAddress(addressIndex: bdk.AddressIndex.LastUnused);
