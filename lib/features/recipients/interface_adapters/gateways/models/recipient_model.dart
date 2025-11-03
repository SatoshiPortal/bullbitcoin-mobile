import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';

class RecipientModel {
  // Add necessary fields here

  RecipientModel();

  factory RecipientModel.fromDomain(Recipient recipient) {
    // Map fields from entity to model
    return RecipientModel();
  }

  factory RecipientModel.fromJson(Map<String, dynamic> json) {
    // Parse JSON to create RecipientModel
    return RecipientModel();
  }

  Recipient get toDomain {
    // Convert RecipientModel to Recipient entity
    return Recipient();
  }

  Map<String, dynamic> toJson() {
    // Convert RecipientModel to JSON
    return {};
  }
}
