import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/derive_vault_key_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_failure_l10n.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScaffold, BullSpacing, BullText, Gap;
import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Reads the key internally; neither a route nor a cubit receives it.
class LocalVaultKeyPage extends StatefulWidget {
  const LocalVaultKeyPage({super.key});

  @override
  State<LocalVaultKeyPage> createState() => _LocalVaultKeyPageState();
}

class _LocalVaultKeyPageState extends State<LocalVaultKeyPage>
    with PrivacyScreen {
  Future<Result<String, RecoverBullFailure>>? _key;

  Future<Result<String, RecoverBullFailure>> _load() async {
    await enableScreenPrivacy();
    if (!mounted) return const Err(VaultSeedUnavailableFailure());
    return locator<DeriveVaultKeyUsecase>().execute();
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BullScaffold(
    appBar: AppBar(title: Text(context.loc.recoverbullVaultKey)),
    body: SafeArea(
      child: FutureBuilder<Result<String, RecoverBullFailure>>(
        future: _key,
        builder: (context, snapshot) {
          final busy =
              _key != null && snapshot.connectionState != ConnectionState.done;
          return ListView(
            padding: const EdgeInsets.all(BullSpacing.lg),
            children: [
              BullText(
                context.loc.recoverbullKeyLocalInstructions,
                style: context.font.bodyMedium,
              ),
              const Gap(BullSpacing.lg),
              if (busy)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                BullText(
                  context.loc.recoverbullErrorUnexpected,
                  style: context.font.bodyMedium,
                )
              else if (snapshot.data case final result?)
                switch (result) {
                  Err(:final failure) => BullText(
                    failure.toTranslated(context),
                    style: context.font.bodyMedium,
                  ),
                  Ok(:final value) => ExcludeSemantics(
                    child: CopyInput(text: value),
                  ),
                },
              const Gap(BullSpacing.lg),
              BullButton.big(
                label: context.loc.recoverbullKeyChooseFile,
                onPressed: () => setState(() {
                  _key = _load();
                }),
                disabled: busy,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
              const Gap(BullSpacing.sm),
              BullButton.big(
                label: context.loc.recoverbullKeyUseServer,
                onPressed: () => openRecoverBullFlow(
                  context,
                  flow: RecoverBullFlow.viewVaultKey,
                ),
                disabled: busy,
                outlined: true,
                bgColor: context.appColors.surface,
                textColor: context.appColors.secondary,
              ),
            ],
          );
        },
      ),
    ),
  );
}
