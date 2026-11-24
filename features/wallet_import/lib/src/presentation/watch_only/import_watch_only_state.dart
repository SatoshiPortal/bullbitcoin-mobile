import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_watch_only_state.freezed.dart';

@freezed
abstract class ImportWatchOnlyState with _$ImportWatchOnlyState {
  const factory ImportWatchOnlyState({
    WatchOnlyWalletEntity? watchOnlyWallet,
    @Default(false) bool imported,
    @Default('') String input,
    ImportWatchOnlyFailure? failure,
  }) = _ImportWatchOnlyState;

  const ImportWatchOnlyState._();
}
