import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_formatter.dart';

class RobotPairingRepository {
  RobotPairingRepository({Dio? dio}) : _dio = dio ?? ApiClient.I.dio;
  final Dio _dio;

  Future<RobotPairingResponse> completePairing({
    required String pairingToken,
    required String friendlyName,
  }) async {
    try {
      final res = await _dio.post(
        '/api/robot/pair',
        data: {'pairing_token': pairingToken, 'friendly_name': friendlyName},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return RobotPairingResponse.fromJson(data);
      }
      return RobotPairingResponse(
        message: data?.toString() ?? 'Paired successfully',
        robot: null,
      );
    } on DioException catch (e) {
      throw ErrorFormatter.fromDio(e);
    }
  }
}

class RobotPairingResponse {
  const RobotPairingResponse({required this.message, required this.robot});

  factory RobotPairingResponse.fromJson(Map<String, dynamic> json) {
    return RobotPairingResponse(
      message: json['message'] as String? ?? 'Pairing completed',
      robot: json['robot'] is Map<String, dynamic>
          ? RobotInfo.fromJson(json['robot'] as Map<String, dynamic>)
          : null,
    );
  }

  final String message;
  final RobotInfo? robot;
}

class RobotInfo {
  const RobotInfo({
    required this.serial,
    required this.userId,
    required this.friendlyName,
    required this.model,
    required this.currentFirmwareVersion,
    required this.currentSoftwareVersion,
    required this.currentConfigHash,
    required this.connectionStatus,
    required this.lastSeen,
    required this.lastIpAddress,
    required this.isActive,
    required this.healthStatus,
    required this.hardwareVersion,
    required this.manufactureDate,
    required this.firstActivationDate,
    required this.warrantyExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RobotInfo.fromJson(Map<String, dynamic> json) {
    return RobotInfo(
      serial: json['robot_serial'] as String?,
      userId: json['user_id'] as String?,
      friendlyName: json['friendly_name'] as String?,
      model: json['model'] as String?,
      currentFirmwareVersion: json['current_firmware_version'] as String?,
      currentSoftwareVersion: json['current_software_version'] as String?,
      currentConfigHash: json['current_config_hash'] as String?,
      connectionStatus: json['connection_status'] as String?,
      lastSeen: json['last_seen'] as String?,
      lastIpAddress: json['last_ip_address'] as String?,
      isActive: json['is_active'] as bool?,
      healthStatus: json['health_status'] as String?,
      hardwareVersion: json['hardware_version'] as String?,
      manufactureDate: json['manufacture_date'] as String?,
      firstActivationDate: json['first_activation_date'] as String?,
      warrantyExpiresAt: json['warranty_expires_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String? serial;
  final String? userId;
  final String? friendlyName;
  final String? model;
  final String? currentFirmwareVersion;
  final String? currentSoftwareVersion;
  final String? currentConfigHash;
  final String? connectionStatus;
  final String? lastSeen;
  final String? lastIpAddress;
  final bool? isActive;
  final String? healthStatus;
  final String? hardwareVersion;
  final String? manufactureDate;
  final String? firstActivationDate;
  final String? warrantyExpiresAt;
  final String? createdAt;
  final String? updatedAt;
}
