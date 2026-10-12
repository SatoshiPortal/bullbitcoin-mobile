import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/account_info.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/account_info_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/account_info_state.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_settings_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(title: Text(context.loc.exchangeAccountInfoTitle)),
      body: Column(
        children: [
          if (state.isLoading)
            LinearProgressIndicator(
              backgroundColor: context.appColors.surface,
              color: context.appColors.primary,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BBText(
              state.failure?.toTranslated(context) ??
                  context.loc.exchangeAccountInfoLoadErrorMessage,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
            const SizedBox(height: 16),
            BBButton.big(
              label: context.loc.retry,
              onPressed: () =>
                  context.read<AccountInfoCubit>().loadAccountInfo(),
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoUserNumberLabel,
              accountInfo.userNumber.toString(),
              isCopyable: true,
              copiedMessage:
                  context.loc.exchangeAccountInfoUserNumberCopiedMessage,
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoVerificationLevelLabel,
              _verificationLevelLabel(context, accountInfo.verificationLevel),
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoEmailLabel,
              accountInfo.email,
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoFirstNameLabel,
              accountInfo.firstName,
            ),
            const SizedBox(height: 32),
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
            BBText(
              label,
              style: context.font.headlineMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
                fontWeight: .w500,
              ),
            ),
            const Spacer(),
            if (isCopyable)
              Row(
                mainAxisSize: .min,
                children: [
                  BBText(
                    value,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.secondary,
                      fontWeight: .w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      SnackBarUtils.showSnackBar(context, copiedMessage ?? '');
                    },
                    child: Icon(
                      Icons.copy,
                      size: 18,
                      color: context.appColors.primary,
                    ),
                  ),
                ],
              )
            else
              BBText(
                value,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.secondary,
                  fontWeight: .w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 1,
          color: context.appColors.border,
        ),
      ],
    );
  }
}
