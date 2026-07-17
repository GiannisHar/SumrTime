import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bar_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class StaffManagementTab extends StatefulWidget {
  const StaffManagementTab({super.key});

  @override
  State<StaffManagementTab> createState() => _StaffManagementTabState();
}

class _StaffManagementTabState extends State<StaffManagementTab> {
  List<dynamic> _staff   = [];
  bool          _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getStaff();
      setState(() => _staff = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load staff: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String staffId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove staff member'),
        content: Text('Remove $name from your team?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteStaff(staffId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddStaffSheet(onAdded: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OceanHeader(
          title: 'Staff',
          subtitle: '${_staff.length} members',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _load,
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: _showAddSheet,
              tooltip: 'Add staff',
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _staff.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No staff yet',
                      subtitle: 'Add cooks and waiters to your team',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _staff.length,
                      itemBuilder: (_, i) => _StaffCard(
                        member: _staff[i],
                        onDelete: () =>
                            _delete(_staff[i]['id'], _staff[i]['name']),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Staff card ────────────────────────────────────────────────────────────────
class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback onDelete;

  const _StaffCard({required this.member, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final role  = member['role'] as String;
    final isCook = role == 'cook';

    final roleColor = isCook ? const Color(0xFFFF7043) : AppTheme.seafoam;
    final roleIcon  = isCook ? Icons.soup_kitchen_rounded : Icons.delivery_dining_rounded;
    final roleLabel = isCook ? 'Cook' : 'Waiter';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pebble, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(roleIcon, color: roleColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'] as String,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: roleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: AppTheme.textSecondary.withOpacity(0.5)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Add staff bottom sheet ────────────────────────────────────────────────────
class _AddStaffSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddStaffSheet({required this.onAdded});

  @override
  State<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<_AddStaffSheet> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  String  _role    = 'cook';
  bool    _loading = false;
  String? _error;

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final pin  = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.addStaff(name, pin, _role);
      if (mounted) Navigator.pop(context);
      widget.onAdded();
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.pebble,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add staff member',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon:
                  Icon(Icons.person_outline_rounded, color: AppTheme.dune),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),

          // PIN field
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '4-digit PIN',
              prefixIcon: Icon(Icons.pin_outlined, color: AppTheme.dune),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Role picker
          Row(
            children: [
              _RoleChip(
                label: 'Cook',
                icon: Icons.soup_kitchen_rounded,
                color: const Color(0xFFFF7043),
                selected: _role == 'cook',
                onTap: () => setState(() => _role = 'cook'),
              ),
              const SizedBox(width: 10),
              _RoleChip(
                label: 'Waiter',
                icon: Icons.delivery_dining_rounded,
                color: AppTheme.seafoam,
                selected: _role == 'waiter',
                onTap: () => setState(() => _role = 'waiter'),
              ),
            ],
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    color: Colors.red,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600)),
          ],

          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ocean,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Add',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppTheme.pebble.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppTheme.pebble,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? color : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: selected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}