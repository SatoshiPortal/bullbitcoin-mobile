part of 'utxos_bloc.dart';

sealed class UtxosEvent {}

class UtxosLoaded extends UtxosEvent {
  final String walletId;
  final int? limit;
  final int? offset;

  UtxosLoaded(this.walletId, {this.limit, this.offset});
}

class UtxosDetailLoaded extends UtxosEvent {
  final String walletId;
  final String txId;
  final int index;

  UtxosDetailLoaded(this.walletId, {required this.txId, required this.index});
}
