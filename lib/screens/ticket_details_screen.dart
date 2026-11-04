import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TicketDetailsScreen extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final String category;
  final String impact;
  final String urgency;
  final String device;
  final String location;
  final String status;
  final String? resolution;
  final String? assignedTechnician;
  final String? reporterName;
  final String? reporterPhone;
  final DateTime? lastModifiedAt;

  const TicketDetailsScreen({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.impact,
    required this.urgency,
    required this.device,
    required this.location,
    required this.status,
    this.resolution,
    this.assignedTechnician,
    this.reporterName,
    this.reporterPhone,
    this.lastModifiedAt,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _CompleteTicketDialog extends StatefulWidget {
  const _CompleteTicketDialog();

  @override
  State<_CompleteTicketDialog> createState() => _CompleteTicketDialogState();
}

class _CompleteTicketDialogState extends State<_CompleteTicketDialog> {
  final _resolutionController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedStatus = 'Resolved';

  @override
  void dispose() {
    _resolutionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete ticket'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'New status'),
              items: const [
                DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'Closed', child: Text('Closed')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedStatus = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _resolutionController,
              minLines: 2,
              maxLines: 4,
              maxLength: 10000,
              decoration: const InputDecoration(
                labelText: 'Resolution',
                hintText: 'Describe how the issue was fixed',
                alignLabelWithHint: true,
              ),
            ),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Internal work note (optional)',
                hintText: 'Only visible to technicians and administrators',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final resolution = _resolutionController.text.trim();
            if (resolution.isEmpty) return;
            Navigator.pop(context, {
              'status': _selectedStatus,
              'resolution': resolution,
              'note': _noteController.text.trim(),
            });
          },
          child: const Text('Save update'),
        ),
      ],
    );
  }
}

class _ReopenTicketDialog extends StatefulWidget {
  const _ReopenTicketDialog();

  @override
  State<_ReopenTicketDialog> createState() => _ReopenTicketDialogState();
}

