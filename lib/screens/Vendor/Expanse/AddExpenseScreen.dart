import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../model/Expense.dart';
import '../../../services/FirestoreService.dart';
import '../../../utlity/AppColors.dart';
import '../../../widgets/CommonTextField.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;
  const AddExpenseScreen({super.key, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}
class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _paidByController = TextEditingController();
  
  late DateTime _selectedDate;
  String? _selectedStaff;
  late String _selectedPaymentType;

  List<String> _staffMembers = [];
  final List<String> _paymentTypes = ['Cash', 'Online'];

  bool _isSaving = false;
  bool _isLoadingStaff = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.expense?.date ?? DateTime.now();
    _selectedPaymentType = widget.expense?.paymentType ?? 'Cash';
    
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _paidByController.text = widget.expense!.paidBy;
      _selectedStaff = widget.expense!.staffMember;
    }

    _loadStaffMembers();
  }

  Future<void> _loadStaffMembers() async {
    try {
      final list = await _firestoreService.getStaffList();
      setState(() {
        _staffMembers = list;
        if (_selectedStaff == null && _staffMembers.isNotEmpty) {
          _selectedStaff = _staffMembers.first;
        }
        _isLoadingStaff = false;
      });
    } catch (e) {
      debugPrint("Error loading staff: $e");
      setState(() => _isLoadingStaff = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _paidByController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a staff member in Shop Profile first!"), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
        'staffMember': _selectedStaff,
        'paymentType': _selectedPaymentType,
        'paidBy': _paidByController.text.trim(),
        'date': _selectedDate,
      };

      if (widget.expense != null) {
        await _firestoreService.updateExpense(
          widget.expense!.id!,
          data,
          widget.expense!.amount,
          widget.expense!.date,
        );
      } else {
        await _firestoreService.addExpense(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.expense != null 
            ? "Expense updated successfully!"
            : "Expense added successfully!"),
          backgroundColor: AppColors.success
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense != null ? "Edit Expense" : "Add Expense", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingStaff 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("General Information"),
              const SizedBox(height: 12),
              CommonTextField(
                controller: _titleController,
                label: "Expense Title",
                prefixIcon: Icons.description,
                hintText: "e.g. Electricity Bill",
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              CommonTextField(
                controller: _amountController,
                label: "Amount",
                prefixIcon: Icons.currency_rupee,
                hintText: "0.00",
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle("Payment Details"),
              const SizedBox(height: 12),
              if (_staffMembers.isEmpty)
                _buildAddStaffHint()
              else
                _buildDropdown("Staff Member", _selectedStaff, _staffMembers, (val) => setState(() => _selectedStaff = val!)),
              const SizedBox(height: 16),
              CommonTextField(
                controller: _paidByController,
                label: "Paid to",
                prefixIcon: Icons.person_outline,
                hintText: "Enter recipient name",
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              _buildDropdown("Payment Type", _selectedPaymentType, _paymentTypes, (val) => setState(() => _selectedPaymentType = val!)),

              const SizedBox(height: 24),
              _buildSectionTitle("Date"),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMMM, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.expense != null ? "Update Expense" : "Save Expense", 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddStaffHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "No staff members found. Please add them in Shop Profile -> Manage Staff.",
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.person, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}