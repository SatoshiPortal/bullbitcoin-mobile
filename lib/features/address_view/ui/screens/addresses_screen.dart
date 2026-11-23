import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_failure_l10n.dart';
import 'package:bb_mobile/features/settings/ui/widgets/address_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullSegmented,
        BullShapesX,
        BullText,
        BullTextRole,
        BullTypographyX,
        Gap;

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, required this.walletId});

  final String walletId;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late final ScrollController _scrollController;
  bool showChangeAddresses = false;
  late String selectedTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize selectedTab after context is available
    if (!_initialized) {
      selectedTab = context.loc.addressViewReceiveType;
      _initialized = true;
    }
  }

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    context.read<AddressViewBloc>().add(
      const AddressViewEvent.loadInitialAddresses(),
    );
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final bloc = context.read<AddressViewBloc>();
    final threshold = _scrollController.position.maxScrollExtent * 0.8;
    if (_scrollController.position.pixels >= threshold) {
      if (showChangeAddresses) {
        bloc.add(const AddressViewEvent.loadMoreChangeAddresses());
      } else {
        bloc.add(const AddressViewEvent.loadMoreReceiveAddresses());
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.addressViewAddressesTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: BullSegmented(
                items: {
                  context.loc.addressViewReceiveType,
                  context.loc.addressViewChangeType,
                },
                initialValue: selectedTab,
                onSelected: (value) {
                  if (value == context.loc.addressViewChangeType) {
                    if (context.read<AddressViewBloc>().state.isLiquid) {
                      BullBottomSheet.show<void>(
                        context: context,
                        child: _ChangeAddressesNotice(
                          description:
                              context.loc.addressViewChangeAddressesDescription,
                        ),
                      );
                    }
                    setState(() {
                      selectedTab = context.loc.addressViewChangeType;
                      showChangeAddresses = true;
                    });
                    return;
                  }
                  setState(() {
                    selectedTab = context.loc.addressViewReceiveType;
                    showChangeAddresses = false;
                  });
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<AddressViewBloc, AddressViewState>(
                builder: (context, state) {
                  final addresses = showChangeAddresses
                      ? state.changeAddresses
                      : state.receiveAddresses;
                  final hasReachedEnd = showChangeAddresses
                      ? state.hasReachedEndOfChangeAddresses
                      : state.hasReachedEndOfReceiveAddresses;
                  final failure = showChangeAddresses
                      ? state.changeAddressesFailure
                      : state.receiveAddressesFailure;
                  final isLiquid = state.isLiquid;

                  if (state.isLoading && addresses.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (failure != null && addresses.isEmpty) {
                    return Center(
                      child: Text(
                        failure.toTranslated(context),
                        style: context.bullType.body.copyWith(
                          color: context.appColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  } else if (addresses.isEmpty) {
                    return Center(
                      child: Text(
                        showChangeAddresses && isLiquid
                            ? context.loc.addressViewChangeAddressesComingSoon
                            : context.loc.addressViewNoAddressesFound,
                        style: context.bullType.body.copyWith(
                          color: context.appColors.onSurface,
                        ),
                      ),
                    );
                  } else {
                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (context, index) => const Gap(16),
                      itemCount:
                          addresses.length +
                          (hasReachedEnd || failure != null ? 0 : 1) +
                          (failure != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < addresses.length) {
                          final address = addresses[index];
                          return AddressCard(
                            isUsed: address.isUsed,
                            address: address.address,
                            index: address.index,
                            balanceSat: address.balanceSat,
                            labels: address.labels,
                          );
                        } else {
                          if (failure != null && index == addresses.length) {
                            return Center(
                              child: Text(
                                failure.toTranslated(context),
                                style: context.bullType.body.copyWith(
                                  color: context.appColors.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeAddressesNotice extends StatelessWidget {
  const _ChangeAddressesNotice({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.bullShapes.dot),
              ),
            ),
            const Gap(24),
            Semantics(
              header: true,
              child: BullText(
                context.loc.comingSoonTitle,
                role: BullTextRole.subtitle,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(8),
            Text(
              description,
              style: context.bullType.body.copyWith(
                color: context.appColors.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(24),
            BullButton.secondary(
              label: context.loc.okButton,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
