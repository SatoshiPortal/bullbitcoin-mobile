part of 'utxos_bloc.dart';

sealed class UtxosEvent {}

class UtxosLoaded extends UtxosEvent {
  final String walletId;
  final int? limit;
  final int? offset;

  UtxosLoaded(this.walletId, {this.limit, this.offset});
}

class UtxosUtxoDetailsLoaded extends UtxosEvent {
  final String outpoint;
  final String walletId;

  UtxosUtxoDetailsLoaded({required this.outpoint, required this.walletId});
}
