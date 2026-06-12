class SubscriptionStatus {
  const SubscriptionStatus({
    required this.tier,
    required this.status,
    required this.period,
    required this.store,
    required this.productId,
    required this.startedAt,
    required this.expiresAt,
    required this.willRenew,
    required this.gracePeriodExpiresAt,
    required this.isActive,
  });

  factory SubscriptionStatus.free() {
    return const SubscriptionStatus(
      tier: 'free',
      status: null,
      period: null,
      store: null,
      productId: null,
      startedAt: null,
      expiresAt: null,
      willRenew: false,
      gracePeriodExpiresAt: null,
      isActive: false,
    );
  }

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      tier: json['tier'] as String? ?? 'free',
      status: json['status'] as String?,
      period: json['period'] as String?,
      store: json['store'] as String?,
      productId: json['product_id'] as String?,
      startedAt: _parseUtc(json['started_at']),
      expiresAt: _parseUtc(json['expires_at']),
      willRenew: json['will_renew'] as bool? ?? false,
      gracePeriodExpiresAt: _parseUtc(json['grace_period_expires_at']),
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  final String tier;
  final String? status;
  final String? period;
  final String? store;
  final String? productId;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool willRenew;
  final DateTime? gracePeriodExpiresAt;
  final bool isActive;

  bool get isCancelledButActive =>
      isActive && status == 'cancelled' && !willRenew;
  bool get hasBillingIssue => status == 'billing_issue';

  static DateTime? _parseUtc(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final normalized = value.endsWith('Z') || value.contains('+')
        ? value
        : '${value}Z';
    return DateTime.tryParse(normalized)?.toUtc();
  }
}
