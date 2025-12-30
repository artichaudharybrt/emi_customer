import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class CreateEmiScreen extends StatefulWidget {
  const CreateEmiScreen({super.key});

  @override
  State<CreateEmiScreen> createState() => _CreateEmiScreenState();
}

class _CreateEmiScreenState extends State<CreateEmiScreen> {
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedPaymentSchedule;
  DateTime? _startDate;
  String _scheduleType = 'default'; // 'default' or 'custom'
  Set<int> _selectedDueDates = {};
  List<Map<String, dynamic>> _customScheduleItems = [];

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black87,
            size: Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create EMI',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: Responsive.padding(
                  context,
                  mobile: const EdgeInsets.all(16),
                  tablet: const EdgeInsets.all(20),
                  desktop: const EdgeInsets.all(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // EMI Details Section
                    _buildEmiDetailsSection(context),

                    SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

                    // Payment Schedule Section
                    _buildPaymentScheduleSection(context),

                    SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

                    // Schedule Type Selection
                    _buildScheduleTypeSelection(context),

                    // Custom Payment Schedule Section (only if custom is selected)
                    if (_scheduleType == 'custom') ...[
                      SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      _buildCustomPaymentScheduleSection(context),
                    ],

                    // Due Dates Selection (only if default is selected)
                    if (_scheduleType == 'default') ...[
                      SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),
                      _buildDueDatesSelection(context),
                    ],

