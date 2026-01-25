import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeStatusSection extends StatelessWidget {
  const HomeStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isSyncing = context.select((WalletBloc bloc) => bloc.state.isSyncing);

    return Center(
      child: BBText(
        isSyncing ? 'Syncing...' : 'Last synced: just now',
        style: context.font.labelSmall,
        color: context.appColors.textMuted,
      ),
    );
  }
}
