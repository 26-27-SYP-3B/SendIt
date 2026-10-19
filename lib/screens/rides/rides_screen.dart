import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RidesScreen extends StatelessWidget {
  const RidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Meine Touren')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: const [
          _RideCard(name: 'Salzkammergut-Runde', distance: '187 km', duration: '3h 20min', date: '15. Okt', elevation: '1.240 m'),
          SizedBox(height: 10),
          _RideCard(name: 'Alpenstrasse', distance: '245 km', duration: '4h 10min', date: '8. Okt', elevation: '2.100 m'),
          SizedBox(height: 10),
          _RideCard(name: 'Donauradweg', distance: '98 km', duration: '1h 55min', date: '1. Okt', elevation: '210 m'),
        ],
      ),
      floatingActionButton: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Tour starten'),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _RideCard extends StatelessWidget {
  final String name;
  final String distance;
  final String duration;
  final String date;
  final String elevation;

  const _RideCard({
    required this.name,
    required this.distance,
    required this.duration,
    required this.date,
    required this.elevation,
  });

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
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              Text(date, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(icon: Icons.straighten, label: distance),
              const SizedBox(width: 8),
              _Chip(icon: Icons.timer_outlined, label: duration),
              const SizedBox(width: 8),
              _Chip(icon: Icons.terrain, label: elevation),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
