import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/alert.dart';
import '../services/custom_alert_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';

class CustomAlertsScreen extends StatefulWidget {
  const CustomAlertsScreen({super.key});

  @override
  State<CustomAlertsScreen> createState() => _CustomAlertsScreenState();
}

class _CustomAlertsScreenState extends State<CustomAlertsScreen> {
  final _alertService = CustomAlertService();
  final _storage = StorageService();
  final _subscription = SubscriptionService();
  
  List<Alert> _alerts = [];
  String _selectedUnit = 'C';
  double _sliderValue = 37.8;
  String _conditionValue = 'above';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final alerts = await _alertService.getAllAlerts();
    setState(() => _alerts = alerts);
  }

  void _showAddAlertDialog() {
    if (!_subscription.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Premium feature - upgrade to use custom alerts',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddAlertDialog(
        onAdd: _addAlert,
        selectedUnit: _selectedUnit,
        initialValue: _sliderValue,
        condition: _conditionValue,
      ),
    );
  }

  Future<void> _addAlert(String name, double threshold, String unit, String condition) async {
    await _alertService.createAlert(
      name: name,
      threshold: threshold,
      unit: unit,
      condition: condition,
    );
    await _loadAlerts();
  }

  Future<void> _deleteAlert(int id) async {
    await _alertService.deleteAlert(id);
    await _loadAlerts();
  }

  Future<void> _toggleAlert(int id) async {
    await _alertService.toggleAlert(id);
    await _loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        foregroundColor: Colors.white,
        title: const Text('Custom Alerts'),
        elevation: 0,
      ),
      body: _alerts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.bell,
                      size: 64,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No alerts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first alert to get notified',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _alertCard(alert);
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6B35),
        onPressed: _showAddAlertDialog,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _alertCard(Alert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isActive ? const Color(0xFFFF6B35) : Colors.grey[800]!,
          width: alert.isActive ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Notify if ${alert.condition} ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                        TextSpan(
                          text: '${alert.threshold}${alert.unit}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((alert.triggerCount ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Triggered ${alert.triggerCount} time(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[300],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    alert.isActive ? LucideIcons.volume2 : LucideIcons.volumeX,
                    color: alert.isActive ? Colors.green[400] : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => _toggleAlert(alert.id),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash2,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _deleteAlert(alert.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAlertDialog extends StatefulWidget {
  final Function(String, double, String, String) onAdd;
  final String selectedUnit;
  final double initialValue;
  final String condition;

  const _AddAlertDialog({
    required this.onAdd,
    required this.selectedUnit,
    required this.initialValue,
    required this.condition,
  });

  @override
  State<_AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends State<_AddAlertDialog> {
  late TextEditingController _nameController;
  late String _unit;
  late double _threshold;
  late String _condition;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _unit = widget.selectedUnit;
    _threshold = widget.initialValue;
    _condition = widget.condition;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1F),
      title: const Text(
        'Add Custom Alert',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Alert name (e.g., "Room too hot")',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Unit selector
            Row(
              children: ['C', 'F', 'K'].map((u) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _unit = u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _unit == u
                            ? const Color(0xFFFF6B35)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        u,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Threshold slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Threshold: ${_threshold.toStringAsFixed(1)}$_unit',
                  style: const TextStyle(color: Colors.white),
                ),
                Slider(
                  value: _threshold,
                  min: _unit == 'C' ? -50 : _unit == 'F' ? -58 : 223.15,
                  max: _unit == 'C' ? 60 : _unit == 'F' ? 140 : 333.15,
                  activeColor: const Color(0xFFFF6B35),
                  inactiveColor: Colors.grey[700],
                  onChanged: (value) => setState(() => _threshold = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Condition
            Row(
              children: ['above', 'below'].map((c) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _condition = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _condition == c
                            ? const Color(0xFFFF6B35)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B35),
          ),
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please enter alert name',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            widget.onAdd(_nameController.text, _threshold, _unit, _condition);
            Navigator.pop(context);
          },
          child: const Text('Add Alert'),
        ),
      ],
    );
  }
}
