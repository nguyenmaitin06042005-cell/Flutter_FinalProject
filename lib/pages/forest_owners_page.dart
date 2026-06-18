import 'package:flutter/material.dart';
import '../widgets/table_page.dart';

class ForestOwnersPage extends StatelessWidget {
  const ForestOwnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TablePage(
      title: 'Forest Owners',
      buttonText: 'Add Owner',
      columns: ['Owner Code', 'Owner Name', 'Type', 'Phone', 'Province', 'Status'],
      rows: [['OWN-0001', 'Nguyễn Văn A', 'Individual', '0912345678', 'Lâm Đồng', 'Active'], ['OWN-0002', 'Lê Thị B', 'Individual', '0987654321', 'Gia Lai', 'Active'], ['OWN-0003', 'Công ty Rừng Xanh', 'Company', '0876543210', 'Đắk Lắk', 'Active']],
    );
  }
}
