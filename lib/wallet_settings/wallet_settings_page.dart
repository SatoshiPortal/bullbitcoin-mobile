import 'dart:async';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/addresses.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/listeners.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletSettingsPage extends StatelessWidget {
  const WalletSettingsPage({
    super.key,
    required this.walletBloc,
    // this.openTestBackup = false,
    this.openBackup = false,
  });

  // final bool openTestBackup;
  final bool openBackup;
  final WalletBloc walletBloc;

  @override
  Widget build(BuildContext context) {
    // final wallet = home.state.selectedWalletCubit!;
    final walletSettings = WalletSettingsCubit(
      wallet: walletBloc.state.wallet!,
      // walletRead: locator<WalletSync>(),
      walletBloc: walletBloc,
      fileStorage: locator<FileStorage>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      walletSensRepository: locator<WalletSensitiveStorageRepository>(),
      homeCubit: locator<HomeCubit>(),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: walletBloc),
        BlocProvider.value(value: walletSettings),
      ],
      child: WalletSettingsListeners(
        child: _Screen(
          // openTestBackup: openTestBackup,
          openBackup: openBackup,
        ),
      ),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen({required this.openBackup});

  // final bool openTestBackup;
  final bool openBackup;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  // bool showPage = false;
  @override
  void initState() {
    _init();
    super.initState();
  }

  void _init() {
    scheduleMicrotask(() async {
      if (widget.openBackup) {
        print('----1');
        // await Future.delayed(const Duration(milliseconds: 300));
        await context.push(
          '/wallet-settings/backup',
          extra: (
            context.read<WalletBloc>(),
            context.read<WalletSettingsCubit>(),
          ),
        );
      } else {
        print('----2');

        // showPage = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final watchOnly = context
        .select((WalletSettingsCubit cubit) => cubit.state.wallet.watchOnly());

    // if (!showPage) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: const ApppBar(),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(16),
            const WalletName(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(16),
                  const WalletType(),
                  // const Gap(16),
                  // const Balances(),
                  const Gap(24),
                  if (!watchOnly) ...[
                    const BackupButton(),
                    const Gap(8),
                    // const TestBackupButton(),
                    // const Gap(8),
                  ],
                  // const PublicDescriptorButton(),
                  // const Gap(8),
                  // const ExtendedPublicKeyButton(),
                  // const Gap(8),
                  const WalletDetailsButton(),
                  const Gap(8),
                  const AddressesButtons(),
                  const Gap(8),

                  const AccountingButton(),
                  const Gap(8),
                  const LabelActions(),
                  // const LabelsExportButton(),
                  // const Gap(8),
                  // const LabelsImportButton(),
                  const Gap(8),
                  const DeleteButton(),
                  const Gap(24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApppBar extends StatelessWidget {
  const ApppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final walletName = context.select(
      (WalletSettingsCubit cubit) => cubit.state.wallet.name,
    );

    final fingerPrint = context.select(
      (WalletSettingsCubit cubit) => cubit.state.wallet.sourceFingerprint,
    );

    return BBAppBar(
      onBack: () {
        context.pop();
      },
      text: walletName ?? fingerPrint,
    );
  }
}

class WalletName extends StatefulWidget {
  const WalletName({super.key});

  @override
  State<WalletName> createState() => _WalletNameState();
}

class _WalletNameState extends State<WalletName> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final mainWallet =
        context.select((WalletBloc x) => x.state.wallet!.mainWallet);
    if (mainWallet) return const SizedBox.shrink();

    final saving = context.select(
      (WalletSettingsCubit x) => x.state.savingName,
    );

    final text = context.select(
      (WalletSettingsCubit x) => x.state.name,
    );
    if (text != _controller.text) _controller.text = text;

    final name = context.select(
      (WalletSettingsCubit x) => x.state.wallet.name,
    );

    final showSave = text.isNotEmpty && name != text;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          Expanded(
            child: BBTextInput.small(
              onChanged: (txt) {
                context.read<WalletSettingsCubit>().changeName(txt);
              },
              value: text,
              hint: name ?? 'Enter name',
            ),
          ),
          const Gap(8),
          if (!saving)
            SizedBox(
              width: 88,
              height: 40,
              child: BBButton.big(
                disabled: !showSave,
                label: 'SAVE',
                onPressed: () {
                  context.read<WalletSettingsCubit>().saveNameClicked();
                },
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class WalletType extends StatelessWidget {
  const WalletType({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (WalletSettingsCubit x) => x.state.wallet.getWalletTypeString(),
    );
    final scriptType =
        context.select((WalletSettingsCubit x) => x.state.wallet.scriptType);
    final _ = scriptTypeString(scriptType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Type'),
        const Gap(4),
        BBText.titleLarge(
          type,
          isBold: true,
        ),
      ],
    );
  }
}

class Balances extends StatelessWidget {
  const Balances({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc cubit) => cubit.state.wallet!);

    final amtSent = wallet.totalSent();

    final amtReceived = wallet.totalReceived();

    final inAmt = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(amtReceived, removeText: true),
    );

    final outAmt = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(amtSent, removeText: true),
    );

    final units = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: wallet.isLiquid()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Total amount received'),
        const Gap(4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(
                  1,
                ),
              child: const FaIcon(
                FontAwesomeIcons.arrowRight,
              ),
            ),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(
                  inAmt,
                  isBold: true,
                ),
              ],
            ),
            const Gap(4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: BBText.title(
                units,
                isBold: true,
              ),
            ),
          ],
        ),
        const Gap(16),
        const BBText.title('Total amount sent'),
        const Gap(4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(
                  -1,
                ),
              child: const FaIcon(
                FontAwesomeIcons.arrowRight,
              ),
            ),
            const Gap(16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(
                  outAmt,
                  isBold: true,
                ),
              ],
            ),
            const Gap(4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: BBText.title(
                units,
                isBold: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AddressesButtons extends StatelessWidget {
  const AddressesButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Addresses',
      onPressed: () {
        AddressesScreen.openPopup(context);
      },
    );
  }
}

class AccountingButton extends StatelessWidget {
  const AccountingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Accounting',
      onPressed: () {
        final walletBloc = context.read<WalletBloc>();
        context.push('/wallet-settings/accounting', extra: walletBloc);
      },
    );
  }
}

