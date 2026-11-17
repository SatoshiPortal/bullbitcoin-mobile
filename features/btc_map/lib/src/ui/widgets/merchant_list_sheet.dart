import 'dart:async';

import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:btc_map/src/presentation/map_state.dart';
import 'package:btc_map/src/ui/widgets/merchant_list_header.dart';
import 'package:btc_map/src/ui/widgets/merchant_list_places.dart';

/// The panel over the bottom of the map, as on btcmap.org: collapsed it shows
/// only the search field; pulled up, the category filters, how many places
/// are in view and the places themselves, nearest first.
class MerchantListSheet extends StatefulWidget {
  const MerchantListSheet({super.key, required this.onMerchantSelected});

  final ValueChanged<Merchant> onMerchantSelected;

  @override
  State<MerchantListSheet> createState() => _MerchantListSheetState();
}

class _MerchantListSheetState extends State<MerchantListSheet> {
  /// Handle and search bar.
  static const _collapsedContentHeight = 96.0;
  static const _halfSize = 0.5;
  static const _expandedSize = 0.92;
  static const _animation = Duration(milliseconds: 250);

  final _sheet = DraggableScrollableController();
  final _searchFocus = FocusNode();
  double _collapsedSize = 0.2;

  /// Pulled up past its collapsed size: the filters and list are revealed.
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocusChanged);
    _sheet.addListener(_onSheetMoved);
  }

  @override
  void dispose() {
    _searchFocus
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _sheet
      ..removeListener(_onSheetMoved)
      ..dispose();
    super.dispose();
  }

  void _onSheetMoved() {
    final isOpen = _sheet.isAttached && _sheet.size > _collapsedSize + 0.01;
    if (isOpen != _isOpen) setState(() => _isOpen = isOpen);
  }

  /// Typing needs room for the results above the keyboard.
  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus) _animateTo(_expandedSize);
  }

  void _animateTo(double size) {
    if (!_sheet.isAttached) return;
    unawaited(
      _sheet.animateTo(size, duration: _animation, curve: Curves.easeOutCubic),
    );
  }

  void _select(Merchant merchant) {
    _searchFocus.unfocus();
    _animateTo(_collapsedSize);
    widget.onMerchantSelected(merchant);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        _collapsedSize =
            ((_collapsedContentHeight + bottomInset) / constraints.maxHeight)
                .clamp(0.1, _halfSize - 0.05);
        return DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: _collapsedSize,
          minChildSize: _collapsedSize,
          maxChildSize: _expandedSize,
          snap: true,
          snapSizes: const [_halfSize],
          builder: (context, scrollController) => Material(
            color: context.bull.background,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(context.bullShapes.sheet),
              ),
              side: BorderSide(color: context.bull.secondaryFixedDim),
            ),
            child: BlocBuilder<MapCubit, MapState>(
              builder: (context, state) => CustomScrollView(
                controller: scrollController,
                slivers: [
                  PinnedHeaderSliver(
                    child: MerchantListHeader(
                      state: state,
                      searchFocus: _searchFocus,
                      isOpen: _isOpen,
                      onCategorySelected: (category) {
                        context.read<MapCubit>().selectCategory(category);
                        _animateTo(_halfSize);
                      },
                    ),
                  ),
                  if (_isOpen)
                    MerchantListPlaces(state: state, onSelected: _select),
                  SliverToBoxAdapter(child: Gap(bottomInset + 16)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
