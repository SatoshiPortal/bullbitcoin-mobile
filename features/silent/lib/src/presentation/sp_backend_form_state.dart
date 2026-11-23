import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/presentation/sp_backend_form.dart';
import 'package:silent/src/presentation/sp_connection_status.dart';

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

  BitcoinNetwork get network => form.network;
  String get blindbitUrl => form.blindbitUrl;
  String get electrumUrl => form.electrumUrl;
  int get fetchConcurrencyFactor => form.fetchConcurrencyFactor;
  int get matchConcurrencyFactor => form.matchConcurrencyFactor;
  SpConnectionStatus get blindbitStatus => form.blindbitStatus;
  SpConnectionStatus get electrumStatus => form.electrumStatus;
  SilentFailure? get blindbitStatusError => form.blindbitStatusError;
  SilentFailure? get electrumStatusError => form.electrumStatusError;
  bool get isFetchingDefaults => form.isFetchingDefaults;
  SilentFailure? get error => form.error;
}
