import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sepa_eur_form.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_failure_l10n.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/confidential_sepa_availability_status.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart' show PopScope;
import 'package:flutter_bloc/flutter_bloc.dart';

// EUR Sell deliberately uses a separate picker for method-first selection while the broader exchange refactor is underway.
// This temporary UI duplication keeps existing Withdraw, Pay and recipient-creation flows stable; the refactor will consolidate these pickers.
class RecipientSelectionScreenV2 extends StatefulWidget {
  final bool isConfidential;

  const RecipientSelectionScreenV2({required this.isConfidential, super.key});

  @override
  State<RecipientSelectionScreenV2> createState() =>
      _RecipientSelectionScreenV2State();
}

class _RecipientSelectionScreenV2State
    extends State<RecipientSelectionScreenV2> {
  bool _hasPopped = false;
  RecipientsFailure? _selectionFailure;

  @override
  Widget build(BuildContext context) {
    final type = widget.isConfidential
        ? RecipientType.confidentialSepaEur
        : RecipientType.sepaEur;
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _hasPopped = true;
      },
      child: BlocProvider<RecipientsBloc>(
        create: (_) => locator<RecipientsBloc>(
          param1: RecipientFilterCriteria(types: [type], isOwner: true),
          param2: (RecipientViewModel recipient, {required bool isNew}) async {
            if (_hasPopped || !mounted) return;
            if (recipient.isOwner != true || recipient.type != type) {
              setState(
                () => _selectionFailure = isNew
                    ? const RecipientsSavedButNotSelectedFailure()
                    : const RecipientsSelectionFailure(),
              );
              return;
            }
            Navigator.of(context).pop(
              RecipientSelection(
                id: recipient.id,
                type: recipient.type,
                displayName: recipient.displayName,
                iban: recipient.iban,
                isVirtualPayeeActive: recipient.isVirtualPayeeActive,
              ),
            );
          },
        )..add(const RecipientsEvent.started()),
        child: _RecipientSelectionViewV2(
          isConfidential: widget.isConfidential,
          selectionFailure: _selectionFailure,
        ),
      ),
    );
  }
}

class _RecipientSelectionViewV2 extends StatefulWidget {
  final bool isConfidential;
  final RecipientsFailure? selectionFailure;

  const _RecipientSelectionViewV2({
    required this.isConfidential,
    this.selectionFailure,
  });

  @override
  State<_RecipientSelectionViewV2> createState() =>
      _RecipientSelectionViewV2State();
}

