import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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

    if (state.isFetchingUserSummary) {
      return Scaffold(
        backgroundColor: context.colour.secondaryFixed,
        appBar: AppBar(title: const Text('Account information')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userSummary == null) {
      return Scaffold(
        backgroundColor: context.colour.secondaryFixed,
        appBar: AppBar(title: const Text('Account information')),

        body: Center(
          child: BBText(
            'Unable to load account information',
            style: context.font.bodyMedium,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colour.secondaryFixed,
      appBar: AppBar(title: const Text('Account information')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildInfoField(
                context,
                'User number',
                userSummary.userNumber.toString(),
                isCopyable: true,
              ),
              const SizedBox(height: 32),
              _buildInfoField(
                context,
                'Verification level',
                _getVerificationLevel(userSummary),
              ),
              const SizedBox(height: 32),
              _buildInfoField(context, 'Email', userSummary.email),
              const SizedBox(height: 32),
              _buildInfoField(
                context,
                'First name',
                userSummary.profile.firstName,
              ),
              const SizedBox(height: 32),
              _buildInfoField(
                context,
                'Last name',
                userSummary.profile.lastName,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVerificationLevel(UserSummary userSummary) {
    if (userSummary.isFullyVerifiedKycLevel) {
      return 'Identity verified';
    } else if (userSummary.isLightKycLevel) {
      return 'Light verification';
    } else if (userSummary.isLimitedKycLevel) {
      return 'Limited verification';
    } else {
      return 'Not verified';
    }
  }

  Widget _buildInfoField(
    BuildContext context,
    String label,
    String value, {
    bool isCopyable = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BBText(
              label,
              style: context.font.headlineMedium?.copyWith(
                color: context.colour.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isCopyable)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    value,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.colour.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      final theme = Theme.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const BBText(
                            'User number copied to clipboard',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: theme.colorScheme.onSurface
                              .withAlpha(204),
                          behavior: SnackBarBehavior.floating,
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
                      color: context.colour.primary,
                    ),
                  ),
                ],
              )
            else
              BBText(
                value,
                style: context.font.bodyLarge?.copyWith(
                  color: context.colour.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 1,
          color: context.colour.secondaryFixedDim,
        ),
      ],
    );
  }
}
