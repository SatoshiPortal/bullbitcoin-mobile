import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/address.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';

class WalletAddress implements IWalletAddress {
  WalletAddress({
    required WalletsRepository walletsRepository,
    required BDKAddress bdkAddress,
    required LWKAddress lwkAddress,
  })  : _walletsRepository = walletsRepository,
        _bdkAddress = bdkAddress,
        _lwkAddress = lwkAddress;

  final WalletsRepository _walletsRepository;
  final BDKAddress _bdkAddress;
  final LWKAddress _lwkAddress;

  @override
  Future<(String?, Err?)> peekIndex({
    required Wallet wallet,
    required int idx,
  }) async {
    try {
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (bdkWallet, errWallet) = _walletsRepository.getBdkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          return await _bdkAddress.peekIndex(bdkWallet!, idx);

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) = _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          return await _lwkAddress.peekIndex(liqWallet!, idx);
      }
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while getting address',
          solution: 'Please try again.',
        )
      );
    }
  }

  @override
  Future<(Wallet?, Err?)> newAddress(Wallet wallet) async {
    try {
      String address;
      switch (wallet.baseWalletType) {
        case BaseWalletType.Bitcoin:
          final (bdkWallet, errWallet) = _walletsRepository.getBdkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final lastIdx = wallet.lastGeneratedAddress?.index ?? 0;
          final (addr, errAddr) = await _bdkAddress.peekIndex(
            bdkWallet!,
            lastIdx + 1,
          );
          if (errAddr != null) throw errAddr;
          address = addr!;

        case BaseWalletType.Liquid:
          final (liqWallet, errWallet) = _walletsRepository.getLwkWallet(wallet.id);
          if (errWallet != null) throw errWallet;
          final lastIdx = wallet.lastGeneratedAddress?.index ?? 0;
          final (addr, errAddr) = await _lwkAddress.peekIndex(
            liqWallet!,
            lastIdx + 1,
          );
          if (errAddr != null) throw errAddr;
          address = addr!;
      }

      final (addr, updatedWallet) = await addAddressToWallet(
        address: (
          wallet.lastGeneratedAddress!.index! + 1,
          address,
        ),
        wallet: wallet,
        kind: AddressKind.deposit,
      );

      final w = updatedWallet.setLastAddress(addr);

      return (w, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while generating new address',
          solution: 'Please try again.',
        )
      );
    }
  }

  @override
  Future<(Address, Wallet)> addAddressToWallet({
    required (int?, String) address,
    required Wallet wallet,
    String? label,
    String? spentTxId,
    required AddressKind kind,
    AddressStatus state = AddressStatus.unused,
    bool spendable = true,
    // int highestPreviousBalance = 0,
  }) async {
    try {
      final (idx, adr) = address;
      final addresses =
          (kind == AddressKind.external ? wallet.externalAddressBook?.toList() : wallet.myAddressBook.toList()) ??
              <Address>[];

      Address updated;
      final existingIdx = addresses.indexWhere(
        (element) => element.address == adr,
      );
      final addressExists = existingIdx != -1;
      if (addressExists) {
        final existing = addresses.removeAt(existingIdx);
        updated = Address(
          address: existing.address,
          index: existing.index,
          label: label ?? existing.label,
          spentTxId: spentTxId ?? existing.spentTxId,
          kind: kind,
          state: state,
          spendable: spendable,
          balance: existing.balance,
          isLiquid: existing.isLiquid,
        );
        addresses.insert(existingIdx, updated);
      } else {
        updated = Address(
          address: adr,
          index: idx,
          label: label,
          spentTxId: spentTxId,
          kind: kind,
          state: state,
          spendable: spendable,
          isLiquid: wallet.baseWalletType == BaseWalletType.Liquid,
        );
        addresses.add(updated);
      }

      final w = kind == AddressKind.external
          ? wallet.copyWith(externalAddressBook: addresses)
          : wallet.copyWith(myAddressBook: addresses);

      return (updated, w);
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getLabel({
    required Wallet wallet,
    required String address,
  }) async {
    final addresses = wallet.myAddressBook;

    String? label;
    if (addresses.any((element) => element.address == address)) {
      final x = addresses.firstWhere(
        (element) => element.address == address,
      );
      label = x.label;
    }

    return label;
  }
}
