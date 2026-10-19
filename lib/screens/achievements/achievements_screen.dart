import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Achievements')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _ProgressCard(),
          const SizedBox(height: 20),
          const Text('FREIGESCHALTET',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _AchievementsGroup(items: const [
            _AchievementItem(title: 'Erste Tour', description: 'Erste Tour abgeschlossen', icon: Icons.route, unlocked: true, points: 100),
            _AchievementItem(title: '1000 km', description: '1.000 km insgesamt gefahren', icon: Icons.speed, unlocked: true, points: 250),
            _AchievementItem(title: 'Sozial', description: '5 Freunde hinzugefuegt', icon: Icons.people, unlocked: true, points: 150),
          ]),
          const SizedBox(height: 20),
          const Text('NOCH ZU SCHAFFEN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _AchievementsGroup(items: const [
            _AchievementItem(title: 'Alpenbezwinger', description: 'Tour ueber 2.000 m Hoehe', icon: Icons.terrain, unlocked: false, points: 500),
            _AchievementItem(title: '10.000 km', description: '10.000 km Gesamtkilometer', icon: Icons.emoji_events, unlocked: false, points: 1000),
            _AchievementItem(title: 'Gruppenfahrt', description: 'An einer Gruppenfahrt teilgenommen', icon: Icons.group, unlocked: false, points: 200),
          ]),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('850 Punkte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('3 / 6', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.5,
              minHeight: 8,
              backgroundColor: AppTheme.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          const Text('50% der Achievements freigeschaltet',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AchievementsGroup extends StatelessWidget {
  final List<_AchievementItem> items;
  const _AchievementsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final int points;

  const _AchievementItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: unlocked ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: unlocked ? AppTheme.primary : AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary)),
                Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('+$points',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: unlocked ? AppTheme.primary : AppTheme.border)),
        ],
      ),
    );
  }
}
