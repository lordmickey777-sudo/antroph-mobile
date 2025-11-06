import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/features/story/presentation/story_sheet.dart';

class StoryPage extends StatefulWidget {
  const StoryPage({super.key});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late final List<StorySection> sections;

  static const _bg = Color(0xFF121516);

  @override
  void initState() {
    super.initState();
    // Temporary JSON data for sections and cards. Replace with API later.
    const tempJson = '''
    {
      "sections": [
        {
          "title": "Recommended",
          "items": [
            {"title": "Cute pet vibes", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s1.png", "users": 312, "views": 48},
            {"title": "Normal Convo", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s2.png", "users": 312, "views": 48},
            {"title": "Mindful Coach", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s3.png", "users": 312, "views": 48}
          ]
        },
        {
          "title": "Learn Something",
          "items": [
            {"title": "Frenchie Croissant", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s1.png", "users": 312, "views": 48},
            {"title": "Guitar Buddy", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s2.png", "users": 312, "views": 48},
            {"title": "Math Sensei", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s3.png", "users": 312, "views": 48}
          ]
        },
        {
          "title": "Learn Something",
          "items": [
            {"title": "Frenchie Croissant", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s1.png", "users": 312, "views": 48},
            {"title": "Guitar Buddy", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s2.png", "users": 312, "views": 48},
            {"title": "Math Sensei", "subtitle": "Chat with the smartest AI Future", "image": "assets/images/s3.png", "users": 312, "views": 48}
          ]
        }
      ]
    }
    ''';

    final map = jsonDecode(tempJson) as Map<String, dynamic>;
    sections = (map['sections'] as List)
        .map((e) => StorySection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: const TypographyText(
                  'Story Mode',
                  variant: TypographyVariant.h1,
                  color: Colors.white,
                ),
              ),
            ),
            for (final section in sections) _SectionSliver(section: section, onTap: _openStory),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Future<void> _openStory(StoryCardData card) async {
    await showCupertinoModalBottomSheet(
      context: context,
      expand: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StorySheet(
        title: card.title,
        subtitle: card.subtitle,
        imageAsset: card.image,
        users: card.users,
        views: card.views,
      ),
    );
  }
}

class _SectionSliver extends StatelessWidget {
  const _SectionSliver({required this.section, required this.onTap});

  final StorySection section;
  final Future<void> Function(StoryCardData) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 340,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            _SideLabel(text: section.title),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(right: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = section.items[index];
                  return _StoryCard(item: item, onTap: () => onTap(item));
                },
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemCount: section.items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Opacity(
        opacity: 0.8,
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: TypographyText(text, variant: TypographyVariant.body1, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.item, required this.onTap});

  final StoryCardData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const cardRadius = 8.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 220,
        child: Column(
          children: [
            // Card visual
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(cardRadius),
                        topRight: Radius.circular(cardRadius),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.2,
                        child: Image.asset(item.image, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TypographyText(
                            item.title,
                            variant: TypographyVariant.body1,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          TypographyText(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            variant: TypographyVariant.body2,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(CupertinoIcons.person_2, size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              TypographyText(
                                '${item.users}',
                                variant: TypographyVariant.body2,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 14),
                              const Icon(CupertinoIcons.eye, size: 14, color: Colors.white60),
                              const SizedBox(width: 6),
                              TypographyText(
                                '${item.views}',
                                variant: TypographyVariant.body2,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Data models
class StorySection {
  StorySection({required this.title, required this.items});
  final String title;
  final List<StoryCardData> items;

  factory StorySection.fromJson(Map<String, dynamic> json) => StorySection(
    title: json['title'] as String,
    items: (json['items'] as List)
        .map((e) => StoryCardData.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class StoryCardData {
  StoryCardData({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.users,
    required this.views,
  });
  final String title;
  final String subtitle;
  final String image;
  final int users;
  final int views;

  factory StoryCardData.fromJson(Map<String, dynamic> json) => StoryCardData(
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    image: json['image'] as String,
    users: (json['users'] as num).toInt(),
    views: (json['views'] as num).toInt(),
  );
}
