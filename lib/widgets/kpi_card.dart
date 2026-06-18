import 'package:flutter/material.dart';
import 'card_box.dart';
import 'app_colors.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String percent;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.percent = '+12% vs last year',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CardBox(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                  const SizedBox(height: 5),
                  Row(children: [Icon(Icons.arrow_upward, size: 12, color: AppColors.primary), const SizedBox(width: 3), Text(percent, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
