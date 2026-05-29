import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ExportTransactionsScreen extends StatefulWidget {
  const ExportTransactionsScreen({super.key});

  @override
  State<ExportTransactionsScreen> createState() =>
      _ExportTransactionsScreenState();
}

class _ExportTransactionsScreenState extends State<ExportTransactionsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2009),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String _formatDate(DateTime date) =>
      MaterialLocalizations.of(context).formatShortDate(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: context.loc.transactionHistoryTitle,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child:
              BlocSelector<
                ExportTransactionsCubit,
                ExportTransactionsState,
                bool
              >(
                selector: (state) =>
                    state.maybeMap(loading: (_) => true, orElse: () => false),
                builder: (context, isLoading) => FadingLinearProgress(
                  height: 3,
                  trigger: isLoading,
                  backgroundColor: context.appColors.onPrimary,
                  foregroundColor: context.appColors.primary,
                ),
              ),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<ExportTransactionsCubit, ExportTransactionsState>(
          listener: (context, state) {
            state.mapOrNull(
              success: (_) => SnackBarUtils.showSnackBar(
                context,
                context.loc.exportTransactionsSuccess,
              ),
              noTransactions: (_) => SnackBarUtils.showSnackBar(
                context,
                context.loc.exportTransactionsEmpty,
              ),
              invalidDateRange: (_) => SnackBarUtils.showSnackBar(
                context,
                context.loc.exportTransactionsInvalidDateRange,
              ),
              error: (_) => SnackBarUtils.showSnackBar(
                context,
                context.loc.exportTransactionsError,
              ),
            );
          },
          builder: (context, state) {
            final cubit = context.read<ExportTransactionsCubit>();
            final isLoading = state.maybeMap(
              loading: (_) => true,
              orElse: () => false,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Gap(20),
                        BBText(
                          context.loc.transactionHistoryHeading,
                          style: context.font.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const Gap(16),
                        BBText(
                          context.loc.exportTransactionsDescription,
                          style: context.font.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const Gap(32),
                        _DateField(
                          label: context.loc.exportTransactionsStartDate,
                          value: _startDate == null
                              ? null
                              : _formatDate(_startDate!),
                          onTap: () => _pickDate(isStart: true),
                          onClear: _startDate == null
                              ? null
                              : () => setState(() => _startDate = null),
                        ),
                        const Gap(12),
                        _DateField(
                          label: context.loc.exportTransactionsEndDate,
                          value: _endDate == null
                              ? null
                              : _formatDate(_endDate!),
                          onTap: () => _pickDate(isStart: false),
                          onClear: _endDate == null
                              ? null
                              : () => setState(() => _endDate = null),
                        ),
                        const Gap(32),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                  child: BBButton.big(
                    label: context.loc.exportTransactionsButton,
                    onPressed: () async {
                      if (isLoading) return;
                      await cubit.exportCsv(start: _startDate, end: _endDate);
                    },
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                    iconData: Icons.file_download,
                    iconFirst: true,
                    disabled: isLoading,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today)
              : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: BBText(
          value ?? context.loc.exportTransactionsAnyDate,
          style: context.font.bodyLarge,
        ),
      ),
    );
  }
}
