import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receive({
    required String id,
    required String walletId,
    String? broadcastedTxId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = ReceivePayjoin;
  const factory Payjoin.send({
    required String uri,
    required String walletId,
    String? broadcastedTxId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = SendPayjoin;
  const Payjoin._();

  String get id => when(
        receive: (id, _, __, ___, ____) => id,
        send: (uri, _, __, ___, ____) => uri,
      );
}