class _RecipientSelectionViewV2State extends State<_RecipientSelectionViewV2> {
  bool _isNew = false;
  RecipientViewModel? _selected;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 200) {
        context.read<RecipientsBloc>().add(const RecipientsEvent.moreLoaded());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<RecipientsBloc, RecipientsState>(
    builder: (context, state) {
      if (!_isNew &&
          !state.isLoading &&
          state.failedToLoadRecipients == null &&
          state.hasMoreRecipientsToLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _scrollController.hasClients &&
              _scrollController.position.extentAfter < 200) {
            context.read<RecipientsBloc>().add(
              const RecipientsEvent.moreLoaded(),
            );
          }
        });
      }
      final colors = context.bull;
      final availabilityFailed = state.failedToLoadConfidentialSepaAvailability;
      final selectionFailure =
          widget.selectionFailure ?? state.failedToSelectRecipient;
      final canSelect =
          !widget.isConfidential ||
          state.selectableRecipientTypes.contains(
            RecipientType.confidentialSepaEur,
          );
      final recipients = (state.selectableRecipients ?? <RecipientViewModel>[])
          .where(
            (recipient) =>
                recipient.isOwner == true &&
                recipient.type ==
                    (widget.isConfidential
                        ? RecipientType.confidentialSepaEur
                        : RecipientType.sepaEur),
          )
          .toList();
      final selected = _selected;
      final selectionIsCurrent =
          selected != null &&
          recipients.any((recipient) => recipient.id == selected.id);
      return BullScaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                BullTopBar(
                  title: context.loc.recipientsScreenTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                BullFadingLinearProgress(trigger: state.isLoading),
                const Gap(16),
                BullSegmented(
                  items: {
                    context.loc.recipientsTabNew,
                    context.loc.recipientsTabList,
                  },
                  initialValue: _isNew
                      ? context.loc.recipientsTabNew
                      : context.loc.recipientsTabList,
                  onSelected: (value) => setState(() {
                    _isNew = value == context.loc.recipientsTabNew;
                    _selected = null;
                  }),
                ),
                const Gap(16),
                ConfidentialSepaAvailabilityStatus(
                  failure: availabilityFailed,
                  onRetry: () => context.read<RecipientsBloc>().add(
                    const RecipientsEvent.confidentialSepaAvailabilityRetried(),
                  ),
                ),
                if (!canSelect &&
                    !state.isLoading &&
                    availabilityFailed == null)
                  Text(
                    const RecipientsVirtualIbanNotAvailableFailure()
                        .toTranslated(context),
                    style: context.bullText.bodyMedium,
                  ),
                if (_isNew)
                  Expanded(
                    child: canSelect && availabilityFailed == null
                        ? BullScrollableColumn(
                            children: [
                              SepaEurForm(
                                isConfidential: widget.isConfidential,
                                hookError: selectionFailure?.toTranslated(
                                  context,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  )
                else ...[
                  BullInputText(
                    value: state.searchQuery,
                    hint: context.loc.recipientsSearchHint,
                    onChanged: (query) {
                      setState(() => _selected = null);
                      context.read<RecipientsBloc>().add(
                        RecipientsEvent.searchChanged(query),
                      );
                    },
                  ),
                  const Gap(16),
                  ConfidentialSepaAvailabilityStatus(
                    failure: state.failedToLoadRecipients,
                    onRetry: () => context.read<RecipientsBloc>().add(
                      const RecipientsEvent.refreshed(),
                    ),
                  ),
                  Expanded(
                    child: BullRefreshIndicator(
                      onRefresh: () async {
                        setState(() => _selected = null);
                        final bloc = context.read<RecipientsBloc>();
                        bloc.add(const RecipientsEvent.refreshed());
                        await bloc.stream.firstWhere(
                          (state) => !state.isLoading,
                        );
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _scrollController,
                        children: [
                          if (recipients.isEmpty && !state.isLoading)
                            Text(
                              context.loc.recipientsListEmpty,
                              style: context.bullText.bodyMedium,
                            ),
                          for (final recipient in recipients) ...[
                            BullBorderedTile(
                              backgroundColor: selected?.id == recipient.id
                                  ? colors.surfaceContainer
                                  : null,
                              onTap: canSelect
                                  ? () => setState(() => _selected = recipient)
                                  : null,
                              child: Column(
                                crossAxisAlignment: .start,
                                children: [
                                  Text(
                                    recipient.displayName ?? '',
                                    style: context.bullText.bodyLarge,
                                  ),
                                  const Gap(8),
                                  Text(
                                    recipient.iban ?? '',
                                    style: context.bullText.bodyMedium,
                                  ),
                                  if (recipient.label case final label?)
                                    Text(
                                      label,
                                      style: context.bullText.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            const Gap(12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (selectionFailure case final failure?)
                    Text(
                      failure.toTranslated(context),
                      style: context.bullText.bodyMedium,
                    ),
                  BullButton.big(
                    label: context.loc.recipientsContinue,
                    disabled:
                        !selectionIsCurrent || !canSelect || state.isLoading,
                    onPressed: () {
                      if (selected != null) {
                        context.read<RecipientsBloc>().add(
                          RecipientsEvent.selected(selected),
                        );
                      }
                    },
                    bgColor: colors.primary,
                    textColor: colors.onPrimary,
                  ),
                  const Gap(16),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
