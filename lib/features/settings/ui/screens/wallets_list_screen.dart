import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletsListScreen extends StatefulWidget {
  const WalletsListScreen({super.key});

  @override
  State<WalletsListScreen> createState() => _WalletsListScreenState();
}

class _WalletsListScreenState extends State<WalletsListScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh wallet list when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletBloc>().add(const WalletRefreshed());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Wallet details',
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            if (state.status == WalletStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final wallets = state.wallets;
            if (wallets.isEmpty) {
              return Center(
                child: BBText(
                  'No wallets found',
                  style: context.font.bodyLarge?.copyWith(
                    color: context.colour.outlineVariant,
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<WalletBloc>().add(const WalletRefreshed());
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  return InkWell(
                    onTap: () {
                      context.pushNamed(
                        SettingsRoute.walletDetailsSelectedWallet.name,
                        pathParameters: {'walletId': wallet.id},
                      );
                      // Refresh wallet list when returning from wallet details
                      if (mounted) {
                        context.read<WalletBloc>().add(const WalletRefreshed());
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: BBText(
                              wallet.getLabel() ?? 'Unnamed Wallet',
                              overflow: TextOverflow.ellipsis,
                              style: context.font.bodyLarge?.copyWith(
                                color: context.colour.outlineVariant,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
