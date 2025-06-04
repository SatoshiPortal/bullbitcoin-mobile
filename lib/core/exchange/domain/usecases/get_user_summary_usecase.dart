import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_user_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';

class GetUserSummaryUsecase {
  GetUserSummaryUsecase({required BullBitcoinUserDatasource userDatasource})
    : _userDatasource = userDatasource;

  final BullBitcoinUserDatasource _userDatasource;

  Future<UserSummaryModel?> execute(String apiKey) async {
    return await _userDatasource.getUserSummary(apiKey);
  }
}
