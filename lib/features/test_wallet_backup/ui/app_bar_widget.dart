import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AppBarWidget extends StatelessWidget {
  const AppBarWidget({super.key, required this.title});

  final String title;

  @override
  PreferredSizeWidget build(BuildContext context) {
    final wallets = context.watch<TestWalletBackupBloc>().state.wallets;
    final selectedWallet =
        context.watch<TestWalletBackupBloc>().state.selectedWallet;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(title),
      actions: [
        if (wallets.length > 1)
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_down),
            onPressed: () async {
              final bloc = context.read<TestWalletBackupBloc>();
              final selectedId = selectedWallet?.id;
              final selectedIndex = wallets.indexWhere(
                (w) => w.id == selectedId,
              );

              final selectedWalletId = await _showWalletPicker(
                context: context,
                wallets: wallets,
                initialIndex: selectedIndex,
              );

              if (selectedWalletId != null) {
                bloc.add(LoadMnemonicForWallet(wallet: selectedWallet!));
              }
            },
          ),
      ],
    );
  }
}

Future<String?> _showWalletPicker({
  required BuildContext context,
  required List<Wallet> wallets,
  required int initialIndex,
}) {
  final controller = FixedExtentScrollController(
    initialItem: initialIndex >= 0 ? initialIndex : 0,
  );

  return BlurredBottomSheet.show<String>(
    context: context,
    isDismissible: true,
    child: Container(
      height: MediaQuery.of(context).size.height * 0.4,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: context.appColors.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Gap(8),
          Expanded(
            child: CupertinoPicker(
              scrollController: controller,
              itemExtent: 70,
              onSelectedItemChanged: (index) {},
              children: [
                for (final wallet in wallets)
                  Center(
                    child: BBText(
                      wallet.isDefault
                          ? context.loc.testBackupDefaultWallets
                          : wallet.displayLabel,
                      style: context.font.bodyLarge?.copyWith(
                        fontWeight: .w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          BBButton.big(
            label: context.loc.testBackupConfirm,
            onPressed: () {
              final wallet = wallets[controller.selectedItem];
              context.read<TestWalletBackupBloc>().add(
                LoadMnemonicForWallet(wallet: wallet),
              );
              Navigator.of(context).pop();
            },
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
      ),
    ),
  );
}
