import 'package:send/src/consolidation/domain/consolidation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Whether a wallet's consolidation banner should be shown.
class ConsolidationBannerCubit extends Cubit<bool> {
  final Consolidation _check;

  final String _walletId;

  ConsolidationBannerCubit({
    required Consolidation consolidation,
    required this._walletId,
  }) : _check = consolidation,
       super(false);

  /// A typed read failure hides this non-critical banner.
  Future<void> reload() async {
    try {
      final result = await _check.isRequired(_walletId);
      final required = switch (result) {
        Ok(:final value) => value,
        Err() => false,
      };
      if (!isClosed) emit(required);
    } catch (_) {
      // Keep the last known value.
    }
  }
}
