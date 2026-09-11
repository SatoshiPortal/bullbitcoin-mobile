import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class ImportMethodWidget extends StatelessWidget {
  final SignerDeviceEntity? signerDevice;

  const ImportMethodWidget({super.key, this.signerDevice});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Gap(12),
        BBButton.big(
          label: context.loc.importWatchOnlyScanQR,
          onPressed: () async {
            final input = await context.pushNamed<String>(
              ImportWatchOnlyWalletRoutes.scan.name,
              extra: signerDevice,
            );
            if (input == null || !context.mounted) return;
            await context.read<ImportWatchOnlyCubit>().parseInput(
              input,
              signerDevice: signerDevice,
            );
          },
          iconData: Icons.qr_code_scanner,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
          outlined: true,
        ),
        const Gap(12),
      ],
    );
  }
}
