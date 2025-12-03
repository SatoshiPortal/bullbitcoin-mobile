import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class RequestIdentifierScreen extends StatelessWidget {
  const RequestIdentifierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.sendTitle,
          color: context.appColors.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocConsumer<RequestIdentifierCubit, RequestIdentifierState>(
        listener: (context, state) {
          if (state.redirect != null) {
            // switch (state.redirect) {
            // case RequestIdentifierRedirect.toSend:
            //   context.go('/send');
            //   break;
            // case RequestIdentifierRedirect.toNostr:
            //   context.go('/send');
            //   break;
            // }
          }
        },
        builder: (context, state) {
          final cubit = context.read<RequestIdentifierCubit>();

          return Stack(
            fit: .expand,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: QrScannerWidget(onScanned: cubit.onScanned),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.appColors.onPrimary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      mainAxisSize: .min,
                      children: [
                        const Gap(32),
                        BBText(
                          context.loc.sendRecipientAddressOrInvoice,
                          style: context.font.bodyMedium,
                        ),
                        const Gap(16),
                        const PasteRequestWidget(),
                        const Gap(16),
                        const RequestErrorWidget(),
                        const Gap(16),
                        const ContinueButtonWidget(),
                        const Gap(42),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PasteRequestWidget extends StatelessWidget {
  const PasteRequestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select<RequestIdentifierCubit, String>(
      (cubit) => cubit.state.rawRequest,
    );

    final cubit = context.read<RequestIdentifierCubit>();

    return BBInputText(
      onlyPaste: true,
      onChanged: cubit.updateRawRequest,
      value: address,
      hint: context.loc.sendPasteAddressOrInvoice,
      hintStyle: context.font.bodyLarge?.copyWith(
        color: context.appColors.surfaceContainer,
      ),
      maxLines: 1,
      rightIcon: Icon(
        Icons.paste_sharp,
        color: context.appColors.secondary,
        size: 20,
      ),
      onRightTap: () {
        Clipboard.getData(Clipboard.kTextPlain).then((value) {
          final clipboard = value?.text;
          if (clipboard == null) return;
          cubit.updateRawRequest(clipboard);
        });
      },
    );
  }
}

class RequestErrorWidget extends StatelessWidget {
  const RequestErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select(
      (RequestIdentifierCubit cubit) => cubit.state.error,
    );

    if (error.isNotEmpty) {
      return BBText(
        error,
        style: context.font.bodyMedium,
        color: context.appColors.error,
        textAlign: .center,
        maxLines: 2,
      );
    }
    return const SizedBox(height: 21);
  }
}

class ContinueButtonWidget extends StatelessWidget {
  const ContinueButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final hasRequest = context.select(
      (RequestIdentifierCubit cubit) => cubit.state.rawRequest.isNotEmpty,
    );
    final hasError = context.select(
      (RequestIdentifierCubit cubit) => cubit.state.error.isNotEmpty,
    );

    final cubit = context.read<RequestIdentifierCubit>();

    return BBButton.big(
      label: context.loc.sendContinue,
      onPressed: cubit.validatePaymentRequest,
      disabled: !hasRequest || hasError,
      bgColor: context.appColors.secondary,
      textColor: context.appColors.onPrimary,
    );
  }
}
