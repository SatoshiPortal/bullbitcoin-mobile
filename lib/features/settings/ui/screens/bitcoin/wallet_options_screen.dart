import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletOptionsScreen extends StatelessWidget {
  const WalletOptionsScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    final Wallet? wallet = context.select(
      (WalletBloc bloc) =>
          bloc.state.wallets.where((w) => w.id == walletId).firstOrNull,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          wallet?.displayLabel ?? context.loc.walletOptionsUnnamedWalletFallback,
        ),
      ),
      body: SafeArea(
        child:
            wallet == null
                ? Center(child: Text(context.loc.walletDeletionErrorWalletNotFound))
                : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          SettingsEntryItem(
                            icon: Icons.account_balance_wallet,
                            title: context.loc.walletOptionsWalletDetailsTitle,
                            onTap: () {
                              context.pushNamed(
                                SettingsRoute.walletDetailsSelectedWallet.name,
                                pathParameters: {'walletId': walletId},
                              );
                            },
                          ),
                          SettingsEntryItem(
                            icon: Icons.currency_bitcoin,
                            title: context.loc.addressViewAddressesTitle,
                            onTap: () {
                              context.pushNamed(
                                SettingsRoute.walletAddresses.name,
                                pathParameters: {'walletId': walletId},
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
