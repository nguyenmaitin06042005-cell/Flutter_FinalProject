import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> exportPdfFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  await Printing.sharePdf(
    bytes: bytes,
    filename: fileName,
  );
}
