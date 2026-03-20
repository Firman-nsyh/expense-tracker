import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/transaction_model.dart';

class ExportService {
  static final ExportService instance = ExportService._();
  ExportService._();

  // --- Nama file untuk export per bulan ---
  static String monthlyFileName(int year, int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return 'Laporan_${months[month]}_$year';
  }

  // --- Nama file untuk export semua data ---
  static String allDataFileName() {
    final now = DateTime.now();
    return 'Semua_Transaksi_${now.day}-${now.month}-${now.year}';
  }

  // --- Export ke .xlsx lalu buka file ---
  Future<String?> exportToExcel({
    required List<TransactionModel> transactions,
    required String fileName,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Laporan'];

      // Header
      final headers = ['No', 'Tanggal', 'Keterangan', 'Kategori', 'Nominal (Rp)', 'Metode Input'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // Data rows
      for (var i = 0; i < transactions.length; i++) {
        final t = transactions[i];
        final row = i + 1;
        final tanggal =
            '${t.date.day.toString().padLeft(2, '0')}/'
            '${t.date.month.toString().padLeft(2, '0')}/'
            '${t.date.year}';
        final rowData = [
          (i + 1).toString(),
          tanggal,
          t.description,
          t.category,
          t.amount.toStringAsFixed(0),
          _methodLabel(t.inputMethod),
        ];
        for (var col = 0; col < rowData.length; col++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          cell.value = TextCellValue(rowData[col]);
          if (i % 2 == 0) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
            );
          }
        }
      }

      // Summary row
      final summaryRow = transactions.length + 2;
      final grandTotal = transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: summaryRow)).value =
          TextCellValue('TOTAL');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: summaryRow)).value =
          TextCellValue(grandTotal.toStringAsFixed(0));

      // Lebar kolom
      sheet.setColumnWidth(0, 5);
      sheet.setColumnWidth(1, 15);
      sheet.setColumnWidth(2, 30);
      sheet.setColumnWidth(3, 20);
      sheet.setColumnWidth(4, 18);
      sheet.setColumnWidth(5, 15);

      // Hapus sheet default
      excel.delete('Sheet1');

      // Simpan file
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName.xlsx';
      final fileBytes = excel.encode();
      if (fileBytes == null) return null;

      await File(filePath).writeAsBytes(fileBytes);
      await OpenFile.open(filePath);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'scan':  return 'Scan Struk';
      case 'voice': return 'Suara';
      default:      return 'Manual';
    }
  }
}