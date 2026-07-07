import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/public/invoices_routes.dart';
import 'package:bb_mobile/features/invoices/ui/widgets/invoice_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// The invoices list (ISS-C-05 legacy `core/widgets`). Status chips filter the
/// loaded set CLIENT-SIDE; a New button opens the create flow and refreshes on
/// return; tapping a row opens the detail.
class InvoicesListScreen extends StatelessWidget {
  const InvoicesListScreen({super.key});

  static const _filters = <InvoiceStatus?>[
    null,
    InvoiceStatus.unpaid,
    InvoiceStatus.paid,
    InvoiceStatus.expired,
    InvoiceStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.invoicesListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.loc.invoicesCreateButton,
            onPressed: () => _openCreate(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<InvoicesListCubit, InvoicesListState>(
          builder: (context, state) => switch (state.status) {
            InvoicesListStatus.initial ||
            InvoicesListStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            InvoicesListStatus.error => _error(context),
            InvoicesListStatus.loaded => _loaded(context, state),
          },
        ),
      ),
    );
  }

  Widget _error(BuildContext context) {
    final cubit = context.read<InvoicesListCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.appColors.error),
            const Gap(16),
            Text(
              context.read<InvoicesListCubit>().state.failure?.toTranslated(
                    context,
                  ) ??
                  context.loc.invoiceErrorUnexpected,
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            BBButton.big(
              label: context.loc.invoicesRetryButton,
              iconData: Icons.refresh,
              iconFirst: true,
              onPressed: cubit.load,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _loaded(BuildContext context, InvoicesListState state) {
    final cubit = context.read<InvoicesListCubit>();
    return Column(
      children: [
        _filterBar(context, state, cubit),
        Expanded(
          child: state.isEmpty
              ? _empty(context)
              : RefreshIndicator(
                  onRefresh: cubit.refresh,
                  child: ListView.separated(
                    itemCount: state.visibleInvoices.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final invoice = state.visibleInvoices[index];
                      return InvoiceListItem(
                        invoice: invoice,
                        onTap: () => _openDetail(context, invoice),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterBar(
    BuildContext context,
    InvoicesListState state,
    InvoicesListCubit cubit,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final filter in _filters) ...[
            ChoiceChip(
              label: Text(
                filter == null
                    ? context.loc.invoicesFilterAll
                    : invoiceStatusText(context, filter),
              ),
              selected: state.filter == filter,
              onSelected: (_) => cubit.setFilter(filter),
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(48),
        Icon(
          Icons.receipt_long,
          size: 56,
          color: context.appColors.textMuted,
        ),
        const Gap(16),
        Text(
          context.loc.invoicesEmptyTitle,
          textAlign: TextAlign.center,
          style: context.font.titleLarge,
        ),
        const Gap(8),
        Text(
          context.loc.invoicesEmptyBody,
          textAlign: TextAlign.center,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.invoicesCreateButton,
          onPressed: () => _openCreate(context),
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final cubit = context.read<InvoicesListCubit>();
    await context.pushNamed(InvoicesRoute.create.name);
    await cubit.refresh();
  }

  Future<void> _openDetail(BuildContext context, Invoice invoice) async {
    final cubit = context.read<InvoicesListCubit>();
    await context.pushNamed(
      InvoicesRoute.detail.name,
      pathParameters: {'id': invoice.id.value},
      extra: invoice,
    );
    await cubit.refresh();
  }
}
