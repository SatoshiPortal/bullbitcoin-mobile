import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ImportSelectWalletTypeScreen extends StatelessWidget {
  const ImportSelectWalletTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((ImportWalletCubit cubit) => cubit.state.walletDetails ?? []);

    final walletCubits = [
      for (final w in wallets)
        WalletCubit(
          saveDir: w.getStorageString(),
          settingsCubit: locator<SettingsCubit>(),
          walletRead: locator<WalletRead>(),
          secureStorage: locator<IStorage>(),
          storage: locator<HiveStorage>(),
          walletCreate: locator<WalletCreate>(),
          walletUpdate: locator<WalletUpdate>(),
          fromStorage: false,
          wallet: w,
        )
    ];

    return BlocListener<ImportWalletCubit, ImportState>(
      listenWhen: (previous, current) => previous.savedWallet != current.savedWallet,
      listener: (context, state) {
        if (state.savedWallet == null) return;
        locator<HomeCubit>().addWallet(state.savedWallet!);
        context.go('/home');
      },
      child: _Screen(walletCubits: walletCubits),
    ).animate(delay: 200.ms).fadeIn();
  }
}

class _Screen extends StatefulWidget {
  const _Screen({required this.walletCubits});

  final List<WalletCubit> walletCubits;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  List<WalletType> walletTypes = [];
  void syncingDone(WalletType type, BuildContext context) {
    if (walletTypes.contains(type)) return;
    walletTypes.add(type);
    if (walletTypes.length == widget.walletCubits.length)
      context.read<ImportWalletCubit>().syncingComplete();
  }

  @override
  Widget build(BuildContext context) {
    // final step = context.select((ImportWalletCubit cubit) => cubit.state.importStep);

    // if (step == ImportSteps.scanningWallets) {
    //   final listeners = [
    //     for (final walletCubit in widget.walletCubits)
    //       BlocListener<WalletCubit, WalletState>(
    //         bloc: walletCubit,
    //         listenWhen: (previous, current) => previous.syncing != current.syncing,
    //         listener: (context, state) async {
    //           if (state.wallet == null) return;

    //           if (!state.syncing) syncingDone(state.wallet!.walletType, context);

    //           if (state.wallet!.isActive()) {
    //             context.read<ImportWalletCubit>().walletTypeChanged(state.wallet!.walletType);
    //           }
    //         },
    //       )
    //   ];

    //   return MultiBlocListener(
    //     listeners: listeners,
    //     child: const ImportScanning(isColdCard: false),
    //   );
    // }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(32),
            const _ImportWalletTypeXpubHeader(),
            const Gap(32),
            const BBText.title(
              'Choose wallet type',
            ),
            const Gap(16),
            for (final walletCubit in widget.walletCubits) ...[
              BlocProvider.value(
                value: walletCubit,
                child: const _ImportWalletTypeButton(),
              ),
              const Gap(16),
            ],
            const Gap(80),
            SizedBox(
              width: 250,
              child: BBButton.bigRed(
                filled: true,
                onPressed: () {
                  context.read<ImportWalletCubit>().saveClicked();
                },
                label: 'Import Wallet',
              ),
            ),
            const Gap(16),
            SizedBox(
              width: 250,
              child: BBButton.text(
                onPressed: () {
                  context.read<ImportWalletCubit>().backClicked();
                },
                label: 'Cancel',
              ),
            ),
            const Gap(80),
          ],
        ),
      ),
    );
  }
}

class _ImportWalletTypeXpubHeader extends StatelessWidget {
  const _ImportWalletTypeXpubHeader();

  @override
  Widget build(BuildContext context) {
    final xpub = context.select((ImportWalletCubit cubit) => cubit.state.xpub);

    if (xpub.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBText.title(
            'Imported Master Public Key-- XPUB',
          ),
          BBText.bodySmall(
            xpub,
          ),
        ],
      ),
    );
  }
}

