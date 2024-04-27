import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/balance.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ImportSelectWalletTypeScreen extends StatelessWidget {
  const ImportSelectWalletTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallets = context
        .select((ImportWalletCubit cubit) => cubit.state.walletDetails ?? []);

    final walletCubits = [
      for (final w in wallets)
        WalletBloc(
          saveDir: w.getWalletStorageString(),
          walletSync: locator<WalletSync>(),
          walletsStorageRepository: locator<WalletsStorageRepository>(),
          fromStorage: false,
          walletBalance: locator<WalletBalance>(),
          walletAddress: locator<WalletAddress>(),
          networkCubit: locator<NetworkCubit>(),
          // swapBloc: locator<WatchTxsBloc>(),
          wallet: w,
          networkRepository: locator<NetworkRepository>(),
          walletsRepository: locator<WalletsRepository>(),
          walletTransactionn: locator<WalletTx>(),
          walletCreatee: locator<WalletCreate>(),
        ),
    ];

    return BlocListener<ImportWalletCubit, ImportState>(
      listenWhen: (previous, current) =>
          previous.savedWallet != current.savedWallet,
      listener: (context, state) async {
        if (!state.savedWallet) return;
        locator<HomeCubit>().getWalletsFromStorage();
        // final wallet = state.savedWallet!;
        // locator<HomeCubit>().addWallets([wallet]);
        // await Future.delayed(300.milliseconds);
        // locator<HomeCubit>().changeMoveToIdx(wallet);
        // await Future.delayed(300.milliseconds);
        context.go('/home');
      },
      child: _Screen(walletCubits: walletCubits),
    ).animate(delay: 200.ms).fadeIn();
  }
}

class _Screen extends StatefulWidget {
  const _Screen({required this.walletCubits});

  final List<WalletBloc> walletCubits;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  List<ScriptType> scriptTypes = [];
  void syncingDone(ScriptType scriptType, BuildContext context) {
    if (scriptTypes.contains(scriptType)) return;
    scriptTypes.add(scriptType);
    if (scriptTypes.length == widget.walletCubits.length)
      context.read<ImportWalletCubit>().syncingComplete();
  }

  @override
  Widget build(BuildContext context) {
    final saving =
        context.select((ImportWalletCubit cubit) => cubit.state.savingWallet);
    // final
    // if (step == ImportSteps.scanningWallets) {
    //   final listeners = [
    //     for (final walletBloc in widget.walletCubits)
    //       BlocListener<walletBloc, WalletState>(
    //         bloc: walletBloc,
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
      key: UIKeys.importWalletSelectionScrollable,
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
            for (final walletBloc in widget.walletCubits) ...[
              BlocProvider.value(
                value: walletBloc,
                child: const _ImportWalletTypeButton(),
              ),
              const Gap(16),
            ],
            const Gap(80),
            const SavingError(),
            Center(
              child: BBButton.big(
                buttonKey: UIKeys.importWalletSelectionConfirmButton,
                disabled: saving,
                filled: true,
                onPressed: () {
                  context.read<ImportWalletCubit>().saveClicked();
                },
                label: 'Import Wallet',
              ),
            ),
            const Gap(16),
            BBButton.text(
              centered: true,
              onPressed: () {
                context.read<ImportWalletCubit>().backClicked();
              },
              label: 'Cancel',
            ),
            const Gap(80),
          ],
        ),
      ),
    );
  }
}

class SavingError extends StatelessWidget {
  const SavingError({super.key});

  @override
  Widget build(BuildContext context) {
    final err =
        context.select((ImportWalletCubit _) => _.state.errSavingWallet);

    if (err.isEmpty) return const SizedBox(height: 24);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BBText.error(err, textAlign: TextAlign.center),
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
    final wallet = context.select((WalletBloc cubit) => cubit.state.wallet);

    if (wallet == null) return const SizedBox.shrink();

    final scriptType = wallet.scriptType;

    final selected = context.select(
      (ImportWalletCubit cubit) => cubit.state.isSelected(scriptType),
    );

    final name = context.select(
      (ImportWalletCubit cubit) => cubit.state.walletName(scriptType),
    );

    final syncing = context.select((WalletBloc cubit) => cubit.state.syncing);

    final ad = context.select((WalletBloc cubit) => cubit.state.firstAddress);

    final balance =
        context.select((WalletBloc cubit) => cubit.state.wallet?.fullBalance);

    final hasTxs = context.select(
      (WalletBloc cubit) =>
          cubit.state.wallet?.transactions.isNotEmpty ?? false,
    );

    final address = ad?.miniString() ?? '';
    final fingerprint = wallet.sourceFingerprint;

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
                    key: UIKeys.importWalletSelectionCard(scriptType),
                    borderRadius: BorderRadius.circular(32),
                    onTap: () {
                      context
                          .read<ImportWalletCubit>()
                          .scriptTypeChanged(scriptType);
                    },
                    radius: 32,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 100),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(32.0)),
                        border: Border.all(
                          width: selected ? 4 : 1,
                          color: selected
                              ? context.colour.primary
                              : context.colour.onBackground,
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
                          const Gap(4),
                          if (hasTxs)
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Transactions: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: wallet.transactions.length.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: context.colour.onBackground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (syncing) ...[
                            const BBText.bodySmall(
                              'Scanning wallet ...',
                              uiKey: UIKeys.importWalletSelectionLoader,
                            ),
                          ],
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
  const ImportWalletDetailsPopUp({
    super.key,
    required this.wallet,
    required this.scriptType,
  });

  final Wallet wallet;
  final ScriptType scriptType;

  static Future showPopUp(BuildContext context, ScriptType scriptType) async {
    final import = context.read<ImportWalletCubit>();
    final wallet = import.state.getWalletDetails(scriptType);
    if (wallet == null) return;

    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: import,
        child: ImportWalletDetailsPopUp(
          wallet: wallet,
          scriptType: scriptType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = context.select(
      (ImportWalletCubit cubit) => cubit.state.walletName(scriptType),
    );

    return Padding(
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
              if (wallet.mnemonicFingerprint.isNotEmpty) ...[
                const BBText.body(
                  'Wallet fingerprint (XFP)',
                ),
                BBText.body(
                  wallet.mnemonicFingerprint,
                ),
                const Gap(16),
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
                  child: BBButton.big(
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
    );
  }
}
