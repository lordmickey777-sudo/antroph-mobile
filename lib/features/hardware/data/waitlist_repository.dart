import 'package:dio/dio.dart';
import 'package:antroph_mobile/core/network/api_client.dart';

class WaitlistRepository {
  WaitlistRepository._();
  static final WaitlistRepository I = WaitlistRepository._();

  /// Join the hardware waitlist. Returns the success message on success,
  /// or throws on failure.
  Future<String> joinWaitlist({required String email, String? name}) async {
    final response = await ApiClient.I.dio.post(
      '/waitlist/',
      data: {
        'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
        'source': 'hardware',
      },
      options: Options(extra: {'skipAuth': true}),
    );
    return response.data['message'] as String;
  }
}
