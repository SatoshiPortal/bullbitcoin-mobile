import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeAccountInfoScreen extends StatelessWidget {
  const ExchangeAccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((ExchangeCubit cubit) => cubit.state);
    final userSummary = state.userSummary;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(title: Text(context.loc.exchangeAccountInfoTitle)),
      body: Column(
        children: [
          if (state.isFetchingUserSummary)
            LinearProgressIndicator(
              backgroundColor: context.appColors.surface,
              color: context.appColors.primary,
            ),
          Expanded(
            child: _buildContent(context, state.isFetchingUserSummary, userSummary),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isLoading, UserSummary? userSummary) {
    if (isLoading && userSummary == null) {
      return const SizedBox.shrink();
    }

    if (userSummary == null) {
      return Center(
        child: BBText(
          context.loc.exchangeAccountInfoLoadErrorMessage,
          style: context.font.bodyMedium,
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
              userSummary.userNumber.toString(),
              isCopyable: true,
              copiedMessage: context.loc.exchangeAccountInfoUserNumberCopiedMessage,
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoVerificationLevelLabel,
              _getVerificationLevel(context, userSummary),
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoEmailLabel,
              userSummary.email,
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoFirstNameLabel,
              userSummary.profile.firstName,
            ),
            const SizedBox(height: 32),
            _buildInfoField(
              context,
              context.loc.exchangeAccountInfoLastNameLabel,
              userSummary.profile.lastName,
            ),
          ],
        ),
      ),
    );
  }

  String _getVerificationLevel(BuildContext context, UserSummary userSummary) {
    if (userSummary.isFullyVerifiedKycLevel) {
      return context.loc.exchangeAccountInfoVerificationIdentityVerified;
    } else if (userSummary.isLightKycLevel) {
      return context.loc.exchangeAccountInfoVerificationLightVerification;
    } else if (userSummary.isLimitedKycLevel) {
      return context.loc.exchangeAccountInfoVerificationLimitedVerification;
    } else {
      return context.loc.exchangeAccountInfoVerificationNotVerified;
    }
  }

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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: BBText(
                            copiedMessage ?? '',
                            textAlign: .center,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.appColors.surfaceFixed,
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: context.appColors.onSurface
                              .withAlpha(204),
                          behavior: .floating,
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 80,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
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
