import 'package:flutter/material.dart';
import 'card_box.dart';
import 'app_colors.dart';

class DataTableCard extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const DataTableCard({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 54,
          headingTextStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 12),
          dataTextStyle: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w500),
          dividerThickness: .5,
          columns: columns.map((e) => DataColumn(label: Text(e))).toList(),
          rows: rows.map((row) {
            return DataRow(cells: row.map((cell) {
              final status = ['Active', 'Draft', 'Surveying', 'Suspended', 'Generate', 'View'].contains(cell);
              if (status) {
                final bg = cell == 'Active' ? AppColors.lightGreen : cell == 'Draft' ? const Color(0xfffff4e5) : const Color(0xffeaf1ff);
                final fg = cell == 'Active' ? AppColors.primary : cell == 'Draft' ? Colors.orange : Colors.blue;
                return DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(cell, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11))));
              }
              return DataCell(Text(cell));
            }).toList());
          }).toList(),
        ),
      ),
    );
  }
}