class _ReopenTicketDialogState extends State<_ReopenTicketDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canReopen = _reasonController.text.trim().length >= 3;
    return AlertDialog(
      title: const Text('Reopen ticket'),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 2000,
        decoration: const InputDecoration(
          labelText: 'Why are you unsatisfied?',
          hintText: 'Explain what still needs attention',
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canReopen
              ? () => Navigator.pop(context, _reasonController.text.trim())
              : null,
          child: const Text('Reopen ticket'),
        ),
      ],
    );
  }
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _updates = [];
  bool _isLoadingHistory = true;
  String? _historyError;
  late String _status;
  String? _resolution;
  bool _isSavingStatus = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _resolution = widget.resolution;
    _loadHistory();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  static const Color blue = AppTheme.accentTeal;
  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;
  static const Color danger = Color(0xFFDC2626);

  Color _statusColor() {
    switch (_status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return success;
      case 'in progress':
        return blue;
      case 'open':
      default:
        return warning;
    }
  }

  Color _priorityColor() {
    if (widget.impact.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'critical') {
      return danger;
    }
    if (widget.urgency.toLowerCase() == 'high' ||
        widget.impact.toLowerCase() == 'high') {
      return warning;
    }
    return blue;
  }

  String _calculatedPriority() {
    if (widget.impact.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'critical') {
      return 'Critical';
    }
    if (widget.impact.toLowerCase() == 'high' ||
        widget.urgency.toLowerCase() == 'high') {
      return 'High';
    }
    if (widget.impact.toLowerCase() == 'medium' ||
        widget.urgency.toLowerCase() == 'medium') {
      return 'Medium';
    }
    return 'Low';
  }

  IconData _categoryIcon() {
    switch (widget.category.toLowerCase()) {
      case 'hardware':
        return Icons.devices_outlined;
      case 'software':
        return Icons.apps_outlined;
      case 'network':
        return Icons.wifi_rounded;
      case 'email':
        return Icons.email_outlined;
      case 'account access':
        return Icons.lock_outline_rounded;
      case 'printer':
      case 'printing':
        return Icons.print_outlined;
      default:
        return Icons.laptop_mac_outlined;
    }
  }

  Future<void> _loadHistory() async {
    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      setState(() {
        _historyError = 'Ticket activity is unavailable for this ticket ID.';
        _isLoadingHistory = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.getTicketHistory(ticketId),
        ApiService.getTicketNotes(ticketId),
      ]);
      final history = results[0];
      final notes = results[1];
      if (!mounted) return;
      final updates = <Map<String, dynamic>>[];
      for (final item in history.whereType<Map>()) {
        final entry = Map<String, dynamic>.from(item);
        final actor = entry['actor_name']?.toString();
        final action = entry['action']?.toString() ?? 'Ticket updated';
        final details = entry['details']?.toString();
        final title = [
          if (actor != null && actor.isNotEmpty) '$actor: ',
          action,
          if (details != null && details.isNotEmpty) ' - $details',
        ].join();
        updates.add({
          'title': title,
          'time': _formatHistoryTime(
            DateTime.parse(entry['created_at'].toString()),
          ),
          'sortTime': DateTime.parse(entry['created_at'].toString()),
        });
      }
      for (final item in notes.whereType<Map>()) {
        final entry = Map<String, dynamic>.from(item);
        final author = entry['author_name']?.toString();
        final isInternal = entry['is_internal'] == true;
        final createdAt = DateTime.parse(entry['created_at'].toString());
        updates.add({
          'title':
              '${isInternal ? '🔒 Internal note · ' : ''}'
              '${author == null || author.isEmpty ? 'User' : author}: '
              '${entry['note']}',
          'time': _formatHistoryTime(createdAt),
          'sortTime': createdAt,
        });
      }
      updates.sort(
        (a, b) =>
            (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime),
      );
      setState(() {
        _updates
          ..clear()
          ..addAll(updates);
        _historyError = null;
        _isLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _changeStatus() async {
    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const _CompleteTicketDialog(),
      );

      if (result == null) return;
      final ticketId = int.tryParse(widget.id);
      if (ticketId == null) {
        throw Exception('Could not identify this ticket.');
      }

      setState(() => _isSavingStatus = true);
      final updated = await ApiService.updateTicketStatus(
        ticketId: ticketId,
        status: result['status']!,
        resolution: result['resolution'],
        note: result['note']!.isEmpty ? null : result['note'],
      );
      if (!mounted) return;
      setState(() {
        _status = updated['status']?.toString() ?? result['status']!;
        _resolution = updated['resolution']?.toString() ?? result['resolution'];
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ticket $_status successfully.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted && _isSavingStatus) {
        setState(() => _isSavingStatus = false);
      }
    }
  }

  Future<void> _reopenTicket() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReopenTicketDialog(),
    );
    if (!mounted || reason == null) return;

    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this ticket.')),
      );
      return;
    }

    setState(() => _isSavingStatus = true);
    try {
      final result = await ApiService.reopenTicket(
        ticketId: ticketId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _status = result['status']?.toString() ?? 'Open';
        _resolution = result['resolution']?.toString() ?? _resolution;
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket reopened successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingStatus = false);
    }
  }

  String _formatHistoryTime(DateTime createdAt) {
    final date = createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final time = TimeOfDay.fromDateTime(date).format(context);
    if (dateOnly == today) return 'Today, $time';
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${date.month}/${date.day}/${date.year}, $time';
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this ticket.')),
      );
      return;
    }
    try {
      await ApiService.addTicketNote(ticketId: ticketId, note: comment);
      if (!mounted) return;
      _commentController.clear();
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add comment: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outlineVariant;

    final statusColor = _statusColor();
    final priority = _calculatedPriority();
    final priorityColor = _priorityColor();
    final isTechnician = ApiService.currentUser?['role'] == 'Technician';
    final isReporter = ApiService.currentUser?['role'] == 'Reporter';
    final isStaff = isTechnician ||
        ApiService.currentUser?['role'] == 'Administrator';
    final canViewRequester =
        isTechnician || ApiService.currentUser?['role'] == 'Administrator';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ticket Details',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_categoryIcon(), color: blue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.id.startsWith('#')
                                  ? widget.id
                                  : '#${widget.id}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                if (widget.lastModifiedAt != null)
                                  Text(
                                    _formatHistoryTime(widget.lastModifiedAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isTechnician && _status == 'In Progress') ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSavingStatus ? null : _changeStatus,
                        icon: _isSavingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.task_alt_rounded),
                        label: const Text('Resolve or close ticket'),
                      ),
                    ),
                  ],
                  if (isReporter &&
                      {'Resolved', 'Closed'}.contains(_status)) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSavingStatus ? null : _reopenTicket,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Reopen ticket'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If the issue is not fixed, tell us what still needs attention.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Metadata Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _metaRow(
                          'Category',
                          widget.category,
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Priority',
                          priority,
                          priorityColor,
                          textSecondary,
                          isBold: true,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Created',
                          'Today, 10:24 AM',
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Assigned to',
                          widget.assignedTechnician ?? 'Unassigned',
                          textPrimary,
                          textSecondary,
                        ),
                        if (canViewRequester &&
                            (widget.reporterName?.isNotEmpty == true ||
                                widget.reporterPhone?.isNotEmpty == true)) ...[
                          const Divider(height: 20),
                          _metaRow(
                            'Requested by',
                            widget.reporterName ?? 'WhatsApp requester',
                            textPrimary,
                            textSecondary,
                          ),
                          if (widget.reporterPhone?.isNotEmpty == true) ...[
                            const Divider(height: 20),
                            _metaRow(
                              'WhatsApp',
                              widget.reporterPhone!,
                              textPrimary,
                              textSecondary,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  if (_resolution != null && _resolution!.isNotEmpty) ...[
                    Text(
                      'Resolution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(_resolution!),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Updates Timeline Section
                  Text(
                    'Updates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingHistory)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_historyError != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  _historyError!,
                                  style: TextStyle(color: textSecondary),
                                ),
                                TextButton(
                                  onPressed: _loadHistory,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        else if (_updates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No activity recorded yet.',
                              style: TextStyle(color: textSecondary),
                            ),
                          )
                        else
                          for (int i = 0; i < _updates.length; i++)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: blue.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: blue,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < _updates.length - 1)
                                      Container(
                                        width: 2,
                                        height: 38,
                                        color: blue.withValues(alpha: 0.3),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _updates[i]['title']!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _updates[i]['time']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Comment & Send Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: isStaff
                          ? 'Add an internal note (staff only)...'
                          : 'Send an update to the support team...',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: blue, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: blue,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _addComment,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(
    String label,
    String value,
    Color valueColor,
    Color textSecondary, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
