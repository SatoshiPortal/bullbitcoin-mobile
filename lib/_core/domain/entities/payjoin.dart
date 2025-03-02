import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receive({
    required String id,
    required String walletId,
    required String url,
    String? broadcastedTxId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinReceive;
  const factory Payjoin.send({
    required String uri,
    required String walletId,
    String? broadcastedTxId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = PayjoinSend;
}
