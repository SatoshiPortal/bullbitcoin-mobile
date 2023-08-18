// class WalletLabels {

//   Future<(Wallet?, Err?)> updateChangeLabel({
//     required Wallet wallet,
//     required bdk.Wallet bdkWallet,
//     // ignore: type_annotate_public_apis
//     required String txid,
//     required String label,
//   }) async {
//     try {
//       final utxos = await bdkWallet.listUnspent();
//       final addresses = wallet.addresses?.toList() ?? [];

//       final newChange = utxos.firstWhere(
//         (element) => element.keychain == bdk.KeychainKind.Internal && element.outpoint.txid == txid,
//       );

//       final scr = await bdk.Script.create(newChange.txout.scriptPubkey.internal);
//       final addresss = await bdk.Address.fromScript(
//         scr,
//         wallet.getBdkNetwork(),
//       );
//       final a = Address(address: addresss.toString(), index: -1, label: label);
//       // final addressStr = addresss.toString();
//       addresses.add(a);
//       final w = wallet.copyWith(addresses: addresses);
//       return (w, null);
//     } catch (e) {
//       return (null, Err(e.toString()));
//     }
//   }
//   Future<(Wallet?, Err?)> updateRelatedLabels({
//     required Wallet wallet,
//     required bdk.Wallet bdkWallet,
//     // ignore: type_annotate_public_apis
//   }) async {
//     try {
//       late bool isRelated = false;

//       for (final element in tx.inAddresses!) {
//         if (element == address) {
//           isRelated = true;
//         }
//       }

//       for (final element in tx.outAddresses!) {
//         if (element == address) {
//           isRelated = true;
//         }
//       }

//       if (isRelated) {
//         return (tx.copyWith(label: label), null);
//       }
//       return (tx, null);
//     } catch (e) {
//       return (null, Err(e.toString()));
//     }
//   }
// }