class _ImportWalletTypeButton extends StatelessWidget {
  const _ImportWalletTypeButton();

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletCubit cubit) => cubit.state.wallet);

    if (wallet == null) return const SizedBox.shrink();

    final walletType = wallet.walletType;

    final selected =
        context.select((ImportWalletCubit cubit) => cubit.state.isSelected(walletType));

    final name = context.select(
      (ImportWalletCubit cubit) => cubit.state.walletName(walletType),
    );

    final syncing = context.select((WalletCubit cubit) => cubit.state.syncing);

    final ad = context.select((WalletCubit cubit) => cubit.state.firstAddress ?? '');

    final balance = context.select((WalletCubit cubit) => cubit.state.balance);

    // final hasTxs = context.select(
    //   (WalletCubit cubit) => cubit.state.wallet?.transactions?.isNotEmpty ?? false,
    // );

    final address = ad.isNotEmpty ? ad.substring(0, 5) + '...' + ad.substring(ad.length - 5) : '';
    final fingerprint = wallet.type == BBWalletType.descriptors ? '' : wallet.cleanFingerprint();

    return AnimatedContainer(
      duration: 500.ms,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: InkWell(
                    onTap: () {
                      context.read<ImportWalletCubit>().walletTypeChanged(walletType);
                    },
                    radius: 32,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 100),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(32.0)),
                        border: Border.all(
                          width: selected ? 4 : 1,
                          color: selected ? context.colour.primary : context.colour.onBackground,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              BBText.body(
                                name,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: syncing
                                    ? CircularProgressIndicator(
                                        color: context.colour.primary,
                                        strokeWidth: 2,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          const Gap(4),
                          if (fingerprint.isNotEmpty)
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Wallet fingerprint (XFP): ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: fingerprint,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Gap(4),
                          if (syncing) ...[
                            const BBText.bodySmall(
                              'Scanning wallet ...',
                            ),
                          ],
                          if (address.isNotEmpty)
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'First Address: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Gap(4),
                          if (balance != null)
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Balance: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: balance.total.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // const Gap(4),
                          // if (hasTxs)
                          //   RichText(
                          //     text: TextSpan(
                          //       children: [
                          //         TextSpan(
                          //           text: 'Transactions: ',
                          //           style: TextStyle(
                          //             fontSize: 12,
                          //             color: context.colour.onBackground,
                          //           ),
                          //         ),
                          //         TextSpan(
                          //           text: wallet.transactions!.length.toString(),
                          //           style: TextStyle(
                          //             fontSize: 12,
                          //             fontWeight: FontWeight.bold,
                          //             color: context.colour.onBackground,
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ImportWalletDetailsPopUp extends StatelessWidget {
  const ImportWalletDetailsPopUp({super.key, required this.wallet, required this.walletType});

  final Wallet wallet;
  final WalletType walletType;

  static Future showPopUp(BuildContext context, WalletType walletType) async {
    final import = context.read<ImportWalletCubit>();
    final wallet = import.state.getWalletDetails(walletType);
    if (wallet == null) return;

    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: import,
        child: ImportWalletDetailsPopUp(
          wallet: wallet,
          walletType: walletType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = context.select(
      (ImportWalletCubit cubit) => cubit.state.walletName(walletType),
    );

    return PopUpBorder(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BBText.body(
                  title,
                ),
                IconButton(
                  onPressed: () {
                    context.pop();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Gap(32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BBText.body(
                  'First Address',
                ),
                const BBText.body(
                  'wallet.firstAddress',
                ),
                const Gap(16),
                if (wallet.fingerprint.isNotEmpty) ...[
                  const BBText.body(
                    'Wallet fingerprint (XFP)',
                  ),
                  BBText.body(
                    wallet.fingerprint,
                  ),
                  const Gap(16),
                ],
                if (wallet.xpub != null) ...[
                  const BBText.body(
                    'Child expanded public key',
                  ),
                  BBText.body(
                    wallet.xpub!,
                  ),
                ],
                const Gap(16),
                const BBText.body(
                  'Derivation Path',
                ),
                BBText.body(
                  wallet.path!,
                ),
                const Gap(48),
                Center(
                  child: SizedBox(
                    width: 250,
                    child: BBButton.bigRed(
                      onPressed: () {
                        context.pop();
                      },
                      label: 'Done',
                    ),
                  ),
                ),
                const Gap(48),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
