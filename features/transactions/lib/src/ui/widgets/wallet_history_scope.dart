import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/blocs/transactions_cubit.dart';

/// Coordinates a wallet pull-to-refresh with the active history list.
abstract final class WalletHistoryScope {
  static Future<void> refresh(
    BuildContext context,
    Future<void> Function() refreshWallet,
  ) async {
    final transactions = context.read<TransactionsCubit>();
    transactions.deferReloads();
    try {
      await refreshWallet();
    } finally {
      await transactions.resumeReloads();
    }
  }
}
