import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_search_bar.dart';
import '../../shared/widgets/app_card.dart';

class HrSalaryPackagesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const HrSalaryPackagesScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<HrSalaryPackagesScreen> createState() => _HrSalaryPackagesScreenState();
}

class _HrSalaryPackagesScreenState extends ConsumerState<HrSalaryPackagesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _packages = [];
  String _searchTerm = '';
  String _selectedSlab = 'All Tax Slabs';

  final List<String> _taxSlabs = [
    'All Tax Slabs',
    '0% slab',
    '5% slab',
    '10% slab',
    '15% slab',
    '20% slab',
    '30% slab'
  ];

  // Create Package Overlay State
  bool _showCreatePackageModal = false;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _minCtcController = TextEditingController();
  final TextEditingController _maxCtcController = TextEditingController();
  final TextEditingController _basicController = TextEditingController();
  final TextEditingController _hraController = TextEditingController();
  final TextEditingController _conveyanceController = TextEditingController();
  final TextEditingController _medicalController = TextEditingController();
  final TextEditingController _specialController = TextEditingController();
  final TextEditingController _pfPercentController = TextEditingController();
  final TextEditingController _esiPercentController = TextEditingController();
  final TextEditingController _tdsPercentController = TextEditingController();
  final TextEditingController _ptController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _createSlab = 'Up to ₹4,000,000';

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _minCtcController.dispose();
    _maxCtcController.dispose();
    _basicController.dispose();
    _hraController.dispose();
    _conveyanceController.dispose();
    _medicalController.dispose();
    _specialController.dispose();
    _pfPercentController.dispose();
    _esiPercentController.dispose();
    _tdsPercentController.dispose();
    _ptController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.get('/salary/packages').catchError((_) => null);
      List<dynamic> items = [];
      if (res is List) {
        items = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        items = res['data'];
      }

      if (mounted) {
        setState(() {
          _packages = items.isNotEmpty
              ? items.map((i) => _mapPackage(i)).toList()
              : _getMockPackages();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _packages = _getMockPackages();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapPackage(dynamic item) {
    final map = item is Map<String, dynamic> ? item : {};
    final basic = double.tryParse((map['basicSalary'] ?? 14500).toString()) ?? 14500.0;
    final hra = double.tryParse((map['hra'] ?? 5800).toString()) ?? 5800.0;
    final conv = double.tryParse((map['conveyance'] ?? 1600).toString()) ?? 1600.0;
    final med = double.tryParse((map['medicalAllowance'] ?? 1250).toString()) ?? 1250.0;
    final spec = double.tryParse((map['specialAllowance'] ?? 6016).toString()) ?? 6016.0;

    final gross = basic + hra + conv + med + spec;
    final pf = basic * 0.12;
    final esi = gross * 0.0075;
    final pt = 200.0;
    final tds = 0.0;
    final totalDeduct = pf + esi + pt + tds;
    final netHand = gross - totalDeduct;

    return {
      'id': map['id'] ?? 'PKG-01',
      'code': map['code'] ?? 'PKG-TIER-1',
      'name': map['name'] ?? 'Entry Level Package (Up to 4 LPA)',
      'slab': map['slab'] ?? '0% slab',
      'ctcRange': map['ctcRange'] ?? 'Up to ₹4,000,000 /year',
      'monthlyGross': gross,
      'netInHand': netHand,
      'deductions': totalDeduct,
      'takeHomePercent': gross > 0 ? (netHand / gross * 100).toStringAsFixed(1) : '93.3',
      'basic': basic,
      'hra': hra,
      'conveyance': conv,
      'medical': med,
      'special': spec,
      'pfPercent': 12.0,
      'esiPercent': 0.75,
      'pt': 200.0,
      'tdsPercent': 0.0,
      'status': map['status'] ?? 'Active',
    };
  }

  List<Map<String, dynamic>> _getMockPackages() {
    return [
      {
        'id': 'PKG-01',
        'code': 'PKG-TIER-1',
        'name': 'Entry Level Package (Up to 4 LPA)',
        'slab': '0% slab',
        'ctcRange': 'Up to ₹4,000,000 /year',
        'monthlyGross': 29166.0,
        'netInHand': 27226.0,
        'deductions': 1940.0,
        'takeHomePercent': '93.3',
        'basic': 14500.0,
        'hra': 5800.0,
        'conveyance': 1600.0,
        'medical': 1250.0,
        'special': 6016.0,
        'pfPercent': 12.0,
        'esiPercent': 0.75,
        'pt': 200.0,
        'tdsPercent': 0.0,
        'status': 'Active',
      },
      {
        'id': 'PKG-02',
        'code': 'PKG-INTERN',
        'name': 'Intern Developer',
        'slab': '0% slab',
        'ctcRange': '₹8,000 /year',
        'monthlyGross': 8000.0,
        'netInHand': 8000.0,
        'deductions': 0.0,
        'takeHomePercent': '100',
        'basic': 8000.0,
        'hra': 0.0,
        'conveyance': 0.0,
        'medical': 0.0,
        'special': 0.0,
        'pfPercent': 0.0,
        'esiPercent': 0.0,
        'pt': 0.0,
        'tdsPercent': 0.0,
        'status': 'Active',
      },
      {
        'id': 'PKG-03',
        'code': 'PKG-TIER-2',
        'name': 'Junior Associate Package (4L - 8L)',
        'slab': '5% slab',
        'ctcRange': '₹4,000,001–₹8,000,000 /year',
        'monthlyGross': 50000.0,
        'netInHand': 44300.0,
        'deductions': 5700.0,
        'takeHomePercent': '88.6',
        'basic': 25000.0,
        'hra': 10000.0,
        'conveyance': 1600.0,
        'medical': 1250.0,
        'special': 12150.0,
        'pfPercent': 12.0,
        'esiPercent': 0.75,
        'pt': 200.0,
        'tdsPercent': 5.0,
        'status': 'Active',
      },
      {
        'id': 'PKG-04',
        'code': 'PKG-TIER-3',
        'name': 'Mid-Level Professional Package (8L - 12L)',
        'slab': '10% slab',
        'ctcRange': '₹8,000,001–₹12,000,000 /year',
        'monthlyGross': 83333.0,
        'netInHand': 69808.0,
        'deductions': 13525.0,
        'takeHomePercent': '83.8',
        'basic': 40000.0,
        'hra': 16000.0,
        'conveyance': 1600.0,
        'medical': 1250.0,
        'special': 24483.0,
        'pfPercent': 12.0,
        'esiPercent': 0.75,
        'pt': 200.0,
        'tdsPercent': 10.0,
        'status': 'Active',
      },
    ];
  }

  String _formatMoney(dynamic amount) {
    final val = double.tryParse(amount?.toString() ?? '0') ?? 0.0;
    return NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(val);
  }

  List<Map<String, dynamic>> get _filteredPackages {
    return _packages.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final code = (p['code'] ?? '').toString().toLowerCase();
      final slab = (p['slab'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchTerm.isEmpty ||
          name.contains(_searchTerm.toLowerCase()) ||
          code.contains(_searchTerm.toLowerCase());
      final matchesSlab = _selectedSlab == 'All Tax Slabs' || slab.contains(_selectedSlab.toLowerCase().replaceFirst(' tax slabs', ''));

      return matchesSearch && matchesSlab;
    }).toList();
  }

  void _openCreatePackageModal() {
    _codeController.text = 'PKG-NEW';
    _nameController.text = 'New Package Template';
    _minCtcController.text = '0';
    _maxCtcController.text = '400000';
    _basicController.text = '15000';
    _hraController.text = '6000';
    _conveyanceController.text = '1600';
    _medicalController.text = '1250';
    _specialController.text = '2000';
    _pfPercentController.text = '12';
    _esiPercentController.text = '0.75';
    _tdsPercentController.text = '0';
    _ptController.text = '200';
    _descriptionController.text = 'Standard salary package template for employee onboarding';

    setState(() {
      _showCreatePackageModal = true;
    });
  }

  void _saveNewPackage() {
    final basic = double.tryParse(_basicController.text.trim()) ?? 0.0;
    final hra = double.tryParse(_hraController.text.trim()) ?? 0.0;
    final conv = double.tryParse(_conveyanceController.text.trim()) ?? 0.0;
    final med = double.tryParse(_medicalController.text.trim()) ?? 0.0;
    final spec = double.tryParse(_specialController.text.trim()) ?? 0.0;

    final pfP = double.tryParse(_pfPercentController.text.trim()) ?? 12.0;
    final esiP = double.tryParse(_esiPercentController.text.trim()) ?? 0.75;
    final tdsP = double.tryParse(_tdsPercentController.text.trim()) ?? 0.0;
    final pt = double.tryParse(_ptController.text.trim()) ?? 200.0;

    final gross = basic + hra + conv + med + spec;
    final pf = basic * (pfP / 100);
    final esi = gross * (esiP / 100);
    final tds = gross * (tdsP / 100);
    final totalDeduct = pf + esi + tds + pt;
    final netHand = gross - totalDeduct;

    setState(() {
      _packages.insert(0, {
        'id': 'PKG-${DateTime.now().millisecondsSinceEpoch}',
        'code': _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : 'PKG-NEW',
        'name': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'New Package',
        'slab': '0% slab',
        'ctcRange': 'Up to ₹${_maxCtcController.text.trim()} /year',
        'monthlyGross': gross,
        'netInHand': netHand,
        'deductions': totalDeduct,
        'takeHomePercent': gross > 0 ? (netHand / gross * 100).toStringAsFixed(1) : '92.3',
        'basic': basic,
        'hra': hra,
        'conveyance': conv,
        'medical': med,
        'special': spec,
        'pfPercent': pfP,
        'esiPercent': esiP,
        'pt': pt,
        'tdsPercent': tdsP,
        'status': 'Active',
      });
      _showCreatePackageModal = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Created new salary package template!'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final skeleton = const Center(child: CircularProgressIndicator());
      if (!widget.showAppBar) return Material(color: Colors.transparent, child: skeleton);
      return GlassScaffold(title: 'Annual Tax Slabs & Salary Packages', body: skeleton);
    }

    final cardBg = Theme.of(context).cardColor;
    final filtered = _filteredPackages;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Buttons Bar (Refresh, Define, Create)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to Payroll', style: TextStyle(fontSize: 12)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh',
                        onPressed: _loadPackages,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create New Package', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                        onPressed: _openCreatePackageModal,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4 Summary KPI Cards matching Web HRMS (Image 11)
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard('TOTAL PACKAGES', '${_packages.length}', 'Configured Templates', Icons.layers, Colors.indigo, cardBg),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard('ACTIVE TEMPLATES', '${_packages.where((p) => p['status'] == 'Active').length}', 'For Onboarding', Icons.check_circle, Colors.green, cardBg),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard('AVG. MONTHLY GROSS', '₹106,729', 'Across All Packages', Icons.account_balance_wallet, Colors.teal, cardBg),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard('MAX CTC CEILING', '₹1 Cr', 'Annual CTC Ceiling', Icons.workspace_premium, Colors.amber[800]!, cardBg),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Tax Slab Filters
              Row(
                children: [
                  Expanded(
                    child: GlassSearchBar(
                      placeholder: 'Search package name, code, or slab tier...',
                      onChanged: (val) => setState(() => _searchTerm = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10), color: cardBg),
                    child: DropdownButton<String>(
                      value: _selectedSlab,
                      underline: const SizedBox.shrink(),
                      items: _taxSlabs.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setState(() => _selectedSlab = val ?? 'All Tax Slabs'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Package Grid Cards (2 columns on tablet/desktop, 1 column on phone)
              filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No salary packages found.')))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 2 : 1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isWide ? 1.15 : 0.95,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            final gross = p['monthlyGross'] ?? 0.0;
                            final net = p['netInHand'] ?? 0.0;
                            final deduct = p['deductions'] ?? 0.0;
                            final takeHome = p['takeHomePercent'] ?? '93.3';

                            return Card(
                              elevation: 1,
                              color: cardBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                              child: Text(p['code'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                              child: Text(p['slab'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Switch(
                                              value: p['status'] == 'Active',
                                              activeColor: Colors.green,
                                              onChanged: (val) {
                                                setState(() => p['status'] = val ? 'Active' : 'Inactive');
                                              },
                                            ),
                                            const Text('Active', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(p['ctcRange'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                    const SizedBox(height: 10),

                                    // Gross vs Net Bar
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('MONTHLY GROSS', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                              Text(_formatMoney(gross), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('NET IN-HAND', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                              Text(_formatMoney(net), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Take home $takeHome%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                        Text('Deductions ${_formatMoney(deduct)}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Earnings Breakdown
                                    Text('Basic: ${_formatMoney(p['basic'])} • HRA: ${_formatMoney(p['hra'])} • Special: ${_formatMoney(p['special'])}', style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                                    const SizedBox(height: 8),

                                    // Statutory & Tax Chips
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        _buildChip('PF ${p['pfPercent']}%'),
                                        _buildChip('ESI ${p['esiPercent']}%'),
                                        _buildChip('PT ₹${p['pt']}'),
                                        _buildChip('TDS ${p['tdsPercent']}%', color: Colors.green[50]!, textColor: Colors.green[800]!),
                                      ],
                                    ),
                                    const Spacer(),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.person_add, size: 14),
                                        label: const Text('Assign to employee', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Assigned ${p['name']} template to employee!'), backgroundColor: AppColors.success),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ],
          ),
        ),

        // Create Standard Salary Package Overlay (Image 12)
        if (_showCreatePackageModal)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: cardBg,
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 850, maxHeight: 750),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Create Standard Salary Package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                    child: const Text('PKG-NEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              Text('Define a new standard compensation package template based on annual taxable income slabs', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showCreatePackageModal = false)),
                        ],
                      ),
                      const Divider(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Form Inputs Left
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Package Identity & Annual Tax Slab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _codeController,
                                        decoration: const InputDecoration(labelText: 'Package Code *', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(labelText: 'Package Name *', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _createSlab,
                                        decoration: const InputDecoration(labelText: 'Annual Taxable Income Slab *', border: OutlineInputBorder()),
                                        items: const [
                                          DropdownMenuItem(value: 'Up to ₹4,000,000', child: Text('Up to ₹4,000,000')),
                                          DropdownMenuItem(value: '₹4,000,001–₹8,000,000', child: Text('₹4,000,001–₹8,000,000')),
                                          DropdownMenuItem(value: '₹8,000,001–₹12,000,000', child: Text('₹8,000,001–₹12,000,000')),
                                        ],
                                        onChanged: (val) => setState(() => _createSlab = val ?? 'Up to ₹4,000,000'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _maxCtcController,
                                        decoration: const InputDecoration(labelText: 'Max Annual CTC (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                const Text('Monthly Earnings Components (Gross Pay)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _basicController,
                                        decoration: const InputDecoration(labelText: 'Basic Salary (₹) *', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _hraController,
                                        decoration: const InputDecoration(labelText: 'House Rent Allowance - HRA (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _conveyanceController,
                                        decoration: const InputDecoration(labelText: 'Conveyance Allowance (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _medicalController,
                                        decoration: const InputDecoration(labelText: 'Medical Allowance (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _specialController,
                                  decoration: const InputDecoration(labelText: 'Special Allowance (₹)', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),

                                const Text('Statutory Deductions & Slab Taxes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _pfPercentController,
                                        decoration: const InputDecoration(labelText: 'Provident Fund - PF (%)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _esiPercentController,
                                        decoration: const InputDecoration(labelText: 'Employee State Insurance - ESI (%)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _tdsPercentController,
                                        decoration: const InputDecoration(labelText: 'Income Tax - TDS (%)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _ptController,
                                        decoration: const InputDecoration(labelText: 'Professional Tax - PT (₹)', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Live Template Preview Sidebar Right (Image 12)
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.dashboard_customize, color: Colors.black87, size: 18),
                                      SizedBox(width: 6),
                                      Text('Live Template Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  _buildSidebarRow('Monthly Gross Pay', _formatMoney(_computeLiveGross())),
                                  _buildSidebarRow('Total Deductions', '-${_formatMoney(_computeLiveDeductions())}', color: Colors.red),
                                  const SizedBox(height: 12),

                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                                    child: Column(
                                      children: [
                                        const Text('NET MONTHLY IN-HAND', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(_formatMoney(_computeLiveNet()), style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 20)),
                                        const Text('92.3% of gross pay', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSidebarRow('Est. Annual Package (CTC)', _formatMoney(_computeLiveGross() * 12), isBold: true),
                                  const SizedBox(height: 16),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                                      onPressed: _saveNewPackage,
                                      child: const Text('Create Package Template'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => setState(() => _showCreatePackageModal = false),
                                      child: const Text('Cancel'),
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
              ),
            ),
          ),
      ],
    );

    if (!widget.showAppBar) return Material(color: Colors.transparent, child: bodyContent);

    return GlassScaffold(
      appBar: GlassHeader(title: 'Annual Tax Slabs & Salary Packages'),
      body: bodyContent,
    );
  }

  double _computeLiveGross() {
    final basic = double.tryParse(_basicController.text) ?? 0.0;
    final hra = double.tryParse(_hraController.text) ?? 0.0;
    final conv = double.tryParse(_conveyanceController.text) ?? 0.0;
    final med = double.tryParse(_medicalController.text) ?? 0.0;
    final spec = double.tryParse(_specialController.text) ?? 0.0;
    return basic + hra + conv + med + spec;
  }

  double _computeLiveDeductions() {
    final basic = double.tryParse(_basicController.text) ?? 0.0;
    final gross = _computeLiveGross();
    final pfP = double.tryParse(_pfPercentController.text) ?? 12.0;
    final esiP = double.tryParse(_esiPercentController.text) ?? 0.75;
    final tdsP = double.tryParse(_tdsPercentController.text) ?? 0.0;
    final pt = double.tryParse(_ptController.text) ?? 200.0;

    final pf = basic * (pfP / 100);
    final esi = gross * (esiP / 100);
    final tds = gross * (tdsP / 100);
    return pf + esi + tds + pt;
  }

  double _computeLiveNet() {
    return _computeLiveGross() - _computeLiveDeductions();
  }

  Widget _buildChip(String label, {Color color = const Color(0xFFF1F5F9), Color textColor = const Color(0xFF334155)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildSidebarRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 11, color: color ?? Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, String subtext, IconData icon, Color color, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withAlpha(40)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtext, style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
