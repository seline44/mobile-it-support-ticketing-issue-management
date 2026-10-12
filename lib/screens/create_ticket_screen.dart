import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/ticket_service.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  static const Color navy = Color(0xFF12355B);
  static const Color blue = Color(0xFF2563EB);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _deviceController =
      TextEditingController();

  final TextEditingController _locationController =
      TextEditingController();

  final List<String> _categories = [
    'Hardware',
    'Software',
    'Network',
    'Email',
    'Account Access',
    'Printing',
    'Other',
  ];

  final List<String> _levels = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  String? _selectedCategory;
  String _selectedImpact = 'Low';
  String _selectedUrgency = 'Low';

  String get _calculatedPriority {
    if (_selectedImpact == 'Critical' ||
        _selectedUrgency == 'Critical') {
      return 'Critical';
    }

    if (_selectedImpact == 'High' ||
        _selectedUrgency == 'High') {
      return 'High';
    }

    if (_selectedImpact == 'Medium' ||
        _selectedUrgency == 'Medium') {
      return 'Medium';
    }

    return 'Low';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _deviceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submitTicket() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category.'),
        ),
      );
      return;
    }

    final String priority = _calculatedPriority;

    final Ticket ticket = Ticket(
      id: TicketService.generateTicketId(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory!,
      impact: _selectedImpact,
      urgency: _selectedUrgency,
      priority: priority,
      device: _deviceController.text.trim(),
      location: _locationController.text.trim(),
      status: 'Open',
      createdAt: DateTime.now(),
    );

    TicketService.addTicket(ticket);

    _showSuccessDialog(ticket);
  }

  void _showSuccessDialog(Ticket ticket) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: success,
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ticket Submitted',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your IT support request has been submitted successfully.',
                style: TextStyle(
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ticket ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.id,
                      style: const TextStyle(
                        fontSize: 17,
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _priorityBadge(ticket.priority),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Support Ticket',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            22,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pageIntro(),

              const SizedBox(height: 24),

              _sectionTitle(
                'Issue Details',
                'Describe the problem you need help with.',
              ),

              const SizedBox(height: 14),

              _textField(
                controller: _titleController,
                label: 'Issue Title',
                hint: 'e.g. Unable to connect to Wi-Fi',
                icon: Icons.title_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an issue title.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              _textField(
                controller: _descriptionController,
                label: 'Description',
                hint:
                    'Describe what is happening and any error messages.',
                icon: Icons.description_outlined,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 26),

              _sectionTitle(
                'Classification',
                'Help us understand the impact and urgency.',
              ),

              const SizedBox(height: 14),

              _dropdownField(
                label: 'Category',
                value: _selectedCategory,
                hint: 'Select issue category',
                icon: _categoryIcon(
                  _selectedCategory ?? '',
                ),
                items: _categories,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              _dropdownField(
                label: 'Impact',
                value: _selectedImpact,
                hint: 'Select impact',
                icon: Icons.groups_outlined,
                items: _levels,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedImpact = value;
                  });
                },
              ),

              const SizedBox(height: 14),

              _dropdownField(
                label: 'Urgency',
                value: _selectedUrgency,
                hint: 'Select urgency',
                icon: Icons.schedule_outlined,
                items: _levels,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedUrgency = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              _priorityCard(),

              const SizedBox(height: 26),

              _sectionTitle(
                'Device & Location',
                'Provide information that can help the technician.',
              ),

              const SizedBox(height: 14),

              _textField(
                controller: _deviceController,
                label: 'Device',
                hint: 'e.g. HP ProBook 450 G8',
                icon: Icons.devices_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the affected device.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              _textField(
                controller: _locationController,
                label: 'Location',
                hint: 'e.g. Library, Lab 2, Office 304',
                icon: Icons.location_on_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the location.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submitTicket,
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 20,
                  ),
                  label: const Text(
                    'Submit Support Ticket',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  'You can track your ticket from the dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report an IT Issue',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Provide a few details about the problem so the support team can assist you.',
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 14,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Icon(
          icon,
          color: navy,
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 14 : 16,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF98A2B3),
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: blue,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      isExpanded: true,
      style: const TextStyle(
        fontSize: 14,
        color: textPrimary,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textSecondary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: navy,
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF98A2B3),
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: blue,
            width: 1.4,
          ),
        ),
      ),
      items: items.map(
        (item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _priorityCard() {
    final String priority = _calculatedPriority;
    final Color color = _priorityColor(priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: blue.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.flag_outlined,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calculated Priority',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  priority,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Auto',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    final Color color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFDC2626);
      case 'High':
        return warning;
      case 'Medium':
        return blue;
      case 'Low':
        return textSecondary;
      default:
        return textSecondary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Hardware':
        return Icons.devices_outlined;
      case 'Software':
        return Icons.apps_outlined;
      case 'Network':
        return Icons.wifi_rounded;
      case 'Email':
        return Icons.email_outlined;
      case 'Account Access':
        return Icons.lock_outline_rounded;
      case 'Printing':
        return Icons.print_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }
}