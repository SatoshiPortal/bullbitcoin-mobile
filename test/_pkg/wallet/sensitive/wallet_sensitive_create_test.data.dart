// import 'package:bb_mobile/_model/address.dart';
// import 'package:bb_mobile/_model/seed.dart';
// import 'package:bb_mobile/_model/wallet.dart';

// Wallet getTestWallet(BBNetwork network, ScriptType script, bool hasImported) {
//   if (network == BBNetwork.Mainnet) {
//     switch (script) {
//       case ScriptType.bip44:
//         return Wallet(
//           mnemonicFingerprint: '22877153',
//           sourceFingerprint: '6c0c85c3',
//           network: network,
//           type: hasImported ? BBWalletType.words : BBWalletType.secure,
//           scriptType: ScriptType.bip44,
//           id: 'f49628b4ae40',
//           name: (hasImported ? 'Imported' : 'Bull Wallet') + ':f4962',
//           externalPublicDescriptor:
//               "pkh([6c0c85c3/44'/0'/0']xpub6CdTxS9hkGFWsSy57mgbp3fQkmLisRK1pf5dseeV7JQCdUdi8UbtNF2yrJnhbxXi4eJnegdPALozoW4amYC4ptzhNUxdrCBcXMFGJjmoM7K/0/*)#s99xw55y",
//           internalPublicDescriptor:
//               "pkh([6c0c85c3/44'/0'/0']xpub6CdTxS9hkGFWsSy57mgbp3fQkmLisRK1pf5dseeV7JQCdUdi8UbtNF2yrJnhbxXi4eJnegdPALozoW4amYC4ptzhNUxdrCBcXMFGJjmoM7K/1/*)#p3q8npyu",
//           lastGeneratedAddress: Address(
//             address: '1DFudRKDPp2qHFYJCsu2Ejoh19T2SfEWit',
//             kind: AddressKind.deposit,
//             state: AddressStatus.unused,
//             index: 0,
//           ),
//           myAddressBook: [],
//           transactions: [],
//           unsignedTxs: [],
//           backupTested: hasImported,
//           baseWalletType: BaseWalletType.Bitcoin,
//         );
//       case ScriptType.bip49:
//         return Wallet(
//           mnemonicFingerprint: '22877153',
//           sourceFingerprint: '6c0c85c3',
//           network: network,
//           type: hasImported ? BBWalletType.words : BBWalletType.secure,
//           scriptType: ScriptType.bip49,
//           id: '535edc36b619',
//           name: (hasImported ? 'Imported' : 'Bull Wallet') + ':535ed',
//           externalPublicDescriptor:
//               "sh(wpkh([6c0c85c3/49'/0'/0']xpub6C8vdW3b4hxKSRYLruzUkznKxv728cFcMtMw43eMHmMoGeEMFJPWNvdKx58T3UiEd8ge24uBhNvo11RT7Aq2YR489PGndic6d37nqk2Vt8K/0/*))#j72xjquc",
//           internalPublicDescriptor:
//               "sh(wpkh([6c0c85c3/49'/0'/0']xpub6C8vdW3b4hxKSRYLruzUkznKxv728cFcMtMw43eMHmMoGeEMFJPWNvdKx58T3UiEd8ge24uBhNvo11RT7Aq2YR489PGndic6d37nqk2Vt8K/1/*))#8lys2lf8",
//           lastGeneratedAddress: Address(
//             address: '3Nty9z8679YteppwUVr3ktEsPLpq15pgB9',
//             kind: AddressKind.deposit,
//             state: AddressStatus.unused,
//             index: 0,
//           ),
//           myAddressBook: [],
//           transactions: [],
//           unsignedTxs: [],
//           backupTested: hasImported,
//         );
//       case ScriptType.bip84:
//         return Wallet(
//           mnemonicFingerprint: '22877153',
//           sourceFingerprint: '6c0c85c3',
//           network: network,
//           type: hasImported ? BBWalletType.words : BBWalletType.secure,
//           scriptType: ScriptType.bip84,
//           id: '954809e0f91d',
//           name: (hasImported ? 'Imported' : 'Bull Wallet') + ':95480',
//           externalPublicDescriptor:
//               "wpkh([6c0c85c3/84'/0'/0']xpub6BoF4Wq21oRMifVTdctqFZLoanJvW9c71p3PxTgkcAev8mJ6ug16RsRwuanXuTHNSRNozTfjiPZGCUXshmywemxXdWgCMKXCxtmtfyMxXuf/0/*)#xgf956u8",
//           internalPublicDescriptor:
//               "wpkh([6c0c85c3/84'/0'/0']xpub6BoF4Wq21oRMifVTdctqFZLoanJvW9c71p3PxTgkcAev8mJ6ug16RsRwuanXuTHNSRNozTfjiPZGCUXshmywemxXdWgCMKXCxtmtfyMxXuf/1/*)#huvyf0vl",
//           lastGeneratedAddress: Address(
//             address: 'bc1q7s3j49nm25p5sqsq9wezzrpfy4wtzcn68kt72x',
//             kind: AddressKind.deposit,
//             state: AddressStatus.unused,
//             index: 0,
//           ),
//           myAddressBook: [],
//           transactions: [],
//           unsignedTxs: [],
//           backupTested: hasImported,
//         );
//     }
//   } else {
//     switch (script) {
//       case ScriptType.bip44:
//         return Wallet(
//           mnemonicFingerprint: '22877153',
//           sourceFingerprint: '6c0c85c3',
//           network: network,
//           type: hasImported ? BBWalletType.words : BBWalletType.secure,
//           scriptType: ScriptType.bip44,
//           id: 'fecff663c5ae',
//           name: (hasImported ? 'Imported' : 'Bull Wallet') + ':fecff',
//           externalPublicDescriptor:
//               "pkh([6c0c85c3/44'/1'/0']tpubDDbgmMXo95Fm2UtNmp9bjkKYX8tbHYP65KZsKji9xJnojp9VhSXUmiXSdANaMPY5LS7wMbp8sFi1sv6TuDBYW5pzoZMG3udrXxQRjttjhK9/0/*)#gcjj7n65",
//           internalPublicDescriptor:
//               "pkh([6c0c85c3/44'/1'/0']tpubDDbgmMXo95Fm2UtNmp9bjkKYX8tbHYP65KZsKji9xJnojp9VhSXUmiXSdANaMPY5LS7wMbp8sFi1sv6TuDBYW5pzoZMG3udrXxQRjttjhK9/1/*)#evhnrx2v",
//           lastGeneratedAddress: Address(
//             address: 'mh2KKDKFs5d9uEZUVEm4L8PvZvkxfdk5zr',
//             kind: AddressKind.deposit,
//             state: AddressStatus.unused,
//             index: 0,
//           ),
//           myAddressBook: [],
//           transactions: [],
//           unsignedTxs: [],
//           backupTested: hasImported,
//         );
//       case ScriptType.bip49:
//         return Wallet(
//           mnemonicFingerprint: '22877153',
//           sourceFingerprint: '6c0c85c3',
//           network: network,
//           type: hasImported ? BBWalletType.words : BBWalletType.secure,
//           scriptType: ScriptType.bip49,
//           id: '410f77af8288',
//           name: (hasImported ? 'Imported' : 'Bull Wallet') + ':410f7',
//           externalPublicDescriptor:
//               "sh(wpkh([6c0c85c3/49'/1'/0']tpubDC4j8Rhy3iojB6hZ9bi35sxyxozYAkP3LfcaDgkdV33Ui19YwtwPhbRJFTWrfmcUrYHHb4sGwys7Bg76pJVQVkEZdYvtNZ9HvwqkgoojZeq/0/*))#e8l02qws",
//           internalPublicDescriptor:
//               "sh(wpkh([6c0c85c3/49'/1'/0']tpubDC4j8Rhy3iojB6hZ9bi35sxyxozYAkP3LfcaDgkdV33Ui19YwtwPhbRJFTWrfmcUrYHHb4sGwys7Bg76pJVQVkEZdYvtNZ9HvwqkgoojZeq/1/*))#vx3ejlm0",
//           lastGeneratedAddress: Address(
//             address: '2NCj9Dp266VMakSAJmeuXinyJagyGP3tiYJ',
//             kind: AddressKind.deposit,
//             state: AddressStatus.unused,
//             index: 0,
//           ),
//           myAddressBook: [],
//           transactions: [],
//           unsignedTxs: [],
//           backupTested: hasImported,
//         );
//       case ScriptType.bip84:
//         return Wallet(
//           mnemonicFingerprint: '22877153',
//           sourceFingerprint: '6c0c85c3',
//           network: network,
//           type: hasImported ? BBWalletType.words : BBWalletType.secure,
//           scriptType: ScriptType.bip84,
//           id: 'fd19d700e701',
//           name: (hasImported ? 'Imported' : 'Bull Wallet') + ':fd19d',
//           externalPublicDescriptor:
//               "wpkh([6c0c85c3/84'/1'/0']tpubDDTvq1bZpLQuWLJ15QeTFbG8ey6kv5KHPWZxrA9iXaE9zFmb2RQswLM6ieu2RKnQRYPTdofCDDXBo9SMDKnbJeMFNC3JZi1Q9U8cPmrnUyd/0/*)#59nxeqfs",
//           internalPublicDescriptor:
//               "wpkh([6c0c85c3/84'/1'/0']tpubDDTvq1bZpLQuWLJ15QeTFbG8ey6kv5KHPWZxrA9iXaE9zFmb2RQswLM6ieu2RKnQRYPTdofCDDXBo9SMDKnbJeMFNC3JZi1Q9U8cPmrnUyd/1/*)#93k8y4eg",
//           lastGeneratedAddress: Address(
//             address: 'tb1qpe2ekvzn37hhjks8fq86e8lc33hmamk4jazsv9',
//             kind: AddressKind.deposit,
//             state: AddressStatus.unused,
//             index: 0,
//           ),
//           myAddressBook: [],
//           transactions: [],
//           unsignedTxs: [],
//           backupTested: hasImported,
//         );
//     }
//   }
// }

// const Seed seed1Data = Seed(
//   network: BBNetwork.Mainnet,
//   mnemonic: 'move decline opera album crisp nice ozone casual gate ozone cycle judge',
//   passphrases: [Passphrase(passphrase: 'Pass1234', sourceFingerprint: 'Pass1234')],
// );

// const String seed1Fingerprint = '6c0c85c3';
