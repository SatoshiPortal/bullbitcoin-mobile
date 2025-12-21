import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/tabs/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeRecipientsScreen extends StatelessWidget {
  const ExchangeRecipientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecipientsBloc>(
      create: (_) =>
          locator<RecipientsBloc>(param1: null, param2: null)
            ..add(const RecipientsEvent.started()),
      child: const _RecipientsView(),
    );
  }
}

class _RecipientsView extends StatelessWidget {
  const _RecipientsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeRecipientsTitle,
          onBack: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<RecipientsBloc, RecipientsState, bool>(
            selector: (state) => state.isLoading,
            builder: (context, isLoading) => isLoading
                ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.appColors.surface,
                    foregroundColor: context.appColors.primary,
                  )
                : const SizedBox(height: 3),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                context.loc.exchangeRecipientsDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: RecipientsListTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
