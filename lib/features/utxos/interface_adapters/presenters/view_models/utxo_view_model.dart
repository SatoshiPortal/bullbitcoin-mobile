import 'package:bb_mobile/features/utxos/application/dto/utxo_dto.dart';

class UtxoViewModel {
  final String walletId;
  final String txId;
  final int index;
  final int valueSat;
  final String address;
  final bool isSpendable;
  final List<String> outputLabels;
  final List<String> addressLabels;
  final List<String> transactionLabels;

  const UtxoViewModel({
    required this.walletId,
    required this.txId,
    required this.index,
    required this.valueSat,
    required this.address,
    required this.isSpendable,
    required this.outputLabels,
    required this.addressLabels,
    required this.transactionLabels,
  });

  String get outpoint => '$txId:$index';

  List<String> get labels {
    final allLabels = <String>{};
    allLabels.addAll(outputLabels);
    allLabels.addAll(addressLabels);
    allLabels.addAll(transactionLabels);
    return allLabels.toList();
  }

  factory UtxoViewModel.fromDto(UtxoDto dto) {
    return UtxoViewModel(
      walletId: dto.walletId,
      txId: dto.txId,
      index: dto.index,
      valueSat: dto.valueSat,
      address: dto.address,
      isSpendable: dto.isSpendable,
      outputLabels: dto.outputLabels,
      addressLabels: dto.addressLabels,
      transactionLabels: dto.transactionLabels,
    );
  }
}
