import 'package:bb_mobile/core/spark/spark.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/spark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SparkAboutPage extends StatelessWidget {
  const SparkAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SparkCubit>().state;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: TopBar(title: 'About', onBack: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _CopyField(label: 'Spark Address', value: state.receiveAddress),
            const SizedBox(height: 18),
            const _InfoField(label: 'Network', value: Spark.network),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    String displayValue;
    if (value is Enum) {
      displayValue = value.toString().split('.').last;
    } else {
      displayValue = value.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
          ),
        ),
        const Gap(4),
        BBText(
          displayValue,
          style: context.font.bodyMedium?.copyWith(
            color: context.colour.outline,
          ),
        ),
      ],
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
          ),
        ),
        const Gap(4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            BBText(
              value,
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.outline,
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    'Copy',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.colour.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
