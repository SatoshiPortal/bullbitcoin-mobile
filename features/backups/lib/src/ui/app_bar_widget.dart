import 'package:backups/src/backups_l10n.dart';
import 'package:backups/src/domain/backup_wallet.dart';
import 'package:backups/src/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullThemeX,
        BullBottomSheet,
        BullButton,
        BullText,
        BullTypographyX,
        Gap;
import 'package:go_router/go_router.dart';

class AppBarWidget extends StatelessWidget {
  const AppBarWidget({super.key, required this.title});

  final String title;

  @override
  PreferredSizeWidget build(BuildContext context) {
    final wallets = context.watch<TestWalletBackupBloc>().state.wallets;
    final selectedWallet = context
        .watch<TestWalletBackupBloc>()
        .state
        .selectedWallet;

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

              final selection = await _showWalletPicker(
                context: context,
                wallets: wallets,
                initialIndex: selectedIndex,
              );

              if (selection != null && !bloc.isClosed) {
                bloc.add(WalletSelected(wallet: selection));
              }
            },
          ),
      ],
    );
  }
}

Future<BackupWallet?> _showWalletPicker({
  required BuildContext context,
  required List<BackupWallet> wallets,
  required int initialIndex,
}) async {
  final controller = FixedExtentScrollController(
    initialItem: initialIndex >= 0 ? initialIndex : 0,
  );

  try {
    return await BullBottomSheet.show<BackupWallet>(
      context: context,
      isDismissible: true,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: .min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: context.bull.secondary),
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
                        child: BullText(
                          wallet.isDefault
                              ? context.loc.testBackupDefaultWallets
                              : wallet.label ??
                                    context
                                        .loc
                                        .walletDetailsUnnamedWalletFallback,
                          style: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.bull.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              BullButton.primary(
                label: context.loc.testBackupConfirm,
                onPressed: () {
                  Navigator.of(context).pop(wallets[controller.selectedItem]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}
