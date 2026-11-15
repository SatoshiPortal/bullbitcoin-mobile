import 'dart:convert';

import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

final class AddressHistoryItemModel {
  final String txid;
  final int height;

  const AddressHistoryItemModel({required this.txid, required this.height});
}

final class AddressOverviewModel {
  static const balanceRequestId = 1;
  static const historyRequestId = 2;

  final int confirmedSat;
  final int unconfirmedSat;
  final List<AddressHistoryItemModel> history;

  const AddressOverviewModel({
    required this.confirmedSat,
    required this.unconfirmedSat,
    required this.history,
  });

  factory AddressOverviewModel.fromResponseLines(Iterable<String> lines) {
    Map<String, dynamic>? balance;
    List<dynamic>? history;

    for (final line in lines) {
      final response = json.decode(line);
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Electrum response is not an object');
      }
      if (response['error'] != null) {
        throw const FormatException('Electrum response has an error');
      }
      final result = response['result'];
      switch (response['id']) {
        case balanceRequestId when result is Map<String, dynamic>:
          balance = result;
        case historyRequestId when result is List<dynamic>:
          history = result;
      }
    }

    if (balance == null || history == null) {
      throw const FormatException('Electrum response is incomplete');
    }
    final confirmed = balance['confirmed'];
    final unconfirmed = balance['unconfirmed'];
    if (confirmed is! int || unconfirmed is! int) {
      throw const FormatException('Electrum balance is malformed');
    }

    return AddressOverviewModel(
      confirmedSat: confirmed,
      unconfirmedSat: unconfirmed,
      history: [
        for (final item in history)
          if (item case {
            'tx_hash': final String txid,
            'height': final int height,
          })
            AddressHistoryItemModel(txid: txid, height: height)
          else
            throw const FormatException('Electrum history is malformed'),
      ],
    );
  }

  AddressOverview toEntity({
    required String address,
    required Network network,
  }) {
    final transactions = [
      for (final item in history)
        AddressTransaction(txid: item.txid, height: item.height),
    ];
    final unconfirmed = transactions.where((tx) => !tx.isConfirmed).toList();
    final confirmed = transactions.where((tx) => tx.isConfirmed).toList()
      ..sort((a, b) => b.height.compareTo(a.height));

    return AddressOverview(
      address: address,
      network: network,
      confirmedSat: confirmedSat,
      unconfirmedSat: unconfirmedSat,
      transactions: [...unconfirmed, ...confirmed],
    );
  }
}
