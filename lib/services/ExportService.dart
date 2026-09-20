import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../model/Order.dart';
import '../model/Expense.dart';
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  // ============================================================
  // CSV EXPORT (EXCEL COMPATIBLE)
  // ============================================================

  Future<void> exportOrdersToCSV(List<OrderModel> orders, {String fileName = 'sales_report'}) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      "Order ID",
      "Date",
      "Customer",
      "Mobile",
      "Type",
      "Payment",
      "Items Count",
      "Total Amount",
      "Status"
    ]);

    for (var order in orders) {
      rows.add([
        order.id,
        DateFormat('dd-MMM-yyyy hh:mm a').format(order.createdAt ?? DateTime.now()),
        order.customerName,
        order.customerMobile ?? 'N/A',
        order.orderType,
        order.paymentType,
        order.itemCount,
        order.totalAmount,
        order.status
      ]);
    }

    String csvData = const CsvEncoder().convert(rows);
    await _saveAndShare(csvData, "${fileName}_${DateTime.now().millisecondsSinceEpoch}.csv");
  }

  Future<void> exportExpensesToCSV(List<Expense> expenses, {String fileName = 'expense_report'}) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      "Expense Title",
      "Date",
      "Amount",
      "Staff Member",
      "Payment Type",
      "Paid To",
      "Category"
    ]);

    for (var expense in expenses) {
      rows.add([
        expense.title,
        DateFormat('dd-MMM-yyyy').format(expense.date),
        expense.amount,
        expense.staffMember,
        expense.paymentType,
        expense.paidBy,
        expense.category ?? 'N/A'
      ]);
    }

    String csvData = const CsvEncoder().convert(rows);
    await _saveAndShare(csvData, "${fileName}_${DateTime.now().millisecondsSinceEpoch}.csv");
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  Future<void> exportOrdersToPDF(List<OrderModel> orders, {String fileName = 'sales_report'}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text("Sales Report - BulkBites", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
            ),
            pw.SizedBox(height: 10),
            pw.Text("Generated on: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}"),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ["Date", "Customer", "Type", "Payment", "Amount"],
              data: orders.map((o) => [
                DateFormat('dd-MMM HH:mm').format(o.createdAt ?? DateTime.now()),
                o.customerName,
                o.orderType,
                o.paymentType,
                "Rs ${o.totalAmount.toStringAsFixed(0)}"
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Total Revenue: Rs ${orders.fold(0.0, (sum, o) => sum + o.totalAmount).toStringAsFixed(0)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Sales Report PDF',
      ),
    );
  }

  Future<void> exportExpensesToPDF(List<Expense> expenses, {String fileName = 'expense_report'}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text("Expense Report - BulkBites", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
            ),
            pw.SizedBox(height: 10),
            pw.Text("Generated on: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}"),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ["Date", "Title", "Staff", "Payment", "Amount"],
              data: expenses.map((e) => [
                DateFormat('dd-MMM').format(e.date),
                e.title,
                e.staffMember,
                e.paymentType,
                "Rs ${e.amount.toStringAsFixed(0)}"
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Total Expenses: Rs ${expenses.fold(0.0, (sum, e) => sum + e.amount).toStringAsFixed(0)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Expense Report PDF',
      ),
    );
  }

  // ============================================================
  // HELPER
  // ============================================================

  Future<void> _saveAndShare(String data, String fileName) async {
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/$fileName";
    final file = File(path);
    await file.writeAsString(data);
    
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'Report Export',
      ),
    );
  }
}
