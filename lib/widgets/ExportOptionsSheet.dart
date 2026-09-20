import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ExportService.dart';
import '../services/FirestoreService.dart';
import '../utlity/AppColors.dart';

enum ExportType { orders, expenses }
enum DateRangeType { today, thisWeek, thisMonth, thisYear, custom }

class ExportOptionsSheet extends StatefulWidget {
  final ExportType exportType;
  final Map<String, dynamic>? additionalFilters;
  final String? title;

  const ExportOptionsSheet({
    super.key,
    required this.exportType,
    this.additionalFilters,
    this.title,
  });

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  DateRangeType _selectedRange = DateRangeType.today;
  String _selectedFormat = 'PDF';
  DateTimeRange? _customRange;
  bool _isExporting = false;

  DateTimeRange _calculateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case DateRangeType.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DateRangeType.thisWeek:
        // Find Monday of this week
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: now,
        );
      case DateRangeType.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case DateRangeType.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      case DateRangeType.custom:
        return _customRange ?? DateTimeRange(start: now, end: now);
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    final range = _calculateRange();
    final filters = Map<String, dynamic>.from(widget.additionalFilters ?? {});
    
    // Check if we should use businessDate for orders
    bool useBusinessDate = false;
    if (widget.exportType == ExportType.orders) {
      final settings = await FirestoreService().getVendorDetails();
      if (settings != null && (settings['isCustomBusinessDay'] ?? false)) {
        useBusinessDate = true;
      }
    }

    if (useBusinessDate) {
      filters['businessDateRange'] = [
        DateFormat('yyyyMMdd').format(range.start),
        DateFormat('yyyyMMdd').format(range.end),
      ];
    } else {
      filters['dateRange'] = range;
    }

    try {
      if (widget.exportType == ExportType.orders) {
        final data = await FirestoreService().getOrdersStream(filters: filters).first;
        if (data.isEmpty) {
          _showNoDataError();
        } else {
          if (_selectedFormat == 'PDF') {
            await ExportService().exportOrdersToPDF(data);
          } else {
            await ExportService().exportOrdersToCSV(data);
          }
          if (mounted) Navigator.pop(context);
        }
      } else {
        final data = await FirestoreService().getExpensesStream(filters: filters).first;
        if (data.isEmpty) {
          _showNoDataError();
        } else {
          if (_selectedFormat == 'PDF') {
            await ExportService().exportExpensesToPDF(data);
          } else {
            await ExportService().exportExpensesToCSV(data);
          }
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Export failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showNoDataError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No records found for the selected range."), backgroundColor: Colors.orange),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondaryContainer: AppColors.primary2,
              onSecondaryContainer: AppColors.primary2,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedRange = DateRangeType.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.file_download, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                widget.title ?? "Export Report",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Select Date Range", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _RangeChip(label: "Today", type: DateRangeType.today, selected: _selectedRange, onSelect: (t) => setState(() => _selectedRange = t)),
              _RangeChip(label: "This Week", type: DateRangeType.thisWeek, selected: _selectedRange, onSelect: (t) => setState(() => _selectedRange = t)),
              _RangeChip(label: "This Month", type: DateRangeType.thisMonth, selected: _selectedRange, onSelect: (t) => setState(() => _selectedRange = t)),
              _RangeChip(label: "This Year", type: DateRangeType.thisYear, selected: _selectedRange, onSelect: (t) => setState(() => _selectedRange = t)),
              ActionChip(
                label: Text(_customRange == null 
                    ? "Custom Range" 
                    : "${DateFormat('dd MMM').format(_customRange!.start)} - ${DateFormat('dd MMM').format(_customRange!.end)}"),
                avatar: const Icon(Icons.calendar_today, size: 14),
                onPressed: _pickCustomRange,
                backgroundColor: _selectedRange == DateRangeType.custom ? AppColors.primary.withOpacity(0.1) : null,
                labelStyle: TextStyle(color: _selectedRange == DateRangeType.custom ? AppColors.primary : null),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Export Format", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              _FormatOption(label: "PDF Document", icon: Icons.picture_as_pdf, color: Colors.red, isSelected: _selectedFormat == 'PDF', onTap: () => setState(() => _selectedFormat = 'PDF')),
              const SizedBox(width: 16),
              _FormatOption(label: "Excel (CSV)", icon: Icons.table_chart, color: Colors.green, isSelected: _selectedFormat == 'CSV', onTap: () => setState(() => _selectedFormat = 'CSV')),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isExporting ? null : _handleExport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isExporting 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Generate and Share Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final DateRangeType type;
  final DateRangeType selected;
  final Function(DateRangeType) onSelect;

  const _RangeChip({required this.label, required this.type, required this.selected, required this.onSelect});


  @override
  Widget build(BuildContext context) {
    final isSelected = type == selected;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => onSelect(type),
      selectedColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textColor, fontWeight: isSelected ? FontWeight.bold : null),
    );
  }
}

class _FormatOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOption({required this.label, required this.icon, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null, color: isSelected ? color : null)),
            ],
          ),
        ),
      ),
    );
  }
}
