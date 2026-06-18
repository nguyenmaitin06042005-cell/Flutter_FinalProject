import 'package:flutter/material.dart';
import 'app_header.dart';
import 'card_box.dart';
import 'data_table_card.dart';
import 'app_colors.dart';

class TablePage extends StatelessWidget {
  final String title;
  final String buttonText;
  final List<String> columns;
  final List<List<String>> rows;

  const TablePage({super.key, required this.title, required this.buttonText, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AppHeader(title: title, buttonText: buttonText),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: TextField(
                    decoration: InputDecoration(hintText: 'Search ${title.toLowerCase()}...', hintStyle: const TextStyle(color: AppColors.muted), prefixIcon: const Icon(Icons.search, color: AppColors.muted), border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _filter('All Status'),
              const SizedBox(width: 10),
              _filter('All Type'),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: DataTableCard(columns: columns, rows: rows)),
        ],
      ),
    );
  }

  Widget _filter(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text)), const SizedBox(width: 8), const Icon(Icons.keyboard_arrow_down, size: 18)]),
      );
}
