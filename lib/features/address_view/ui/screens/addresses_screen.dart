import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/coming_soon_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/settings/ui/widgets/address_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
      appBar: AppBar(
        title: Text(context.loc.addressViewAddressesTitle),
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: BBSegmentFull(
                items: {context.loc.addressViewReceiveType, context.loc.addressViewChangeType},
                initialValue: selectedTab,
                onSelected: (value) {
                  if (value == context.loc.addressViewChangeType) {
                    ComingSoonBottomSheet.show(
                      context,
                      description: context.loc.addressViewChangeAddressesDescription,
                    );
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
                  final addresses =
                      showChangeAddresses
                          ? state.changeAddresses
                          : state.receiveAddresses;
                  final hasReachedEnd =
                      showChangeAddresses
                          ? state.hasReachedEndOfChangeAddresses
                          : state.hasReachedEndOfReceiveAddresses;

                  if (state.isLoading && addresses.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state.error != null && addresses.isEmpty) {
                    return Center(
                      child: Text(
                        context.loc.addressViewErrorLoadingAddresses(state.error!.toString()),
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.error,
                        ),
                      ),
                    );
                  } else if (addresses.isEmpty) {
                    return Center(
                      child: Text(
                        showChangeAddresses
                            ? context.loc.addressViewChangeAddressesComingSoon
                            : context.loc.addressViewNoAddressesFound,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.onSurface,
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
                          (hasReachedEnd ? 0 : 1) +
                          (state.error != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < addresses.length) {
                          final address = addresses[index];
                          return AddressCard(
                            isUsed: address.isUsed,
                            address: address.address,
                            index: address.index,
                            balanceSat: address.balanceSat,
                          );
                        } else {
                          if (state.error != null &&
                              index == addresses.length) {
                            return Center(
                              child: Text(
                                context.loc.addressViewErrorLoadingMoreAddresses(state.error!.toString()),
                                style: context.font.bodyMedium?.copyWith(
                                  color: context.colour.error,
                                ),
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
