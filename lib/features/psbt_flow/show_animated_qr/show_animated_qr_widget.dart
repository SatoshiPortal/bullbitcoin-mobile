import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_cubit.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShowAnimatedQrWidget extends StatelessWidget {
  final String psbt;
  final QrType qrType;
  final bool showSlider;

  const ShowAnimatedQrWidget({
    super.key,
    required this.psbt,
    required this.qrType,
    this.showSlider = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShowAnimatedQrCubit(psbt: psbt, qrType: qrType),
      child: _ShowAnimatedQrView(
        showSlider: showSlider,
      ),
    );
  }
}

class _ShowAnimatedQrView extends StatefulWidget {
  final bool showSlider;

  const _ShowAnimatedQrView({
    required this.showSlider,
  });

  @override
  State<_ShowAnimatedQrView> createState() => _ShowAnimatedQrViewState();
}

class _ShowAnimatedQrViewState extends State<_ShowAnimatedQrView> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debouncedCallback(int fragmentLength) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      context.read<ShowAnimatedQrCubit>().updateFragmentLength(fragmentLength);
    });
  }


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShowAnimatedQrCubit, ShowAnimatedQrState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state.error != null) {
          return Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                context.loc.psbtFlowError(state.error!),
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.error,
                ),
              ),
            ),
          );
        }

        if (state.parts.isEmpty) {
          return Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                context.loc.psbtFlowNoPartsToDisplay,
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.error,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              QrImageView(data: state.parts[state.currentIndex]),
              const Gap(16),
              if (widget.showSlider) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Builder(
                    builder: (context) {
                      final currentValue = state.fragmentLength.toDouble().clamp(25.0, 200.0);
                      
                      return Slider(
                        value: currentValue,
                        min: 25.0,
                        max: 200.0,
                        activeColor: context.colour.secondary,
                        inactiveColor: context.colour.surfaceContainer,
                        onChanged: (value) {
                          final newFragmentLength = value.round();
                          context.read<ShowAnimatedQrCubit>().updateFragmentLength(
                            newFragmentLength,
                          );
                          _debouncedCallback(newFragmentLength);
                        },
                      );
                    },
                  ),
                ),
                const Gap(16),
              ],

              if (state.parts.length > 1) ...[
                BBText(
                  context.loc.psbtFlowPartProgress((state.currentIndex + 1).toString(), state.parts.length.toString()),
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.secondary,
                  ),
                ),
                const Gap(8),
              ],
            ],
          ),
        );
      },
    );
  }
}
