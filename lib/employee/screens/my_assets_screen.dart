import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/asset_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_header.dart';

class MyAssetsScreen extends ConsumerStatefulWidget {
  final bool? showAppBar;
  const MyAssetsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyAssetsScreen> createState() => _MyAssetsScreenState();
}

class _MyAssetsScreenState extends ConsumerState<MyAssetsScreen> {
  bool get _showAppBar => widget.showAppBar ?? true;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _assets = [];
  List<dynamic> _softwareLicenses = [];
  List<dynamic> _requests = [];
  Map<String, dynamic> _stats = {};

  String _activeTab = 'inventory'; // 'inventory' or 'requests'
  bool _showRequestModal = false;
  String _requestCategory = 'LAPTOP';
  final _reasonController = TextEditingController();
  bool _requesting = false;
  String? _acknowledgingId;

  final List<Map<String, String>> _categories = [
    {'value': 'LAPTOP', 'label': 'Laptop / Notebook'},
    {'value': 'MONITOR', 'label': 'Monitor / Display'},
    {'value': 'MOBILE', 'label': 'Mobile Phone / Tablet'},
    {'value': 'ACCESSORY', 'label': 'Accessory (Keyboard/Mouse/Headset)'},
    {'value': 'OTHER', 'label': 'Other Equipment'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<dynamic> _extractList(dynamic res) {
    if (res == null) return [];
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'] as List;
      if (res['items'] is List) return res['items'] as List;
      if (res['assets'] is List) return res['assets'] as List;
      if (res['requests'] is List) return res['requests'] as List;
      if (res['result'] is List) return res['result'] as List;
      if (res['value'] is List) return res['value'] as List;
      if (res['data'] is Map) {
        final inner = res['data'] as Map;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['assets'] is List) return inner['assets'] as List;
        if (inner['requests'] is List) return inner['requests'] as List;
      }
    }
    return [];
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final assetService = ref.read(assetServiceProvider);

    try {
      final assetsRes = await assetService.getMyAssets().timeout(const Duration(seconds: 10));

      // Secondary sections: a failure here must not hide the main asset list.
      dynamic softwareRes;
      try {
        softwareRes = await assetService.rawGet(ApiEndpoints.itSoftwareMyAssignments).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[MyAssets] software load failed: $e');
      }

      dynamic requestsRes;
      try {
        requestsRes = await assetService.getMyAssetRequests().timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[MyAssets] requests load failed: $e');
      }

      if (!mounted) return;

      List<dynamic> assetList = _extractList(assetsRes);
      List<dynamic> softwareList = _extractList(softwareRes);
      List<dynamic> requestList = _extractList(requestsRes);

      final Map<String, dynamic> statsMap = {
        'total': assetList.length,
        'assigned': assetList.where((a) => a['acknowledgedAt'] != null).length,
      };

      setState(() {
        _assets = assetList;
        _softwareLicenses = softwareList;
        _requests = requestList;
        _stats = statsMap;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _assets = [];
          _softwareLicenses = [];
          _requests = [];
          _stats = {};
          _isLoading = false;
          _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _acknowledge(String assetId, String assetName) async {
    setState(() => _acknowledgingId = assetId);
    final assetService = ref.read(assetServiceProvider);
    try {
      await assetService.acknowledgeAsset(assetId).catchError((_) async {
        return await assetService.rawPost('/assets/assignments/$assetId/acknowledge', body: {});
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$assetName acknowledged. Asset is now in your use.'), backgroundColor: AppColors.success),
      );
      _fetchAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to acknowledge asset: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acknowledgingId = null);
    }
  }

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for your asset request.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _requesting = true);
    final assetService = ref.read(assetServiceProvider);
    try {
      await assetService.createAssetRequest({
        'category': _requestCategory,
        'reason': _reasonController.text.trim(),
      }).catchError((_) async {
        return await assetService.rawPost('/assets/request', body: {
          'category': _requestCategory,
          'reason': _reasonController.text.trim(),
        });
      });

      if (!mounted) return;
      setState(() {
        _showRequestModal = false;
        _requesting = false;
        _reasonController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset request submitted for approval.'), backgroundColor: AppColors.success),
      );
      _fetchAll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit asset request: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _categoryLabel(String val) {
    final c = _categories.firstWhere((x) => x['value'] == val, orElse: () => {'label': val});
    return c['label'] ?? val;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    if (_isLoading) {
      final skeleton = const ListSkeleton(itemCount: 4);
      if (!_showAppBar) return skeleton;
      return GlassScaffold(title: 'My Assets', body: skeleton);
    }

    final totalAssets = _stats['total'] ?? _assets.length;
    final availableAssets = _stats['available'] ?? 0;
    final assignedAssets = _stats['assigned'] ?? _assets.where((a) => a['acknowledgedAt'] != null).length;
    final underRepair = _stats['underRepair'] ?? 0;
    final pendingAckCount = _assets.where((a) => a['acknowledgedAt'] == null).length;

    final content = Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row matching web
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Assets',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View assets assigned to you, acknowledge and request new assets',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showRequestModal = true),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Asset', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Asset Inventory vs Asset Requests Tabs matching web
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _activeTab == 'inventory' ? const Color(0xFF0F6B66) : cardBgColor,
                        foregroundColor: _activeTab == 'inventory' ? Colors.white : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        side: BorderSide(color: _activeTab == 'inventory' ? const Color(0xFF0F6B66) : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0))),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() => _activeTab = 'inventory'),
                      child: Text('Asset Inventory (${_assets.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _activeTab == 'requests' ? const Color(0xFF0F6B66) : cardBgColor,
                        foregroundColor: _activeTab == 'requests' ? Colors.white : (isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        side: BorderSide(color: _activeTab == 'requests' ? const Color(0xFF0F6B66) : (isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0))),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() => _activeTab = 'requests'),
                      child: Text('Asset Requests (${_requests.length})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Error State / Content
                if (_error != null)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                          const SizedBox(height: 8),
                          Text('Failed to load assets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                          const SizedBox(height: 4),
                          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchAll,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_activeTab == 'inventory') ...[
                  // 7 Stat Cards Row matching web reference
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Total', value: '$totalAssets', icon: Icons.inventory_2_rounded, color: const Color(0xFF2563EB))),
                        const SizedBox(width: 6),
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Available', value: '$availableAssets', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF10B981))),
                        const SizedBox(width: 6),
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Assigned', value: '$assignedAssets', icon: Icons.assignment_ind_rounded, color: const Color(0xFF0284C7))),
                        const SizedBox(width: 6),
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Repair', value: '$underRepair', icon: Icons.build_rounded, color: const Color(0xFFF59E0B))),
                        const SizedBox(width: 6),
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Returned', value: '0', icon: Icons.assignment_return_rounded, color: const Color(0xFF8B5CF6))),
                        const SizedBox(width: 6),
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Lost', value: '0', icon: Icons.warning_amber_rounded, color: const Color(0xFFEF4444))),
                        const SizedBox(width: 6),
                        SizedBox(width: 110, child: _buildStatTile(cardBgColor, label: 'Pending', value: '$pendingAckCount', icon: Icons.hourglass_empty_rounded, color: const Color(0xFFD97706))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. ASSIGNED HARDWARE ASSETS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assigned Hardware Assets (${_assets.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _assets.isEmpty
                      ? AppCard(
                    backgroundColor: cardBgColor,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.laptop_outlined, size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No hardware assets are currently assigned to you.', style: TextStyle(fontSize: 12.5, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _assets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = _assets[index];
                      final assetName = a['assetName']?.toString() ?? a['name']?.toString() ?? 'Hardware Asset';
                      final assetCode = a['assetCode']?.toString() ?? a['assetTag']?.toString() ?? 'AST-001';
                      final acknowledged = a['acknowledgedAt'] != null;
                      final id = a['id']?.toString() ?? '';
                      final issued = _formatDate(a['issuedAt']?.toString());
                      final condition = a['condition']?.toString() ?? 'Good';
                      final notes = a['notes']?.toString();

                      return AppCard(
                        backgroundColor: cardBgColor,
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
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: const Color(0xFF0F6B66).withAlpha(30), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.laptop, color: Color(0xFF0F6B66), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(assetCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F6B66))),
                                        const SizedBox(height: 2),
                                        Text(assetName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                      ],
                                    ),
                                  ],
                                ),
                                StatusChip(status: acknowledged ? 'IN USE' : 'PENDING ACK'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Issued: $issued', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                Text('Condition: $condition', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              ],
                            ),
                            if (notes != null && notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Note: $notes', style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkMutedText : Colors.grey)),
                            ],
                            if (!acknowledged) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _acknowledgingId == id ? null : () => _acknowledge(id, assetName),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(_acknowledgingId == id ? 'Confirming...' : 'Acknowledge Receipt'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. ASSIGNED SOFTWARE & SUBSCRIPTIONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assigned Software & Subscriptions (${_softwareLicenses.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _softwareLicenses.isEmpty
                      ? AppCard(
                    backgroundColor: cardBgColor,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.key_outlined, size: 36, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No software licenses currently assigned to you.', style: TextStyle(fontSize: 12.5, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _softwareLicenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = _softwareLicenses[index];
                      final swName = s['licenseName']?.toString() ?? s['name']?.toString() ?? 'Software License';
                      final vendor = s['vendor']?.toString() ?? 'IT Subscription';
                      final assigned = _formatDate(s['assignedAt']?.toString());
                      final expiry = s['expiryDate'] != null ? _formatDate(s['expiryDate'].toString()) : 'Never';

                      return AppCard(
                        backgroundColor: cardBgColor,
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
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.green.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.code, color: Colors.green, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(vendor, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                        const SizedBox(height: 2),
                                        Text(swName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                      ],
                                    ),
                                  ],
                                ),
                                const StatusChip(status: 'ACTIVE SEAT'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Assigned On: $assigned', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                Text('Expires: $expiry', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // ASSET REQUESTS TAB
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Asset Requests Management (${_requests.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _requests.isEmpty
                      ? AppCard(
                    backgroundColor: cardBgColor,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text('You have not requested any assets.', style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                      ),
                    ),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = _requests[index];
                      final cat = _categoryLabel(r['category']?.toString() ?? 'LAPTOP');
                      final reqDate = _formatDate(r['requestedAt']?.toString() ?? r['createdAt']?.toString());
                      final reason = r['reason']?.toString() ?? '';
                      final status = r['status']?.toString() ?? 'PENDING';

                      return AppCard(
                        backgroundColor: cardBgColor,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                  const SizedBox(height: 2),
                                  Text('Requested on $reqDate${reason.isNotEmpty ? " • $reason" : ""}', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(status: status),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_showRequestModal) _buildRequestModal(context, isDark, cardBgColor),
      ],
    );

    if (!_showAppBar) return content;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'My Assets',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            tooltip: 'Request New Asset',
            onPressed: () => setState(() => _showRequestModal = true),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildStatTile(Color cardBgColor, {required String label, required String value, required IconData icon, required Color color}) {
    return AppCard(
      backgroundColor: cardBgColor,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRequestModal(BuildContext context, bool isDark, Color cardBgColor) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Request Asset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                    IconButton(onPressed: () => setState(() => _showRequestModal = false), icon: const Icon(Icons.close, size: 18)),
                  ],
                ),
                const Divider(height: 16),
                const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _requestCategory,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c['value']!, child: Text(c['label']!, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _requestCategory = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Why do you need this asset?',
                    filled: true,
                    fillColor: cardBgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _requesting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F6B66), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(_requesting ? 'Submitting...' : 'Submit Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}