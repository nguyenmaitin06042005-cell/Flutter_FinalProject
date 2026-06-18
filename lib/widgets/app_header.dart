import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? buttonText;

  const AppHeader({super.key, required this.title, this.buttonText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Welcome back, Admin Platform 👋', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: const Row(children: [Icon(Icons.calendar_today, size: 16), SizedBox(width: 8), Text('01/05/2024 - 31/12/2024', style: TextStyle(fontSize: 12))]),
        ),
        const SizedBox(width: 14),
        Stack(children: [
          const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.notifications_none, color: AppColors.text)),
          Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
        ]),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: const Row(children: [CircleAvatar(radius: 15, backgroundColor: Color(0xffffd9a8), child: Icon(Icons.person, size: 18)), SizedBox(width: 8), Text('Admin Platform', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
        ),
        if (buttonText != null && buttonText!.isNotEmpty) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: Text(buttonText!),
          ),
        ],
      ],
    );
  }
}
