class SubscriptionStatus {
  const SubscriptionStatus({
    required this.subscriptionsEnabled,
    required this.accessLifted,
    required this.tier,
    required this.status,
    required this.period,
    required this.store,
    required this.productId,
    required this.startedAt,
    required this.expiresAt,
    required this.willRenew,
    required this.gracePeriodExpiresAt,
    required this.syncedAt,
    required this.isActive,
    required this.capabilities,
  });

  factory SubscriptionStatus.free() {
    return const SubscriptionStatus(
      subscriptionsEnabled: true,
      accessLifted: false,
      tier: 'free',
      status: null,
      period: null,
      store: null,
      productId: null,
      startedAt: null,
      expiresAt: null,
      willRenew: false,
      gracePeriodExpiresAt: null,
      syncedAt: null,
      isActive: false,
      capabilities: SubscriptionCapabilities.free(),
    );
  }

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      subscriptionsEnabled: json['subscriptions_enabled'] as bool? ?? true,
      accessLifted: json['access_lifted'] as bool? ?? false,
      tier: json['tier'] as String? ?? 'free',
      status: json['status'] as String?,
      period: json['period'] as String?,
      store: json['store'] as String?,
      productId: json['product_id'] as String?,
      startedAt: _parseUtc(json['started_at']),
      expiresAt: _parseUtc(json['expires_at']),
      willRenew: json['will_renew'] as bool? ?? false,
      gracePeriodExpiresAt: _parseUtc(json['grace_period_expires_at']),
      syncedAt: _parseUtc(json['synced_at']),
      isActive: json['is_active'] as bool? ?? false,
      capabilities: SubscriptionCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>?,
      ),
    );
  }

  final bool subscriptionsEnabled;
  final bool accessLifted;
  final String tier;
  final String? status;
  final String? period;
  final String? store;
  final String? productId;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool willRenew;
  final DateTime? gracePeriodExpiresAt;
  final DateTime? syncedAt;
  final bool isActive;
  final SubscriptionCapabilities capabilities;

  bool get isCancelledButActive =>
      isActive && status == 'cancelled' && !willRenew;
  bool get hasBillingIssue => status == 'billing_issue';
  String get normalizedTier => SubscriptionTier.normalize(tier);
  bool tierAtLeast(String requiredTier) =>
      SubscriptionTier.atLeast(normalizedTier, requiredTier);
  bool get hasStarterAccess => tierAtLeast(SubscriptionTier.starter);
  bool get hasPremiumAccess => tierAtLeast(SubscriptionTier.premium);
  bool get hasProAccess => tierAtLeast(SubscriptionTier.pro);

  static DateTime? _parseUtc(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final normalized = value.endsWith('Z') || value.contains('+')
        ? value
        : '${value}Z';
    return DateTime.tryParse(normalized)?.toUtc();
  }
}

class SubscriptionCapabilities {
  const SubscriptionCapabilities({
    required this.freeStoryLibrary,
    required this.premiumStoryLibrary,
    required this.aiStoryInteractions,
    required this.earlyAccess,
    required this.soloGameInteractions,
    required this.groupGameInteractions,
    required this.customStoryLimit,
    required this.customStoriesCreated,
    required this.customStoriesRemaining,
    required this.aiAssistedStoryBuilding,
    required this.canPublishCommunityStories,
    required this.verifiedCreator,
    required this.communityStoriesAccess,
  });

  const SubscriptionCapabilities.free()
    : freeStoryLibrary = true,
      premiumStoryLibrary = 'none',
      aiStoryInteractions = 'limited',
      earlyAccess = false,
      soloGameInteractions = false,
      groupGameInteractions = false,
      customStoryLimit = 1,
      customStoriesCreated = 0,
      customStoriesRemaining = 1,
      aiAssistedStoryBuilding = false,
      canPublishCommunityStories = false,
      verifiedCreator = false,
      communityStoriesAccess = true;

  factory SubscriptionCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SubscriptionCapabilities.free();
    return SubscriptionCapabilities(
      freeStoryLibrary: json['free_story_library'] as bool? ?? true,
      premiumStoryLibrary: json['premium_story_library'] as String? ?? 'none',
      aiStoryInteractions:
          json['ai_story_interactions'] as String? ?? 'limited',
      earlyAccess: json['early_access'] as bool? ?? false,
      soloGameInteractions: json['solo_game_interactions'] as bool? ?? false,
      groupGameInteractions: json['group_game_interactions'] as bool? ?? false,
      customStoryLimit: json['custom_story_limit'] as int?,
      customStoriesCreated: json['custom_stories_created'] as int? ?? 0,
      customStoriesRemaining: json['custom_stories_remaining'] as int?,
      aiAssistedStoryBuilding:
          json['ai_assisted_story_building'] as bool? ?? false,
      canPublishCommunityStories:
          json['can_publish_community_stories'] as bool? ?? false,
      verifiedCreator: json['verified_creator'] as bool? ?? false,
      communityStoriesAccess: json['community_stories_access'] as bool? ?? true,
    );
  }

  final bool freeStoryLibrary;
  final String premiumStoryLibrary;
  final String aiStoryInteractions;
  final bool earlyAccess;
  final bool soloGameInteractions;
  final bool groupGameInteractions;
  final int? customStoryLimit;
  final int customStoriesCreated;
  final int? customStoriesRemaining;
  final bool aiAssistedStoryBuilding;
  final bool canPublishCommunityStories;
  final bool verifiedCreator;
  final bool communityStoriesAccess;

  bool get hasUnlimitedCustomStories => customStoryLimit == null;
  bool get canCreateCustomStory =>
      customStoryLimit == null || (customStoriesRemaining ?? 0) > 0;
}

class SubscriptionTier {
  const SubscriptionTier._();

  static const free = 'free';
  static const starter = 'starter';
  static const premium = 'premium';
  static const pro = 'pro';

  static const _rank = {free: 0, starter: 1, premium: 2, pro: 3};

  static String normalize(String? tier) {
    final value = (tier ?? free).trim().toLowerCase();
    return _rank.containsKey(value) ? value : free;
  }

  static bool atLeast(String? currentTier, String requiredTier) {
    final current = _rank[normalize(currentTier)] ?? 0;
    final required = _rank[normalize(requiredTier)] ?? 0;
    return current >= required;
  }

  static String displayName(String? tier) {
    switch (normalize(tier)) {
      case starter:
        return 'Starter';
      case premium:
        return 'Premium';
      case pro:
        return 'Pro';
      default:
        return 'Free';
    }
  }
}
