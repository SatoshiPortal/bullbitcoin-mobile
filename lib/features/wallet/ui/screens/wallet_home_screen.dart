import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/auto_swap_fee_warning.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/autoswap_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  bool _hasShownAutoSwapWarning = false;
  // ensures that the warning is only showed once on app startup

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          previous.autoSwapSettings != current.autoSwapSettings ||
          previous.wallets != current.wallets,
      listener: (context, state) {
        if (!_hasShownAutoSwapWarning &&
            state.showAutoSwapDefaultEnabledWarning()) {
          _hasShownAutoSwapWarning = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AutoSwapWarningBottomSheet.show(context);
          });
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {},
        child: Column(
          children: [
            const WalletHomeTopSection(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<WalletBloc>();
                  bloc.add(const WalletRefreshed());
                  await bloc.stream.firstWhere((state) => !state.isSyncing);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const HomeWarnings(),
                      const AutoSwapFeeWarning(),
                      WalletCards(
                        onTap: (w) {
                          context.pushNamed(
                            WalletRoute.walletDetail.name,
                            pathParameters: {'walletId': w.id},
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 13.0),
              child: WalletBottomButtons(),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}
