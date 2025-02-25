import 'package:boltz/boltz.dart';

abstract class BoltzDataSource {
  Future<ReverseFeesAndLimits> getReverseFeesAndLimits();
}

class BoltzDataSourceImpl implements BoltzDataSource {
  final String _url;

  BoltzDataSourceImpl({String url = 'api.boltz.exchange/v2'}) : _url = url;

  @override
  Future<ReverseFeesAndLimits> getReverseFeesAndLimits() async {
    final fees = Fees(boltzUrl: _url);
    final reverse = await fees.reverse();
    return reverse;
  }
}
