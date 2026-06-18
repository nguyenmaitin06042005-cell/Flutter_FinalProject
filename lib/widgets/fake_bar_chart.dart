import 'package:flutter/material.dart';
import 'app_colors.dart';

class FakeBarChart extends StatelessWidget {
  const FakeBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      ('Dak Lak\nProject 01', 45331, 170.0),
      ('Lam Dong\nProject 02', 38521, 145.0),
      ('Gia Lai\nProject 01', 32110, 122.0),
      ('Quang Tri\nProject 01', 24532, 95.0),
      ('Quang Nam\nProject 01', 18410, 72.0),
    ];
    return SizedBox(
      height: 238,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: data.map((e) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${e.$2}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 6),
              Container(
                width: 42,
                height: e.$3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xff14b956), Color(0xff008f3f)]),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.2), blurRadius: 10, offset: const Offset(0, 5))],
                ),
              ),
              const SizedBox(height: 9),
              Text(e.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, height: 1.15, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
