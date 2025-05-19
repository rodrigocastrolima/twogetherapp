import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cpe_proposta_detail.dart';
import '../../../../core/services/salesforce_auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

final cpePropostaDetailProvider = FutureProvider.family<CpePropostaDetail, String>((ref, cpePropostaId) async {
  final authNotifier = ref.read(salesforceAuthProvider.notifier);
  final accessToken = authNotifier.currentAccessToken;
  final instanceUrl = authNotifier.currentInstanceUrl;

  if (accessToken == null || instanceUrl == null) {
    throw Exception('Salesforce authentication required.');
  }

  final callable = FirebaseFunctions.instance.httpsCallable('getSalesforceCPEDetails');
  final result = await callable.call({
    'cpePropostaId': cpePropostaId,
    'accessToken': accessToken,
    'instanceUrl': instanceUrl,
  });
  final data = result.data['data'] as Map<String, dynamic>;
  return CpePropostaDetail.fromJson(data);
}); 