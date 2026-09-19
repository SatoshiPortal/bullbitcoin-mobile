import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Exposes the existing policy owner while the caller owns the presentation.
class WalletPolicyView extends StatelessWidget {
  final String walletId;
  final Widget Function(BuildContext, BitcoinWalletPolicy) builder;
  const WalletPolicyView({
    super.key,
    required this.walletId,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(walletId),
    create: (_) => locator<WalletDetailsCubit>()..loadPolicy(walletId),
    child: BlocBuilder<WalletDetailsCubit, WalletDetailsState>(
      builder: (context, state) {
        if (state.isLoadingPolicy) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.failure == null) {
          if (state.policy case final policy?) return builder(context, policy);
        }
        return Column(
          children: [
            Text(context.loc.walletDetailsUnavailableLabel),
            TextButton(
              onPressed: () =>
                  context.read<WalletDetailsCubit>().loadPolicy(walletId),
              child: Text(context.loc.retry),
            ),
          ],
        );
      },
    ),
  );
}
