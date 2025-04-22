// ignore_for_file: unused_field, use_late_for_private_fields_and_variables, use_build_context_synchronously, unused_element, deprecated_member_use

import 'package:bb_mobile/core/exchange/domain/usecases/get_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BullBitcoinWebViewPage extends StatefulWidget {
  const BullBitcoinWebViewPage({super.key});

  @override
  State<BullBitcoinWebViewPage> createState() => _BullBitcoinWebViewPageState();
}

class _BullBitcoinWebViewPageState extends State<BullBitcoinWebViewPage> {
  late final ExchangeCubit _exchangeCubit;

  @override
  void initState() {
    _exchangeCubit = ExchangeCubit(
      saveApiKeyUsecase: locator<SaveApiKeyUsecase>(),
      getApiKeyUsecase: locator<GetApiKeyUsecase>(),
      getUserSummaryUseCase: locator<GetUserSummaryUseCase>(),
    );

    super.initState();
  }

  @override
  void dispose() {
    _exchangeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _exchangeCubit,
      child: BlocListener<ExchangeCubit, ExchangeState>(
        listenWhen: (prev, curr) =>
            prev.showLoginSuccessDialog != curr.showLoginSuccessDialog,
        listener: (context, state) {
          if (state.showLoginSuccessDialog) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Login Successful'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 64),
                    SizedBox(height: 16),
                    Text('You are now logged in to Bull Bitcoin!'),
                    SizedBox(height: 8),
                    Text('You can return to the wallet now.'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
        child: const BullBitcoinWebView(),
      ),
    );
  }
}

class BullBitcoinWebView extends StatefulWidget {
  const BullBitcoinWebView({super.key});

  @override
  State<BullBitcoinWebView> createState() => _BullBitcoinWebViewState();
}

class _BullBitcoinWebViewState extends State<BullBitcoinWebView> {
  @override
  Widget build(BuildContext context) {
    final hasError =
        context.select((ExchangeCubit cubit) => cubit.state.hasError);
    final errorMessage =
        context.select((ExchangeCubit cubit) => cubit.state.errorMessage);

    final isLoading =
        context.select((ExchangeCubit cubit) => cubit.state.isLoading);

    final apiKeyGenerating =
        context.select((ExchangeCubit cubit) => cubit.state.apiKeyGenerating);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        flexibleSpace: const SizedBox.shrink(),
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (hasError)
              _ErrorView(
                message: errorMessage,
                onRetry: () => Navigator.of(context).pop(),
              )
            else
              WebViewWidget(
                  controller: context.read<ExchangeCubit>().webViewController),
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
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

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