class WalletDetailsButton extends StatelessWidget {
  const WalletDetailsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      label: 'Wallet Details',
      onPressed: () {
        final walletBloc = context.read<WalletBloc>();
        context.push('/wallet/details', extra: walletBloc);
      },
    );
  }
}

class TestBackupButton extends StatelessWidget {
  const TestBackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isTested =
        context.select((WalletBloc x) => x.state.wallet!.backupTested);

    // if (isTested) return const SizedBox.shrink();
    return BBButton.textWithStatusAndRightArrow(
      label: 'Test Backup',
      statusText: isTested ? 'Tested' : 'Not Tested',
      isRed: !isTested,
      onPressed: () async {
        context.push(
          '/wallet-settings/test-backup',
          extra: (
            context.read<WalletBloc>(),
            context.read<WalletSettingsCubit>(),
          ),
        );
        // await TestBackupScreen.openPopup(context);
      },
    );
    // return Row(
    //   children: [
    //     BBButton.textWithLeftArrow(
    //       label: 'Test Backup',
    //       onPressed: () async {
    //         await TestBackupScreen.openPopup(context);
    //       },
    //     ),
    //     const Spacer(),
    //     BBText.body(
    //       isTested ? 'Tested' : 'Not tested',
    //       isGreen: isTested,
    //       isRed: !isTested,
    //     ),
    //   ],
    // );
  }
}

class BackupButton extends StatelessWidget {
  const BackupButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isTested =
        context.select((WalletBloc x) => x.state.wallet!.backupTested);

    return BBButton.textWithStatusAndRightArrow(
      onPressed: () async {
        context.push(
          '/wallet-settings/backup',
          extra: (
            context.read<WalletBloc>(),
            context.read<WalletSettingsCubit>(),
          ),
        );
        // await BackupScreen.openPopup(context);
      },
      label: 'Backup',
      statusText: isTested ? 'Tested' : 'Not Tested',
      isRed: !isTested,
    );
  }
}

class DeleteButton extends StatelessWidget {
  const DeleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CenterLeft(
      child: BBButton.text(
        isRed: true,
        onPressed: () {
          DeletePopUp.openPopUp(context);
        },
        label: 'Delete Wallet',
      ),
    );
  }
}

class DeletePopUp extends StatelessWidget {
  const DeletePopUp({super.key});

  static Future openPopUp(BuildContext context) {
    final settings = context.read<WalletSettingsCubit>();

    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
        ],
        child: BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) =>
              previous.deleted != current.deleted,
          listener: (context, state) {
            if (state.deleted) {
              // final walletBloc = settings.walletBloc;
              // context.read<HomeCubit>().clearWallet(walletBloc);
              context.go('/home');
            }
          },
          child: const DeletePopUp(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(32),
        const BBText.body(
          'Delete wallet',
        ),
        const Gap(24),
        const BBText.body(
          'Are you sure you want to delete this wallet?',
          textAlign: TextAlign.center,
        ),
        const Gap(40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: BBButton.text(
                  onPressed: () {
                    context.pop();
                  },
                  label: 'Cancel',
                  centered: true,
                ),
              ),
              Expanded(
                child: BBButton.big(
                  filled: true,
                  onPressed: () {
                    context.read<WalletSettingsCubit>().deleteWalletClicked();
                  },
                  label: 'Delete',
                ),
              ),
            ],
          ),
        ),
        const Gap(40),
      ],
    );
  }
}

