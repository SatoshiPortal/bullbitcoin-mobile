import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/samrock/presentation/bloc/samrock_cubit.dart';
import 'package:bb_mobile/features/samrock/presentation/bloc/samrock_state.dart';
import 'package:bb_mobile/features/samrock/ui/samrock_confirmation_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SamrockSetupPage extends StatelessWidget {
  const SamrockSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SamrockCubit, SamrockState>(
      builder: (context, state) {
        return state.when(
          initial: () => _buildScannerView(context),
          parsed: (request) => _buildConfirmationView(context, state),
          loading: (request) => _buildLoadingView(context),
          success: (request, response) =>
              _buildSuccessView(context, request, response),
          error: (message, request) =>
              _buildErrorView(context, message, request),
        );
      },
    );
  }

  Widget _buildScannerView(BuildContext context) {
    final cubit = context.read<SamrockCubit>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(
            onScanned: cubit.parseUrl,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Center(
              child: BBText(
                'Scan SamRock QR Code',
                style: context.font.labelMedium,
                color: context.appColors.onPrimary,
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.02,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  CupertinoIcons.xmark_circle,
                  color: context.appColors.onPrimary,
                  size: 64,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationView(BuildContext context, SamrockState state) {
    final cubit = context.read<SamrockCubit>();
    final request = (state as SamrockParsed).request;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'SamRock Setup',
          onBack: () => cubit.reset(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SamrockConfirmationWidget(request: request),
            const Gap(24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: BBButton.big(
                      label: 'Cancel',
                      bgColor: context.appColors.surface,
                      textColor: context.appColors.text,
                      onPressed: () => cubit.reset(),
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: BBButton.big(
                      label: 'Confirm',
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      onPressed: cubit.confirmSetup,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: const TopBar(title: 'SamRock Setup'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            Gap(16),
            Text('Submitting wallet descriptors...'),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    dynamic request,
    dynamic response,
  ) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: const TopBar(title: 'SamRock Setup'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: context.appColors.primary,
              ),
              const Gap(16),
              BBText(
                'Setup Complete!',
                style: context.font.headlineMedium,
              ),
              const Gap(8),
              BBText(
                'Your BTCPay Server store is now configured to receive payments to your Bull Bitcoin wallet.',
                style: context.font.bodyMedium,
                color: context.appColors.textMuted,
                textAlign: TextAlign.center,
              ),
              const Gap(32),
              BBButton.big(
                label: 'Done',
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    String message,
    dynamic request,
  ) {
    final cubit = context.read<SamrockCubit>();
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'SamRock Setup',
          onBack: () => cubit.reset(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: context.appColors.error,
              ),
              const Gap(16),
              BBText(
                'Setup Failed',
                style: context.font.headlineMedium,
              ),
              const Gap(8),
              BBText(
                message,
                style: context.font.bodyMedium,
                color: context.appColors.error,
                textAlign: TextAlign.center,
              ),
              const Gap(32),
              if (request != null)
                BBButton.big(
                  label: 'Try Again',
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                  onPressed: cubit.confirmSetup,
                ),
              const Gap(16),
              BBButton.big(
                label: 'Scan Again',
                bgColor: context.appColors.surface,
                textColor: context.appColors.text,
                onPressed: () => cubit.reset(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
