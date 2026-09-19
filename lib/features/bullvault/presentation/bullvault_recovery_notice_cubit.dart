import 'package:flutter_bloc/flutter_bloc.dart';

/// A transient home message; it owns no vault or backup state.
final class BullVaultRecoveryNoticeCubit
    extends Cubit<({String walletId, String label})?> {
  BullVaultRecoveryNoticeCubit() : super(null);

  void record({required String walletId, required String label}) =>
      emit((walletId: walletId, label: label));

  void opened(String walletId) {
    if (state?.walletId == walletId) emit(null);
  }
}
