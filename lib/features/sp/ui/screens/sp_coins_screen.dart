import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/ui/widgets/coin_source_label.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpCoinsScreen extends StatelessWidget {
  const SpCoinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.loc.coinsTitle, style: context.font.headlineMedium),
      ),
      body: SafeArea(
        child: BlocBuilder<SpCubit, SpState>(
          builder: (context, state) {
            final coins = state.coins;
            if (coins.isEmpty) {
              return Center(
                child: Text(
                  context.loc.spCoinsEmpty,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: coins.length,
              itemBuilder: (context, i) => _SpCoinTile(coin: coins[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SpCoinTile extends StatelessWidget {
  const _SpCoinTile({required this.coin});
  final SpCoin coin;

  @override
  Widget build(BuildContext context) {
    final color = coin.source.sourceColor(context);
    return ListTile(
      leading: SpBadge(label: coin.source.shortLabel(context), color: color),
      title: Text(
        context.loc.spSendSatsAmount(
          FormatAmount.satsGrouped(coin.amountSat.toInt()),
        ),
      ),
      subtitle: Text(
        context.loc.spCoinSubtitle(
          StringFormatting.truncateMiddle(
            coin.outpoint,
            head: 10,
            tail: 8,
            placeholder: '…',
          ),
          coin.height != null
              ? context.loc.spBlockLabel('${coin.height}')
              : context.loc.spUnconfirmed,
        ),
        style: context.font.bodySmall?.copyWith(
          color: context.appColors.textMuted,
        ),
      ),
      trailing: _statusIcon(context, coin.status),
    );
  }

  Widget _statusIcon(BuildContext context, SpCoinStatus status) {
    final (icon, color, tooltip) = switch (status) {
      SpCoinStatus.unconfirmed => (
        Icons.schedule,
        context.appColors.textMuted,
        context.loc.spUnconfirmed,
      ),
      SpCoinStatus.unspent => (
        Icons.check_circle,
        context.appColors.success,
        context.loc.spCoinStatusUnspent,
      ),
      SpCoinStatus.spent => (
        Icons.remove_circle,
        context.appColors.textMuted,
        context.loc.spCoinStatusSpent,
      ),
    };
    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color),
    );
  }
}
