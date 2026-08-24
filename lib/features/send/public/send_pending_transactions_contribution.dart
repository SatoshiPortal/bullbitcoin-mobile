import 'dart:async';

import 'package:bb_mobile/features/send/presentation/bloc/send_pending_transactions_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_pending_transactions_section.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendPendingTransactionsContribution extends StatefulWidget {
  final String walletId;
  final Stream<void> walletRefreshes;

  const SendPendingTransactionsContribution({
    super.key,
    required this.walletId,
    this.walletRefreshes = const Stream.empty(),
  });

  @override
  State<SendPendingTransactionsContribution> createState() =>
      _SendPendingTransactionsContributionState();
}

class _SendPendingTransactionsContributionState
    extends State<SendPendingTransactionsContribution> {
  late final SendPendingTransactionsCubit _cubit;
  late StreamSubscription<void> _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _cubit = locator<SendPendingTransactionsCubit>()..watch(widget.walletId);
    _refreshSubscription = widget.walletRefreshes.listen((_) => _cubit.retry());
  }

  @override
  void didUpdateWidget(SendPendingTransactionsContribution oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletId != widget.walletId) {
      _cubit.watch(widget.walletId);
    }
    if (oldWidget.walletRefreshes != widget.walletRefreshes) {
      unawaited(_refreshSubscription.cancel());
      _refreshSubscription = widget.walletRefreshes.listen(
        (_) => _cubit.retry(),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_refreshSubscription.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: const SendPendingTransactionsSection(),
  );
}
