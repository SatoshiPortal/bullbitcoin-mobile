import 'package:exchange/exchange.dart';

import '../../../exchange_l10n.dart';
import '../../domain/entities/account_info.dart';
import '../../presentation/account_info_cubit.dart';
import '../../presentation/account_info_state.dart';

import 'package:bull_exchange/src/presentation/exchange_failure_l10n.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AccountInfoCubit>().loadAccountInfo();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AccountInfoCubit>().state;

    return BullScaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.exchangeAccountInfoTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          BullFadingLinearProgress(
            trigger: state.isLoading,
            backgroundColor: context.bull.surface,
            foregroundColor: context.bull.primary,
          ),
          Expanded(child: _buildContent(context, state)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AccountInfoState state) {
    final accountInfo = state.accountInfo;

    if (state.isLoading && accountInfo == null) {
      return const SizedBox.shrink();
    }

    if (accountInfo == null) {
      // A retry can't help once the session ended (SET-3).
      final signedOut = state.failure is ExchangeNotAuthenticatedFailure;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BullText(
              signedOut
                  ? context.loc.exchangeSettingsSignedOut
                  : state.failure?.toTranslated(context) ??
                        context.loc.exchangeAccountInfoLoadErrorMessage,
              style: context.bullType.body.copyWith(color: context.bull.error),
            ),
            if (!signedOut) ...[
              const Gap(BullSpacing.md),
              BullButton.secondary(
                label: context.loc.retry,
                onPressed: () =>
                    context.read<AccountInfoCubit>().loadAccountInfo(),
              ),
            ],
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(BullSpacing.sm),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoUserNumberLabel,
              accountInfo.userNumber.toString(),
              isCopyable: true,
              copiedMessage:
                  context.loc.exchangeAccountInfoUserNumberCopiedMessage,
            ),
            const Gap(BullSpacing.xl),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoVerificationLevelLabel,
              _verificationLevelLabel(context, accountInfo.verificationLevel),
            ),
            const Gap(BullSpacing.xl),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoEmailLabel,
              accountInfo.email,
            ),
            const Gap(BullSpacing.xl),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoFirstNameLabel,
              accountInfo.firstName,
            ),
            const Gap(BullSpacing.xl),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoLastNameLabel,
              accountInfo.lastName,
            ),
          ],
        ),
      ),
    );
  }

  String _verificationLevelLabel(
    BuildContext context,
    VerificationLevel level,
  ) => switch (level) {
    VerificationLevel.identityVerified =>
      context.loc.exchangeAccountInfoVerificationIdentityVerified,
    VerificationLevel.light =>
      context.loc.exchangeAccountInfoVerificationLightVerification,
    VerificationLevel.limited =>
      context.loc.exchangeAccountInfoVerificationLimitedVerification,
    VerificationLevel.notVerified =>
      context.loc.exchangeAccountInfoVerificationNotVerified,
  };

  Widget _buildInfoField(
    BuildContext context,
    String label,
    String value, {
    bool isCopyable = false,
    String? copiedMessage,
  }) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            BullText(
              label,
              style: context.bullType.subtitle
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(
                    color: context.bull.onSurfaceVariant,
                    fontWeight: .w500,
                  ),
            ),
            const Spacer(),
            if (isCopyable)
              Row(
                mainAxisSize: .min,
                children: [
                  BullText(
                    value,
                    style: context.bullType.body
                        .copyWith(fontWeight: FontWeight.w500)
                        .copyWith(
                          color: context.bull.secondary,
                          fontWeight: .w700,
                        ),
                  ),
                  const Gap(BullSpacing.xs),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      BullSnackBar.show(context, message: copiedMessage ?? '');
                    },
                    child: BullIcon(
                      BullIcons.contentCopy,
                      size: 18,
                      color: context.bull.primary,
                    ),
                  ),
                ],
              )
            else
              BullText(
                value,
                style: context.bullType.body
                    .copyWith(fontWeight: FontWeight.w500)
                    .copyWith(color: context.bull.secondary, fontWeight: .w700),
              ),
          ],
        ),
        const Gap(BullSpacing.sm),
        Container(
          width: double.infinity,
          height: 1,
          color: context.bull.border,
        ),
      ],
    );
  }
}
