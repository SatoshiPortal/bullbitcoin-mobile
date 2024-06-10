import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BDKUtxo {
  Future<(Wallet?, Err?)> loadUtxos({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final unspentList = await bdkWallet.listUnspent();
      final List<Address> myAddresses = wallet.myAddressBook.toList();

      final network = wallet.getBdkNetwork();
      if (network == null) return (null, Err('Network is null'));

      final List<UTXO> list = [];

      for (final unspent in unspentList) {
        UTXO utxo;
        final scr = bdk.ScriptBuf(
          bytes: unspent.txout.scriptPubkey.bytes,
        );
        final addresss = await bdk.Address.fromScript(
          script: scr,
          network: network,
        );
        final addressStr = await addresss.asString();
        final AddressKind addressKind =
            unspent.keychain == bdk.KeychainKind.internalChain
                ? AddressKind.change
                : AddressKind.deposit;
        String addressLabel = '';
        bool spendable = true;
        for (final addr in myAddresses) {
          if (addr.address == addressStr) {
            addressLabel = addr.label ?? '';
            spendable = addr.spendable;
          }
        }
        utxo = UTXO(
          txid: unspent.outpoint.txid,
          txIndex: unspent.outpoint.vout,
          isSpent: unspent.isSpent,
          value: unspent.txout.value,
          label: addressLabel,
          spendable: spendable,
          address: Address(
            address: addressStr,
            kind: addressKind,
            state: AddressStatus.active,
          ),
        );
        list.add(utxo);
      }

      final w = wallet.copyWith(utxos: list);
      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while loading utxos',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<Wallet?> updateUtxoLabel({
    required String addressStr,
    required Wallet wallet,
    required String label,
  }) async {
    try {
      final List<UTXO> utxos = wallet.utxos.toList();
      final existingIdx = utxos.indexWhere(
        (element) => element.address.address == addressStr,
      );
      if (existingIdx != -1) {
        final existing = utxos.removeAt(existingIdx);
        final updated = existing.copyWith(label: label);
        utxos.insert(existingIdx, updated);
      }

      final w = wallet.copyWith(utxos: utxos);

      return w;
    } catch (e) {
      rethrow;
    }
  }

  (Wallet?, Err?) updateUtxoFromAddressSpendable({
    required Wallet wallet,
    required Address address,
    required bool spendable,
  }) {
    try {
      final utxos = [...wallet.utxos].toList();

      final index =
          utxos.indexWhere((utxo) => utxo.address.address == address.address);

      if (index == -1) return (wallet, null);

      final utxo = utxos[index].copyWith(spendable: spendable);
      utxos.removeAt(index);
      utxos.insert(index, utxo);

      final w = wallet.copyWith(utxos: utxos);

      return (w, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while update UTXO spendable from address',
          solution: 'Please try again.',
        )
      );
    }
  }
}
