import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/alert.dart';
import '../services/custom_alert_service.dart';
import '../services/subscription_service.dart';
import '../services/unit_service.dart';

class CustomAlertsScreen extends StatefulWidget {
  const CustomAlertsScreen({super.key});

  @override
  State<CustomAlertsScreen> createState() => _CustomAlertsScreenState();
}

class _CustomAlertsScreenState extends State<CustomAlertsScreen> {
  final _alertService = CustomAlertService();
  
  List<Alert> _alerts = [];
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _alertService.getAllAlerts();
      final stats = await _alertService.getAlertStats();
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddAlertDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAlertBottomSheet(
        onAdd: _addAlert,
      ),
    );
  }

  Future<void> _addAlert(String name, double threshold, String unit, String condition) async {
    try {
      await _alertService.createAlert(
        name: name,
        threshold: threshold,
        unit: unit,
        condition: condition,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Alert created successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create alert: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _deleteAlert(Alert alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Alert',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${alert.name}"?',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _alertService.deleteAlert(alert.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Alert deleted',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _toggleAlert(Alert alert) async {
    await _alertService.toggleAlert(alert.id);
    await _loadData();
  }

  void _showEditAlertDialog(Alert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAlertBottomSheet(
        onAdd: (name, threshold, unit, condition) async {
          alert.name = name;
          alert.threshold = threshold;
          alert.unit = unit;
          alert.condition = condition;
          await _alertService.updateAlert(alert);
          await _loadData();
        },
        existingAlert: alert,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFF8E53),
            Color(0xFFFFB366),
            Color(0xFFD4A8C8),
            Color(0xFFB8A9D4),
            Color(0xFF8BA4D0),
          ],
          stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Custom App Bar
            Container(
              padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(70),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.arrowLeft,
                        size: 20,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Alerts',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Get notified when temperature changes',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF6B35).withAlpha(100)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.crown, size: 14, color: Color(0xFFFF6B35)),
                        SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats Cards
            if (_stats != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: LucideIcons.bell,
                        label: 'Total',
                        value: '${_stats!['total_alerts']}',
                        color: const Color(0xFFFF6B35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: LucideIcons.volume2,
                        label: 'Active',
                        value: '${_stats!['active_alerts']}',
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: LucideIcons.zap,
                        label: 'Triggers',
                        value: '${_stats!['total_triggers']}',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Alerts List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                      ),
                    )
                  : _alerts.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _alerts.length,
                          itemBuilder: (context, index) {
                            final alert = _alerts[index];
                            return _alertCard(alert);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF111827),
          onPressed: _showAddAlertDialog,
          icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
          label: const Text(
            'New Alert',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(100)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF111827).withAlpha(140),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(75),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.bellOff,
                size: 48,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Alerts Yet',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first alert to get notified\nwhen temperature reaches your threshold',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF111827).withAlpha(160),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddAlertDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Create Alert',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(Alert alert) {
    final conditionIcon = alert.condition == 'above' 
        ? LucideIcons.trendingUp 
        : LucideIcons.trendingDown;
    final conditionColor = alert.condition == 'above' 
        ? const Color(0xFFFF4E50) 
        : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(alert.isActive ? 90 : 60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.isActive 
              ? const Color(0xFFFF6B35).withAlpha(100) 
              : Colors.white.withAlpha(80),
          width: alert.isActive ? 1.5 : 1,
        ),
        boxShadow: alert.isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withAlpha(30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEditAlertDialog(alert),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: conditionColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(conditionIcon, size: 18, color: conditionColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'If ${alert.condition} ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: const Color(0xFF111827).withAlpha(140),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${alert.threshold.toStringAsFixed(1)}°${alert.unit}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Toggle switch
                    Switch(
                      value: alert.isActive,
                      onChanged: (value) => _toggleAlert(alert),
                      activeColor: const Color(0xFF10B981),
                      activeTrackColor: const Color(0xFF10B981).withAlpha(100),
                      inactiveThumbColor: const Color(0xFF9CA3AF),
                      inactiveTrackColor: const Color(0xFF9CA3AF).withAlpha(100),
                    ),
                  ],
                ),

                if ((alert.triggerCount ?? 0) > 0 || !alert.isActive) ...[
                  const SizedBox(height: 12),
                  Divider(color: const Color(0xFF111827).withAlpha(20), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if ((alert.triggerCount ?? 0) > 0)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.zap,
                                size: 14,
                                color: const Color(0xFFF59E0B).withAlpha(200),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Triggered ${alert.triggerCount}x',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF111827).withAlpha(140),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!alert.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CA3AF).withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.volumeX,
                                size: 12,
                                color: const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // Delete button
                      GestureDetector(
                        onTap: () => _deleteAlert(alert),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add/Edit Alert Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _AddAlertBottomSheet extends StatefulWidget {
  final Function(String, double, String, String) onAdd;
  final Alert? existingAlert;

  const _AddAlertBottomSheet({
    required this.onAdd,
    this.existingAlert,
  });

  @override
  State<_AddAlertBottomSheet> createState() => _AddAlertBottomSheetState();
}

class _AddAlertBottomSheetState extends State<_AddAlertBottomSheet> {
  late TextEditingController _nameController;
  late String _unit;
  late double _threshold;
  late String _condition;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final currentUnit = UnitService.instance.unit;
    
    if (widget.existingAlert != null) {
      _nameController = TextEditingController(text: widget.existingAlert!.name);
      _unit = widget.existingAlert!.unit;
      _threshold = widget.existingAlert!.threshold;
      _condition = widget.existingAlert!.condition;
    } else {
      _nameController = TextEditingController();
      _unit = currentUnit == TempUnit.celsius ? 'C' 
            : currentUnit == TempUnit.fahrenheit ? 'F' 
            : 'K';
      _threshold = _unit == 'C' ? 37.8 : _unit == 'F' ? 100.0 : 310.9;
      _condition = 'above';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _minValue {
    if (_unit == 'C') return -50;
    if (_unit == 'F') return -58;
    return 223.15; // Kelvin
  }

  double get _maxValue {
    if (_unit == 'C') return 60;
    if (_unit == 'F') return 140;
    return 333.15; // Kelvin
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      widget.onAdd(_nameController.text.trim(), _threshold, _unit, _condition);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom;
    final isEdit = widget.existingAlert != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF5F0), Colors.white],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.bell,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Alert' : 'Create New Alert',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Alert Name
                const Text(
                  'Alert Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration: InputDecoration(
                    hintText: 'e.g., "Room too hot", "Freezing alert"',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an alert name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Temperature Unit
                const Text(
                  'Temperature Unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['C', 'F', 'K'].map((u) {
                    final isSelected = _unit == u;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            // Convert threshold when changing units
                            if (_unit == 'C' && u == 'F') {
                              _threshold = (_threshold * 9 / 5) + 32;
                            } else if (_unit == 'C' && u == 'K') {
                              _threshold = _threshold + 273.15;
                            } else if (_unit == 'F' && u == 'C') {
                              _threshold = (_threshold - 32) * 5 / 9;
                            } else if (_unit == 'F' && u == 'K') {
                              _threshold = (_threshold - 32) * 5 / 9 + 273.15;
                            } else if (_unit == 'K' && u == 'C') {
                              _threshold = _threshold - 273.15;
                            } else if (_unit == 'K' && u == 'F') {
                              _threshold = (_threshold - 273.15) * 9 / 5 + 32;
                            }
                            _unit = u;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            right: u == 'K' ? 0 : 8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFFFF6B35), Color(0xFFFF8555)],
                                  )
                                : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.grey[300]!,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B35).withAlpha(60),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '°$u',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF111827),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Threshold
                const Text(
                  'Temperature Threshold',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_threshold.toStringAsFixed(1)}°$_unit',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFFFF6B35),
                          inactiveTrackColor: Colors.grey[300],
                          thumbColor: const Color(0xFFFF6B35),
                          overlayColor: const Color(0xFFFF6B35).withAlpha(50),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _threshold,
                          min: _minValue,
                          max: _maxValue,
                          divisions: 100,
                          onChanged: (value) => setState(() => _threshold = value),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_minValue.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_maxValue.toStringAsFixed(0)}°',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Condition
                const Text(
                  'Trigger Condition',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _conditionButton(
                        label: 'Above',
                        icon: LucideIcons.trendingUp,
                        value: 'above',
                        color: const Color(0xFFFF4E50),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _conditionButton(
                        label: 'Below',
                        icon: LucideIcons.trendingDown,
                        value: 'below',
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isEdit ? 'Update Alert' : 'Create Alert',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conditionButton({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _condition == value;
    return GestureDetector(
      onTap: () => setState(() => _condition = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF111827),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
