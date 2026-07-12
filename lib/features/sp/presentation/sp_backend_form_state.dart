import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_conn_test.dart';

/// A state that embeds the shared [SpBackendForm]. Each concrete state stores
/// the form and swaps it via [withForm], folding in its own bookkeeping (the
/// settings state marks itself initialized and clears its saved flag). The form
/// fields are forwarded as getters so the UI reads `state.network` etc. without
/// reaching into `state.form`.
mixin SpBackendFormState<S> {
  SpBackendForm get form;

  /// Rebuild this state with a new [form], applying any state-specific
  /// bookkeeping the concrete state needs.
  S withForm(SpBackendForm form);

  SpNetwork get network => form.network;
  String get blindbitUrl => form.blindbitUrl;
  String get electrumUrl => form.electrumUrl;
  SpConnTest get blindbitTest => form.blindbitTest;
  SpConnTest get electrumTest => form.electrumTest;
  SpFailure? get blindbitTestError => form.blindbitTestError;
  SpFailure? get electrumTestError => form.electrumTestError;
  bool get isFetchingDefaults => form.isFetchingDefaults;
  SpFailure? get error => form.error;
}