// class LabelsExportButton extends StatelessWidget {
//   const LabelsExportButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return CenterLeft(
//       child: BBButton.text(
//         onPressed: () {
//           context.read<WalletSettingsCubit>().exportLabelsClicked();
//         },
//         label: 'Export Labels',
//       ),
//     );
//   }
// }

// class LabelsImportButton extends StatelessWidget {
//   const LabelsImportButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return CenterLeft(
//       child: BBButton.text(
//         onPressed: () {
//           context.read<WalletSettingsCubit>().importLabelsClicked();
//         },
//         label: 'Import Labels',
//       ),
//     );
//   }
// }

// class LabelsImportPopup extends StatelessWidget {
//   const LabelsImportPopup({super.key});

//   static Future openPopUp(BuildContext context) {
//     final settings = context.read<WalletSettingsCubit>();

//     return showMddaterialModalBottomSheet(
//       context: context,
//       isDismissible: false,
//       enableDrag: false,
//       backgroundColor: Colors.transparent,
//       builder: (context) => MultiBlocProvider(
//         providers: [
//           BlocProvider.value(value: settings),
//         ],
//         child: const PopUpBorder(
//           child: LabelsImportButton(),
//         ),
//       ),
//       // ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         const Gap(32),
//         const BBText.body(
//           'Import Labels',
//         ),
//         const Gap(24),
//         const BBText.body(
//           'Importing labels will override existing labels. Continue?',
//           textAlign: TextAlign.center,
//         ),
//         const Gap(40),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               Expanded(
//                 child: BBButton.text(
//                   onPressed: () {
//                     context.pop();
//                   },
//                   label: 'Cancel',
//                   centered: true,
//                 ),
//               ),
//               Expanded(
//                 child: BBButton.big2(
//                   filled: true,
//                   onPressed: () {
//                     context.read<WalletSettingsCubit>().importLabelsClicked();
//                   },
//                   label: 'Import',
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const Gap(40),
//       ],
//     );
//   }
// }

class LabelSettingPopup extends StatelessWidget {
  const LabelSettingPopup({super.key});

  static Future openPopUp(BuildContext context) {
    final settings = context.read<WalletSettingsCubit>();

    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
        ],
        child: BlocListener<WalletSettingsCubit, WalletSettingsState>(
          listenWhen: (previous, current) =>
              previous.exported != current.exported ||
              previous.imported != current.imported,
          listener: (context, state) async {
            if (state.exported || state.imported) {
              await Future.delayed(1.seconds);
              context.pop();
            }
          },
          child: const LabelSettingPopup(),
        ),
      ),
      // ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final importing =
        context.select((WalletSettingsCubit x) => x.state.importing);
    final exporting =
        context.select((WalletSettingsCubit x) => x.state.exporting);
    final errImporting =
        context.select((WalletSettingsCubit x) => x.state.errImporting);
    final errExporting =
        context.select((WalletSettingsCubit x) => x.state.errExporting);
    final imported =
        context.select((WalletSettingsCubit x) => x.state.imported);
    final exported =
        context.select((WalletSettingsCubit x) => x.state.exported);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBHeader.popUpCenteredText(
            text: 'Import / Export Labels',
            isLeft: true,
            onBack: () {
              context.pop();
            },
          ),
          const Gap(24),
          const BBText.bodySmall(
            'Importing labels will override existing wallet labels.',
          ),
          const Gap(8),
          AnimatedSwitcher(
            duration: 300.ms,
            child: () {
              if (importing)
                return const CenterLeft(child: CircularProgressIndicator());
              else if (errImporting.isNotEmpty)
                return BBText.error(errImporting);
              else if (imported)
                return const FaIcon(
                  FontAwesomeIcons.circleCheck,
                  color: Colors.green,
                );
              else
                return BBButton.text(
                  label: 'Import',
                  onPressed: () {
                    context.read<WalletSettingsCubit>().importLabelsClicked();
                  },
                );
            }(),
          ),
          const Gap(40),
          const BBText.bodySmall(
            'Exporting labels will create a backup file or overwrite an existing file.',
          ),
          const Gap(8),
          AnimatedSwitcher(
            duration: 300.ms,
            child: () {
              if (exporting)
                return const CenterLeft(child: CircularProgressIndicator());
              else if (errExporting.isNotEmpty)
                return BBText.error(errExporting);
              else if (exported)
                return const FaIcon(
                  FontAwesomeIcons.circleCheck,
                  color: Colors.green,
                );
              else
                return BBButton.text(
                  label: 'Export',
                  onPressed: () {
                    context.read<WalletSettingsCubit>().exportLabelsClicked();
                  },
                );
            }(),
          ),
          const Gap(40),
        ],
      ),
    );
  }
}

class LabelActions extends StatelessWidget {
  const LabelActions({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.textWithStatusAndRightArrow(
      onPressed: () async {
        await LabelSettingPopup.openPopUp(context);
      },
      label: 'Import / Export Labels',
    );
  }
}
