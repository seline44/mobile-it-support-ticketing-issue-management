import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_header.dart';

const Color _adminBlue = AppTheme.accentTeal;
const Color _adminGreen = AppTheme.accentTeal;
const Color _adminAmber = AppTheme.warningGold;
const Color _adminRed = Color(0xFFDC2626);

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  final Set<int> _updatingUserIds = {};
  static const _filters = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await ApiService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _approvalStatus(Map<String, dynamic> user) {
    final status = (user['approval_status'] ?? 'Pending').toString().trim();
    if (status.toLowerCase() == 'approved') return 'Approved';
    if (status.toLowerCase() == 'rejected') return 'Rejected';
    if (status.toLowerCase() == 'pending') return 'Pending';
    return status.isEmpty ? 'Pending' : status;
  }

  int _countFor(String status) {
    if (status == 'All') return _users.length;
    return _users.where((item) {
      if (item is! Map) return false;
      return _approvalStatus(Map<String, dynamic>.from(item)).toLowerCase() ==
          status.toLowerCase();
    }).length;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final result = <Map<String, dynamic>>[];
    for (final item in _users) {
      if (item is! Map) continue;
      final user = Map<String, dynamic>.from(item);
      if (_selectedFilter == 'All' ||
          _approvalStatus(user).toLowerCase() ==
              _selectedFilter.toLowerCase()) {
        result.add(user);
      }
    }
    result.sort((a, b) {
      final nameA = (a['full_name'] ?? a['email'] ?? '')
          .toString()
          .toLowerCase();
      final nameB = (b['full_name'] ?? b['email'] ?? '')
          .toString()
          .toLowerCase();
      return nameA.compareTo(nameB);
    });
    return result;
  }

  int? _userId(Map<String, dynamic> user) {
    final rawId = user['id'] ?? user['user_id'];
    return rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
  }

  Future<void> _updateApproval(Map<String, dynamic> user, String status) async {
    final userId = _userId(user);
    if (userId == null) {
      _showMessage('Could not identify this account.');
      return;
    }
    setState(() => _updatingUserIds.add(userId));
    try {
      await ApiService.updateUserApproval(
        userId: userId,
        approvalStatus: status,
      );
      if (!mounted) return;
      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;
          final itemId = item['id'] ?? item['user_id'];
          if (itemId.toString() == userId.toString()) {
            item['approval_status'] = status;
            break;
          }
        }
        _updatingUserIds.remove(userId);
      });
      _showMessage(
        status == 'Approved'
            ? 'Account approved successfully.'
            : 'Account rejected successfully.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(userId));
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _linkWhatsAppNumber(Map<String, dynamic> user) async {
    final userId = _userId(user);
    if (userId == null) {
      _showMessage('Could not identify this account.');
      return;
    }
    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (_) => const _WhatsAppNumberDialog(),
    );
    if (phoneNumber == null || !mounted) return;

    setState(() => _updatingUserIds.add(userId));
    try {
      final result = await ApiService.linkWhatsAppNumber(
        userId: userId,
        phoneNumber: phoneNumber,
      );
      if (!mounted) return;
      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;
          final itemId = item['id'] ?? item['user_id'];
          if (itemId.toString() == userId.toString()) {
            item['whatsapp_phone_number'] = result['phone_number'];
            break;
          }
        }
        _updatingUserIds.remove(userId);
      });
      _showMessage(result['message']?.toString() ?? 'WhatsApp number linked.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(userId));
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _adminGreen;
      case 'pending':
        return _adminAmber;
      case 'rejected':
        return _adminRed;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleUsers = _filteredUsers;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoal,
        foregroundColor: Colors.white,
        title: const Text('Users and Technicians'),
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            buildUserHeader(context, roleTitle: 'Administrator', color: _adminBlue),
            const Text(
              'User Management',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'View registered accounts and manage registration approvals.',
              style: TextStyle(color: secondaryColor, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (!_isLoading && _errorMessage == null) ...[
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Total Users',
                      _countFor('All'),
                      _adminBlue,
                      Icons.people_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryCard(
                      'Pending',
                      _countFor('Pending'),
                      _adminAmber,
                      Icons.pending_actions_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Approved',
                      _countFor('Approved'),
                      _adminGreen,
                      Icons.verified_user_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryCard(
                      'Rejected',
                      _countFor('Rejected'),
                      _adminRed,
                      Icons.person_off_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Filter accounts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in _filters)
                    ChoiceChip(
                      label: Text('$filter (${_countFor(filter)})'),
                      selected: _selectedFilter == filter,
                      onSelected: (_) =>
                          setState(() => _selectedFilter = filter),
                      selectedColor: theme.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedFilter == filter
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _messageCard(
                icon: Icons.error_outline_rounded,
                title: _errorMessage!,
                message: 'Please refresh the account list and try again.',
                action: FilledButton(
                  onPressed: _loadUsers,
                  child: const Text('Try again'),
                ),
              )
            else if (visibleUsers.isEmpty)
              _messageCard(
                icon: _selectedFilter == 'Pending'
                    ? Icons.verified_user_outlined
                    : Icons.people_outline_rounded,
                title: _selectedFilter == 'Pending'
                    ? 'No pending registrations'
                    : 'No ${_selectedFilter.toLowerCase()} users',
                message: 'Try another filter or refresh the list.',
              )
            else ...[
              Text(
                '${visibleUsers.length} ${visibleUsers.length == 1 ? 'account' : 'accounts'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final user in visibleUsers) _buildUserCard(user),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, int count, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 14), action],
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final name =
        (user['full_name'] ??
                user['name'] ??
                user['username'] ??
                'Unnamed user')
            .toString();
    final email = (user['email'] ?? 'No email provided').toString();
    final role = (user['role'] ?? 'Reporter').toString();
    final status = _approvalStatus(user);
    final userId = _userId(user);
    final isUpdating = userId != null && _updatingUserIds.contains(userId);
    final isPending = status.toLowerCase() == 'pending';
    final canLinkWhatsApp =
        role.toLowerCase() == 'reporter' && status.toLowerCase() == 'approved';
    final linkedWhatsAppNumber = user['whatsapp_phone_number']?.toString();
    final roleColor = switch (role.toLowerCase()) {
      'technician' => _adminGreen,
      'administrator' => AppTheme.charcoal,
      _ => _adminBlue,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Icon(
                    role.toLowerCase() == 'technician'
                        ? Icons.support_agent_rounded
                        : role.toLowerCase() == 'administrator'
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline_rounded,
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        style: TextStyle(color: secondaryColor, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _UserPill(label: role, color: roleColor),
                          _UserPill(label: status, color: _statusColor(status)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isUpdating || userId == null
                          ? null
                          : () => _updateApproval(user, 'Rejected'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _adminRed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isUpdating || userId == null
                          ? null
                          : () => _updateApproval(user, 'Approved'),
                      icon: isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(isUpdating ? 'Updating...' : 'Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _adminGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (canLinkWhatsApp) ...[
              const SizedBox(height: 12),
              if (linkedWhatsAppNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'WhatsApp linked: $linkedWhatsAppNumber',
                    style: TextStyle(color: secondaryColor, fontSize: 13),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: isUpdating || userId == null
                    ? null
                    : () => _linkWhatsAppNumber(user),
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_outlined),
                label: Text(isUpdating ? 'Linking...' : 'Link WhatsApp'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WhatsAppNumberDialog extends StatefulWidget {
  const _WhatsAppNumberDialog();

  @override
  State<_WhatsAppNumberDialog> createState() => _WhatsAppNumberDialogState();
}

class _WhatsAppNumberDialogState extends State<_WhatsAppNumberDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link WhatsApp number'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Reporter phone number',
          hintText: '+254794045207',
          helperText: 'Use international format, starting with +.',
          errorText: _validationError,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final phone = _controller.text.trim();
            if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
              setState(
                () => _validationError = 'Enter a valid international number.',
              );
              return;
            }
            Navigator.pop(context, phone);
          },
          child: const Text('Link number'),
        ),
      ],
    );
  }
}

class _UserPill extends StatelessWidget {
  final String label;
  final Color color;

  const _UserPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
