import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/dropdown/signer_device_dropdown.dart';
import 'package:bb_mobile/core/widgets/inputs/labeled_text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:satoshifier/enums/derivation.dart' as satoshifier;

class WatchOnlyDetailsWidget extends StatelessWidget {
  final WatchOnlyWalletEntity watchOnlyWallet;
  const WatchOnlyDetailsWidget({super.key, required this.watchOnlyWallet});

  @override
  Widget build(BuildContext context) {
    return switch (watchOnlyWallet) {
      WatchOnlyDescriptorEntity() => const _DescriptorDetailsWidget(),
      WatchOnlyXpubEntity() => const _XpubDetailsWidget(),
    };
  }
}

class _DescriptorDetailsWidget extends StatelessWidget {
  const _DescriptorDetailsWidget();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final watchOnlyWallet = context
        .watch<ImportWatchOnlyCubit>()
        .state
        .watchOnlyWallet;
    final entity = watchOnlyWallet! as WatchOnlyDescriptorEntity;

    return Column(
      crossAxisAlignment: .start,
      children: [
        LabeledTextInput(
          label: context.loc.walletDetailsNetworkLabel,
          value: entity.network == Network.bitcoinMainnet
              ? context.loc.walletNetworkBitcoin
              : context.loc.walletNetworkBitcoinTestnet,
          onChanged: null,
        ),
        const Gap(24),
        LabeledTextInput(
          label: context.loc.importWatchOnlyDescriptor,
          value: entity.descriptor,
          onChanged: null,
          maxLines: 5,
        ),
        if (entity.inferredChangePath) ...[
          const Gap(24),
          InfoCard(
            title: context.loc.importWatchOnlyChangePathTitle,
            description: context.loc.importWatchOnlyChangePathDescription,
            bgColor: context.appColors.warning.withValues(alpha: 0.1),
            tagColor: context.appColors.warning,
          ),
        ],
        if (entity.scriptType case final scriptType?) ...[
          const Gap(24),
          LabeledTextInput(
            label: context.loc.importWatchOnlyType,
            value: _derivationFor(scriptType).label,
            onChanged: null,
          ),
        ],
        const Gap(24),
        for (final (index, signer) in entity.signers.indexed) ...[
          if (index > 0) const Gap(16),
          _SignerDeviceField(
            signer: signer,
            index: index,
            onChanged: (device) =>
                cubit.onSignerDeviceChanged(signer.id, device),
          ),
        ],
        const Gap(24),
        LabeledTextInput(
          label: context.loc.importWatchOnlyLabel,
          hint: context.loc.importWatchOnlyRequired,
          value: entity.label,
          onChanged: cubit.updateLabel,
          maxLines: 1,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
        ),
        const Gap(24),
      ],
    );
  }
}

class _SignerDeviceField extends StatelessWidget {
  final WalletSigner signer;
  final int index;
  final ValueChanged<SignerDeviceEntity?> onChanged;

  const _SignerDeviceField({
    required this.signer,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fingerprint = signer.displayFingerprint;
    final label = fingerprint.isEmpty
        ? context.loc.walletSignerLabel(index + 1)
        : context.loc.walletSignerLabelWithFingerprint(index + 1, fingerprint);
    if (signer.signer == SignerEntity.local) {
      return LabeledTextInput(
        label: label,
        value: context.loc.importWatchOnlyBullMobileDevice,
        onChanged: null,
      );
    }

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        BBText(label, style: context.font.titleMedium),
        const Gap(8),
        SignerDeviceDropdown(
          key: ValueKey(signer.id),
          value: signer.signerDevice,
          unknownLabel: context.loc.importWatchOnlyUnknown,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _XpubDetailsWidget extends StatelessWidget {
  const _XpubDetailsWidget();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final watchOnlyWallet = context
        .watch<ImportWatchOnlyCubit>()
        .state
        .watchOnlyWallet;
    final entity = watchOnlyWallet! as WatchOnlyXpubEntity;
    final isXpub = entity.extendedPublicKey.startsWith('xpub');
    final usesStandardPrefix =
        isXpub || entity.extendedPublicKey.startsWith('tpub');
    final canSelectScriptType =
        usesStandardPrefix && entity.derivationPath == null;

    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          context.loc.importWatchOnlyExtendedPublicKey,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBText(entity.extendedPublicKey, style: context.font.bodyMedium),
        const Gap(24),
        if (!isXpub) ...[
          BBText(
            context.loc.importWatchOnlyXpubLabel,
            style: context.font.titleMedium,
          ),
          const Gap(8),
          BBText(entity.canonicalXpub, style: context.font.bodyMedium),
          const Gap(24),
        ],
        BBText(
          context.loc.importWatchOnlyType,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        if (!canSelectScriptType) ...[
          BBText(
            _derivationFor(entity.scriptType).label,
            style: context.font.bodyMedium,
          ),
          const Gap(24),
        ] else ...[
          InfoCard(
            title: context.loc.importWatchOnlyDisclaimerTitle,
            description: context.loc.importWatchOnlyDisclaimerDescription,
            bgColor: context.appColors.warning.withValues(alpha: 0.1),
            tagColor: context.appColors.warning,
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<satoshifier.Derivation>(
              alignment: Alignment.centerLeft,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: context.appColors.text,
              ),
              initialValue: _derivationFor(entity.scriptType),
              items: [...satoshifier.Derivation.values]
                  .map(
                    (value) => DropdownMenuItem<satoshifier.Derivation>(
                      value: value,
                      child: BBText(
                        'BIP${value.purpose} - ${value.label}',
                        style: context.font.headlineSmall,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: cubit.onDerivationChanged,
            ),
          ),
          const Gap(24),
        ],
        BBText(
          context.loc.importWatchOnlyLabel,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BullInputText(
          onChanged: cubit.updateLabel,
          value: entity.label,
          maxLines: 1,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}

satoshifier.Derivation _derivationFor(ScriptType scriptType) =>
    switch (scriptType) {
      ScriptType.bip84 => satoshifier.Derivation.bip84,
      ScriptType.bip49 => satoshifier.Derivation.bip49,
      ScriptType.bip44 => satoshifier.Derivation.bip44,
    };
