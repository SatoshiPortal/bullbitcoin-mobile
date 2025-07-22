import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/settings/ui/widgets/address_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class AddressListBottomSheet extends StatefulWidget {
  const AddressListBottomSheet({super.key});

  @override
  State<AddressListBottomSheet> createState() => _AddressListBottomSheetState();
}

class _AddressListBottomSheetState extends State<AddressListBottomSheet> {
  late final ScrollController _scrollController;
  bool showChangeAddresses = false;

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
    // This widget is a placeholder for the address list bottom sheet.
    // You can implement the actual UI and functionality here.
    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(8),
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Center(
                  child: Text(
                    'Addresses',
                    style: context.font.headlineMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(24),
            BlocBuilder<AddressViewBloc, AddressViewState>(
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
                      'Error loading addresses: ${state.error!}',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.error,
                      ),
                    ),
                  );
                } else if (addresses.isEmpty) {
                  return Center(
                    child: Text(
                      'No addresses found',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.onSurface,
                      ),
                    ),
                  );
                } else {
                  return ListView.separated(
                    separatorBuilder: (context, index) => const Gap(16),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
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
                        if (state.error != null && index == addresses.length) {
                          return Center(
                            child: Text(
                              'Error loading more addresses: ${state.error!}',
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
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: 'Receive',
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                    onPressed: () {
                      setState(() {
                        showChangeAddresses = false;
                      });
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    disabled:
                        true, // TODO: implement change address list functionality
                    label: 'Change',
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                    onPressed: () {
                      setState(() {
                        showChangeAddresses = true;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
