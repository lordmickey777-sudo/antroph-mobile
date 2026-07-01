import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';
import '../models/subscription_models.dart';

class SubscriptionRepository {
  SubscriptionRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;

  final Dio _dio;

  Future<SubscriptionStatus> getCurrentSubscription() async {
    try {
      final response = await _dio.get('/subscriptions/me');
      return SubscriptionStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorFormatter.fromDio(error);
    }
  }
}
