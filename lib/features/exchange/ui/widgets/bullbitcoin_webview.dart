// ignore_for_file: unused_field, use_late_for_private_fields_and_variables, use_build_context_synchronously, unused_element, deprecated_member_use

import 'package:bb_mobile/features/exchange/presentation/exchange_home_cubit.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BullbitcoinWebview extends StatelessWidget {
  const BullbitcoinWebview({super.key});

  @override
  Widget build(BuildContext context) {
    final hasError = context.select(
      (ExchangeHomeCubit cubit) => cubit.state.hasError,
    );
    final errorMessage = context.select(
      (ExchangeHomeCubit cubit) => cubit.state.errorMessage,
    );

    final isLoading = context.select(
      (ExchangeHomeCubit cubit) => cubit.state.isLoading,
    );

    final apiKeyGenerating = context.select(
      (ExchangeHomeCubit cubit) => cubit.state.apiKeyGenerating,
    );

    return SafeArea(
      child: Stack(
        children: [
          if (hasError)
            _ErrorView(
              message: errorMessage,
              onRetry: () => Navigator.of(context).pop(),
            )
          else
            Builder(
              builder: (context) {
                final controller =
                    context.read<ExchangeHomeCubit>().webViewController;
                if (controller == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return WebViewWidget(controller: controller);
              },
            ),
          if (isLoading && !hasError) const SizedBox.shrink(),
          if (apiKeyGenerating)
            ColoredBox(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Generating API key...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    /*

    return BlocProvider.value(
      value: _exchangeCubit,
      child: BlocListener<ExchangeCubit, ExchangeState>(
        listenWhen:
            (prev, curr) =>
                prev.showLoginSuccessDialog != curr.showLoginSuccessDialog &&
                curr.showLoginSuccessDialog,
        listener: (context, state) {
          // TODO: MOVE THIS TO THE BLOC WHEN LOGIN IS SUCCESSFUL
          context.read<HomeBloc>().add(const GetUserDetails());
        },
        child: const BullBitcoinWebView(),
      ),
    );*/
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const BBText(
              'Error loading Bull Bitcoin Exchange',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            BBText(message, style: TextStyle(color: context.colour.onError)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: BBText(
                'Go Back',
                style: TextStyle(color: context.colour.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
