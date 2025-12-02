import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:bb_mobile/features/send/ui/screens/open_the_camera_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SendRecipientPage extends StatefulWidget {
  const SendRecipientPage({super.key, this.prefilledRecipient});

  final String? prefilledRecipient;

  @override
  State<SendRecipientPage> createState() => _SendRecipientPageState();
}

class _SendRecipientPageState extends State<SendRecipientPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.prefilledRecipient != null) {
      _controller.text = widget.prefilledRecipient!;
    }
    _controller.addListener(() {
      // Rebuild when text changes to update button state
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Unfocus to close keyboard before popping (optional, just looks nicer)
      FocusScope.of(context).unfocus();
      context.read<ArkCubit>().updateSendAddress(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // tap outside input to close keyboard
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.loc.arkSendRecipientTitle,
            style: context.font.headlineMedium,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: BlocSelector<ArkCubit, ArkState, bool>(
              selector: (state) => state.isLoading,
              builder:
                  (context, isLoading) =>
                      isLoading
                          ? FadingLinearProgress(
                            height: 3,
                            trigger: isLoading,
                            backgroundColor: context.colorScheme.surface,
                            foregroundColor: context.colorScheme.primary,
                          )
                          : const SizedBox(height: 3),
            ),
          ),
        ),
        backgroundColor: context.colorScheme.secondaryFixedDim,
        body: ScrollableColumn(
          padding: EdgeInsets.zero,
          children: [
            Expanded(
              child: OpenTheCameraWidget(
                onScannedPaymentRequest: (paymentRequest) {
                  _controller.text = paymentRequest.$1;
                  if (mounted) context.pop();
                },
              ),
            ),
            Form(
              key: _formKey,
              child: Card(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Gap(32),
                        Text(
                          context.loc.arkRecipientAddress,
                          style: context.font.bodyMedium,
                        ),
                        const Gap(16.0),
                        TextFormField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            fillColor: context.colorScheme.onPrimary,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(
                                color: context.colorScheme.secondaryFixedDim,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(
                                color: context.colorScheme.secondaryFixedDim,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(
                                color: context.colorScheme.secondaryFixedDim
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            hintText: context.loc.arkSendRecipientHint,
                            hintStyle: context.font.bodyMedium?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.paste_outlined,
                                color: context.colorScheme.secondary,
                              ),
                              onPressed: () {
                                Clipboard.getData(Clipboard.kTextPlain).then((
                                  value,
                                ) {
                                  if (value != null) {
                                    _controller.text = value.text ?? '';
                                    _formKey.currentState?.validate();
                                  }
                                });
                              },
                            ),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.loc.arkSendRecipientError;
                            }
                            return null;
                          },
                        ),
                        const Gap(32),
                        BlocSelector<ArkCubit, ArkState, ArkError?>(
                          selector: (state) => state.error,
                          builder: (context, error) {
                            return Center(
                              child: Text(
                                error?.message ?? '',
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                        const Gap(16),
                        BlocSelector<ArkCubit, ArkState, bool>(
                          selector: (state) => state.isLoading,
                          builder: (context, isLoading) {
                            return BBButton.big(
                              label: context.loc.arkContinueButton,
                              onPressed: _submit,
                              disabled: _controller.text.isEmpty || isLoading,
                              bgColor: context.colorScheme.secondary,
                              textColor: context.colorScheme.onSecondary,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