                    SizedBox(height: Responsive.spacing(context, mobile: 80, tablet: 90, desktop: 100)),
                  ],
                ),
              ),
            ),

            // Bottom Create Button
            _buildCreateButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmiDetailsSection(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: const Color(0xFF1F6AFF),
                  size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                ),
              ),
              SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
              Text(
                'EMI Details',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

          // Principal and Interest Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 400;
              if (isSmallScreen) {
                return Column(
                  children: [
                    _buildAmountField(
                      context,
                      label: 'Principal',
                      hint: 'Principal',
                      controller: _principalController,
                      prefix: '₹',
                    ),
                    SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),
                    _buildAmountField(
                      context,
                      label: 'Interest Rate',
                      hint: 'Interest',
                      controller: _interestController,
                      prefix: '%',
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildAmountField(
                      context,
                      label: 'Principal',
                      hint: 'Principal',
                      controller: _principalController,
                      prefix: '₹',
                    ),
                  ),
                  SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                  Expanded(
                    child: _buildAmountField(
                      context,
                      label: 'Interest Rate',
                      hint: 'Interest',
                      controller: _interestController,
                      prefix: '%',
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),

          // Description Field
          _buildTextField(
            context,
            label: 'Description',
            hint: 'Description',
            controller: _descriptionController,
            icon: Icons.description,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required String prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
              color: Colors.grey.shade400,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: const BorderSide(color: Color(0xFF1F6AFF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
              vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, mobile: 6, tablet: 8, desktop: 10)),
        TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
              color: Colors.grey.shade400,
            ),
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    color: Colors.grey.shade600,
                    size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              borderSide: const BorderSide(color: Color(0xFF1F6AFF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
              vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentScheduleSection(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Schedule Dropdown
          _buildDropdownField(
            context,
            hint: 'Payment Schedule',
            value: _selectedPaymentSchedule,
            icon: Icons.calendar_today,
            onTap: () {
              // Handle dropdown tap
            },
          ),

          SizedBox(height: Responsive.spacing(context, mobile: 20, tablet: 24, desktop: 28)),

          // Start Date Input
          _buildDateField(
            context,
            label: 'Start Date *',
            value: _startDate,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (date != null) {
                setState(() => _startDate = date);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String hint,
    String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: Responsive.padding(
          context,
          mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          tablet: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
          ),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.grey.shade600,
              size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  color: value != null ? Colors.black87 : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey.shade600,
              size: Responsive.spacing(context, mobile: 24, tablet: 26, desktop: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: Responsive.padding(
              context,
              mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              tablet: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(
                Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
              ),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade600,
                  size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                ),
                SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day} ${_getMonthName(value.month)} ${value.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                      color: value != null ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTypeSelection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        if (isSmallScreen) {
          // Stack vertically on small screens
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScheduleTypeButton(
                context,
                title: 'Default Schedule',
                icon: Icons.calendar_today,
                isSelected: _scheduleType == 'default',
                onTap: () => setState(() => _scheduleType = 'default'),
              ),
              SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
              _buildScheduleTypeButton(
                context,
                title: 'Custom Schedule',
                icon: Icons.tune,
                isSelected: _scheduleType == 'custom',
                onTap: () => setState(() => _scheduleType = 'custom'),
              ),
            ],
          );
        }
        
        // Row layout for larger screens
        return Row(
          children: [
            Expanded(
              child: _buildScheduleTypeButton(
                context,
                title: 'Default Schedule',
                icon: Icons.calendar_today,
                isSelected: _scheduleType == 'default',
                onTap: () => setState(() => _scheduleType = 'default'),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
            Expanded(
              child: _buildScheduleTypeButton(
                context,
                title: 'Custom Schedule',
                icon: Icons.tune,
                isSelected: _scheduleType == 'custom',
                onTap: () => setState(() => _scheduleType = 'custom'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleTypeButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: Responsive.padding(
          context,
          mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F6AFF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(
            Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
          ),
          border: Border.all(
            color: isSelected ? const Color(0xFF1F6AFF) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: Responsive.spacing(context, mobile: 18, tablet: 20, desktop: 22),
            ),
            SizedBox(width: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPaymentScheduleSection(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Payment Schedule *',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
          
          // Add Button - Full width on small screens
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _customScheduleItems.add({
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'date': DateTime.now(),
                    'amount': 0.0,
                  });
                });
              },
              icon: Icon(
                Icons.add,
                size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
              ),
              label: Text(
                'Add',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F6AFF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.spacing(context, mobile: 14, tablet: 16, desktop: 18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                ),
                elevation: 0,
              ),
            ),
          ),

          SizedBox(height: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20)),

          // Custom Schedule Items List
          if (_customScheduleItems.isEmpty)
            Container(
              padding: Responsive.padding(
                context,
                mobile: const EdgeInsets.all(20),
                tablet: const EdgeInsets.all(24),
                desktop: const EdgeInsets.all(28),
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                ),
              ),
              child: Center(
                child: Text(
                  'No custom schedule items. Click "Add" to create one.',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._customScheduleItems.map((item) => Container(
                  margin: EdgeInsets.only(
                    bottom: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                  ),
                  padding: Responsive.padding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(18),
                    desktop: const EdgeInsets.all(20),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(
                      Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Item ${_customScheduleItems.indexOf(item) + 1}',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade400,
                          size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
                        ),
                        onPressed: () {
                          setState(() {
                            _customScheduleItems.remove(item);
                          });
                        },
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildDueDatesSelection(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Due Dates (Select days of month) *',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.columnsForWidth(
                MediaQuery.of(context).size.width,
                mobile: 5,
                tablet: 6,
                desktop: 7,
              ),
              mainAxisSpacing: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
              crossAxisSpacing: Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
              childAspectRatio: 1.0,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = _selectedDueDates.contains(day);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDueDates.remove(day);
                    } else {
                      _selectedDueDates.add(day);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1F6AFF) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(
                      Responsive.spacing(context, mobile: 8, tablet: 10, desktop: 12),
                    ),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1F6AFF) : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return Container(
      padding: Responsive.padding(
        context,
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Handle create EMI
            },
            icon: Icon(
              Icons.check,
              size: Responsive.spacing(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            label: Text(
              'Create EMI',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F6AFF),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: Responsive.spacing(context, mobile: 16, tablet: 18, desktop: 20),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.spacing(context, mobile: 12, tablet: 14, desktop: 16),
                ),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
