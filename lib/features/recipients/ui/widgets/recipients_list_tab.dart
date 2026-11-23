import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:material_ui/material_ui.dart' show MaterialLocalizations;
import 'package:bb_mobile/features/recipients/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipients_list_tile.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bb_mobile/features/recipients/ui/screens/virtual_iban_onboarding_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/confidential_sepa_availability_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecipientsListTab extends StatefulWidget {
  const RecipientsListTab({
    this.hookError,
    this.showFilters = true,
    this.enforceRecipientFilter = false,
    this.isHookRunning = false,
    super.key,
  });

  final String? hookError;
  final bool showFilters;
  final bool enforceRecipientFilter;
  final bool isHookRunning;

  @override
  RecipientsListTabState createState() => RecipientsListTabState();
}

class RecipientsListTabState extends State<RecipientsListTab> {
  RecipientViewModel? _selectedRecipient;
  Key _sepaTypeSelectorKey = const ValueKey(0);
  int _sepaTypeSelectorGeneration = 0;
  late ScrollController _scrollController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 200) {
      context.read<RecipientsBloc>().add(const RecipientsEvent.moreLoaded());
    }
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _selectedRecipient = null;
    });
    context.read<RecipientsBloc>().add(RecipientsEvent.searchChanged(query));
  }

  Future<void> _onRefresh() async {
    setState(() => _selectedRecipient = null);
    final bloc = context.read<RecipientsBloc>();
    bloc.add(const RecipientsEvent.refreshed());
    // orElse guards against the bloc closing (route popped) before completion,
    // which would otherwise throw an unhandled StateError on this future.
    await bloc.stream.firstWhere(
      (state) =>
          !state.isLoadingRecipients &&
          !state.isLoadingConfidentialSepaAvailability,
      orElse: () => bloc.state,
    );
  }

  Future<void> _onSepaTypeChanged(RecipientType type) async {
    final bloc = context.read<RecipientsBloc>();
    var next = type;
    if (type == RecipientType.confidentialSepaEur &&
        bloc.state.confidentialSepaAvailability ==
            ConfidentialSepaAvailability.needsVirtualIban) {
      final result = await VirtualIbanOnboardingScreen.showForWithdraw(context);
      if (!mounted) return;
      if (result == null) {
        setState(
          () => _sepaTypeSelectorKey = ValueKey(++_sepaTypeSelectorGeneration),
        );
        return;
      }
      next = result;
      if (next == RecipientType.confidentialSepaEur) {
        bloc.add(const RecipientsEvent.virtualIbanActivated());
      }
    }
    bloc.add(RecipientsEvent.sepaTypeChanged(next));
    setState(() {
      _selectedRecipient = null;
      _sepaTypeSelectorKey = ValueKey(++_sepaTypeSelectorGeneration);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecipientsBloc>().state;
    final loaded = state.selectableRecipients ?? const <RecipientViewModel>[];
    final types = state.selectableRecipientTypes;
    final owner = state.allowedRecipientFilters.isOwner;
    final recipients = widget.enforceRecipientFilter
        ? loaded
              .where(
                (recipient) =>
                    types.contains(recipient.type) &&
                    (owner == null || recipient.isOwner == owner),
              )
              .toList()
        : loaded;
    final selectedId = _selectedRecipient?.id;
    final selected = recipients
        .where((recipient) => recipient.id == selectedId)
        .firstOrNull;
    bool canSelect(RecipientViewModel recipient) =>
        !state.isLoading &&
        !widget.isHookRunning &&
        (recipient.type != RecipientType.confidentialSepaEur ||
            (types.contains(RecipientType.confidentialSepaEur) &&
                state.failedToLoadConfidentialSepaAvailability == null));
    if (!state.isLoading &&
        state.failedToLoadRecipients == null &&
        state.hasMoreRecipientsToLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onScroll();
      });
    }
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        BullSearchBar(
          hint: context.loc.recipientsSearchHint,
          value: _searchQuery,
          clearTooltip: MaterialLocalizations.of(context).clearButtonTooltip,
          onChanged: _updateSearch,
          onCleared: () => _updateSearch(''),
        ),
        if (widget.showFilters) ...[
          const Gap(16.0),
          Text(
            context.loc.recipientsFilterByJurisdiction,
            style: context.bullType.body,
          ),
          const Gap(8.0),
          BlocSelector<RecipientsBloc, RecipientsState, String?>(
            selector: (state) => state.jurisdictionFilter,
            builder: (context, selected) {
              return JurisdictionsDropdown(
                selectedJurisdiction: selected,
                includeAllOption: true,
                onChanged: (newJurisdiction) {
                  context.read<RecipientsBloc>().add(
                    RecipientsEvent.jurisdictionChanged(newJurisdiction),
                  );
                  if (newJurisdiction != null &&
                      _selectedRecipient?.jurisdictionCode != newJurisdiction) {
                    setState(() => _selectedRecipient = null);
                  }
                },
              );
            },
          ),
          BlocBuilder<RecipientsBloc, RecipientsState>(
            buildWhen: (previous, current) =>
                previous.canChooseSepaType != current.canChooseSepaType ||
                previous.sepaType != current.sepaType,
            builder: (context, state) {
              if (!state.canChooseSepaType) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    BullSegmented(
                      key: _sepaTypeSelectorKey,
                      items: {
                        RecipientType.sepaEur.name,
                        RecipientType.confidentialSepaEur.name,
                      },
                      labelBuilder: (value) =>
                          value == RecipientType.sepaEur.name
                          ? context.loc.recipientsTypeSepa
                          : context.loc.recipientsTypeConfidentialSepa,
                      height: BullSpacing.xxl,
                      fitLabels: true,
                      initialValue: state.sepaType.name,
                      onSelected: (value) => _onSepaTypeChanged(
                        RecipientType.values.byName(value),
                      ),
                    ),
                    if (state.sepaType ==
                        RecipientType.confidentialSepaEur) ...[
                      const Gap(8),
                      Text(
                        context.loc.recipientsTypeConfidentialSepaDescription,
                        style: context.bullType.body,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
        const Gap(16.0),
        if (recipients.isNotEmpty)
          ConfidentialSepaAvailabilityStatus(
            failure: state.failedToLoadRecipients,
            onRetry: () {
              _onRefresh();
            },
          ),
        Expanded(
          child: BullRefreshIndicator(
            onRefresh: _onRefresh,
            child: _buildListContent(state, recipients, canSelect),
          ),
        ),
        if (widget.hookError case final hookError?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              hookError,
              style: context.bullType.body.copyWith(color: context.bull.error),
            ),
          ),
        BlocSelector<RecipientsBloc, RecipientsState, RecipientsFailure?>(
          selector: (state) => state.failedToSelectRecipient,
          builder: (context, failure) {
            if (failure == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                failure.toTranslated(context),
                style: context.bullType.body.copyWith(
                  color: context.bull.error,
                ),
              ),
            );
          },
        ),
        BullButton.primary(
          label: context.loc.recipientsContinue,
          onPressed: (selected == null || !canSelect(selected))
              ? null
              : () => context.read<RecipientsBloc>().add(
                  RecipientsEvent.selected(selected),
                ),
        ),
        const Gap(16),
      ],
    );
  }

  Widget _buildListContent(
    RecipientsState state,
    List<RecipientViewModel> recipients,
    bool Function(RecipientViewModel) canSelect,
  ) {
    if (recipients.isEmpty) {
      if (state.isLoadingRecipients) {
        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            BullShimmerBox(height: 112, padding: EdgeInsets.zero),
            BullShimmerBox(height: 112, padding: EdgeInsets.zero),
            BullShimmerBox(height: 112, padding: EdgeInsets.zero),
          ],
        );
      }

      // Translated from the failure rather than one static string:
      //  RecipientsNetworkFailure exists to tell the user to check their
      //  connection, and this is the only place a load failure is shown, so a
      //  static message would throw that advice away. The pull-to-retry hint
      //  the static string used to carry is kept as its own line, since it is
      //  an affordance of THIS screen rather than something a failure knows.
      final failure = state.failedToLoadRecipients;
      final message =
          failure?.toTranslated(context) ?? context.loc.recipientsListEmpty;
      // Wrap in a scrollable so pull-to-refresh works while empty.
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Gap(96.0),
          Center(
            child: Text(
              message,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (failure != null) ...[
            const Gap(8.0),
            Center(
              child: Text(
                context.loc.recipientsListPullToRetry,
                style: context.bullType.label.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final recipient = recipients[index];
        return RecipientsListTile(
          recipient: recipient,
          selected: _selectedRecipient?.id == recipient.id,
          onTap: !canSelect(recipient)
              ? null
              : () {
                  setState(() {
                    _selectedRecipient = recipient;
                  });
                },
        );
      },
      itemCount: recipients.length,
    );
  }
}
