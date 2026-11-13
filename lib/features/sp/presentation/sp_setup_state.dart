import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_setup_state.freezed.dart';

/// Where the wallet starts scanning once created. A fresh wallet has no
/// history, so it starts at the current tip; an existing one picks a height.
enum SpScanStart { fromNow, earlierBlock }

@freezed
sealed class SpSetupState
    with _$SpSetupState, SpBackendFormState<SpSetupState> {
  const factory SpSetupState({
    @Default(SpBackendForm()) SpBackendForm form,
    @Default(true) bool isInspecting,
    SpFailure? entryFailure,
    @Default(SpScanStart.fromNow) SpScanStart scanStart,
    @Default(false) bool isCreating,
    @Default(false) bool created,
    @Default(false) bool existingVerified,
  }) = _SpSetupState;

  const SpSetupState._();

  // A wrong address can't create a wallet: both URLs must pass a connection
  // test (which cannot pass on an empty URL, so no separate non-empty check).
  bool get canCreate =>
      form.blindbitStatus == SpConnectionStatus.ok &&
      form.electrumStatus == SpConnectionStatus.ok &&
      !isCreating &&
      !isInspecting &&
      entryFailure == null;

  @override
  SpSetupState withForm(SpBackendForm form) => copyWith(form: form);
}
