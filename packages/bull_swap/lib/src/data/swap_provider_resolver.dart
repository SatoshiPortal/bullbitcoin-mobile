import 'package:bull_swap/src/data/swap_provider_factory.dart';
import 'package:bull_swap/src/data/swap_provider_store.dart';
import 'package:bull_swap/src/domain/swap_provider.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';

class SwapProviderResolver {
  final SwapProviderStore _store;
  final SwapProviderFactory _factory;
  final Map<String, SwapProvider> _cache = {};

  SwapProviderResolver(this._store, this._factory);

  Future<SwapProvider> resolveActive() async {
    final config = await _store.active();
    if (config == null) {
      throw StateError('No active swap provider; call ensureSeeded first');
    }
    return resolveFor(config);
  }

  Future<SwapProvider> resolveById(String id) async {
    final config = await _store.byId(id);
    if (config == null) throw ArgumentError('Unknown swap provider: $id');
    return resolveFor(config);
  }

  SwapProvider resolveFor(SwapProviderConfig config) =>
      _cache.putIfAbsent(_key(config), () => _factory.create(config));

  void invalidate() => _cache.clear();

  String _key(SwapProviderConfig config) => '${config.id}|${config.baseUrl}';
}
