import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';
import '../../shared/widgets/app_card.dart';

class ItAssetFormScreen extends ConsumerStatefulWidget {
  const ItAssetFormScreen({super.key});

  @override
  ConsumerState<ItAssetFormScreen> createState() => _ItAssetFormScreenState();
}

class _ItAssetFormScreenState extends ConsumerState<ItAssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _purchaseDateController = TextEditingController(text: '11/05/2026');
  final TextEditingController _costController = TextEditingController(text: '0');
  final TextEditingController _warrantyController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();

  final TextEditingController _processorController = TextEditingController();
  final TextEditingController _ramController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _productIdController = TextEditingController();
  final TextEditingController _systemTypeController = TextEditingController(text: '64-bit operating system, x64-based processor');
  final TextEditingController _penTouchController = TextEditingController(text: 'No pen or touch input is available for this display');
  final TextEditingController _notesController = TextEditingController();

  String _category = 'Laptop';
  final List<String> _categories = ['Laptop', 'Monitor', 'Desktop', 'Mobile', 'Accessory', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _purchaseDateController.dispose();
    _costController.dispose();
    _warrantyController.dispose();
    _vendorController.dispose();
    _processorController.dispose();
    _ramController.dispose();
    _deviceIdController.dispose();
    _productIdController.dispose();
    _systemTypeController.dispose();
    _penTouchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    final apiClient = ref.read(apiClientProvider);

    final payload = {
      'name': _nameController.text.trim(),
      'category': _category.toUpperCase(),
      if (_serialController.text.trim().isNotEmpty) 'serialNumber': _serialController.text.trim(),
      if (_purchaseDateController.text.trim().isNotEmpty) 'purchaseDate': _purchaseDateController.text.trim(),
      'purchaseCost': double.tryParse(_costController.text.trim()) ?? 0,
      if (_warrantyController.text.trim().isNotEmpty) 'warranty': _warrantyController.text.trim(),
      if (_vendorController.text.trim().isNotEmpty) 'vendor': _vendorController.text.trim(),
      if (_processorController.text.trim().isNotEmpty) 'processor': _processorController.text.trim(),
      if (_ramController.text.trim().isNotEmpty) 'ram': _ramController.text.trim(),
      if (_deviceIdController.text.trim().isNotEmpty) 'deviceId': _deviceIdController.text.trim(),
      if (_productIdController.text.trim().isNotEmpty) 'productId': _productIdController.text.trim(),
      if (_systemTypeController.text.trim().isNotEmpty) 'systemType': _systemTypeController.text.trim(),
      if (_penTouchController.text.trim().isNotEmpty) 'penTouch': _penTouchController.text.trim(),
      if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
      'status': 'AVAILABLE',
      'condition': 'GOOD',
    };

    try {
      await apiClient.post('/assets', body: payload).catchError((_) async {
        return await apiClient.post(ApiEndpoints.itAssets, body: payload);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset registered successfully into company inventory.'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final msg = e is ApiException ? e.message : 'Failed to register asset: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Add Asset',
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Register a new asset into the company inventory', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
              const SizedBox(height: 16),

              // General Asset Details Card
              AppCard(
                backgroundColor: cardBgColor,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                        SizedBox(width: 8),
                        Text('General Asset Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Asset Name *', hintText: 'e.g. Dell Latitude 5430', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Asset name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => _category = val ?? 'Laptop'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _serialController,
                            decoration: const InputDecoration(labelText: 'Serial Number', hintText: 'e.g. S/N 4FYHR23', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _purchaseDateController,
                            decoration: const InputDecoration(labelText: 'Purchase Date', suffixIcon: Icon(Icons.calendar_today, size: 16), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Purchase Cost (INR)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _warrantyController,
                            decoration: const InputDecoration(labelText: 'Warranty', hintText: 'e.g. 3 years', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _vendorController,
                            decoration: const InputDecoration(labelText: 'Vendor', hintText: 'e.g. Amazon Business', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hardware Specifications Card
              AppCard(
                backgroundColor: cardBgColor,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.settings_input_component_rounded, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8),
                        Text('Hardware Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _processorController,
                            decoration: const InputDecoration(labelText: 'Processor', hintText: 'e.g. Intel Core i7', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _ramController,
                            decoration: const InputDecoration(labelText: 'Installed RAM', hintText: 'e.g. 16.0 GB', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _deviceIdController,
                            decoration: const InputDecoration(labelText: 'Device ID', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _productIdController,
                            decoration: const InputDecoration(labelText: 'Product ID', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _systemTypeController,
                            decoration: const InputDecoration(labelText: 'System Type', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _penTouchController,
                            decoration: const InputDecoration(labelText: 'Pen & Touch', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes / Remarks', hintText: 'Optional remarks about this asset...', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Footer Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveAsset,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: Text(_isSaving ? 'Saving...' : 'Add Asset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
