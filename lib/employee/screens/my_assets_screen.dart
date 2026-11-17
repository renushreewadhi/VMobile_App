// My Assets Screen - UI Polished
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
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;

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

    final content = RefreshIndicator(
      onRefresh: _fetchAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Header Banner (~76px total height)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'View assets assigned to you, acknowledge and request new assets',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _showRequestModal = true),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Add Asset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Segmented Control Tabs (Full width, height 40px, light gray track #F1F5F9, radius 12px)
            Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 'inventory'),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeTab == 'inventory' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Asset Inventory (${_assets.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _activeTab == 'inventory' ? FontWeight.w600 : FontWeight.w500,
                            color: _activeTab == 'inventory' ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 'requests'),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeTab == 'requests' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Asset Requests (${_requests.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _activeTab == 'requests' ? FontWeight.w600 : FontWeight.w500,
                            color: _activeTab == 'requests' ? Colors.white : (isDark ? AppColors.darkPrimaryText : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Error State / Content
            if (_error != null) ...[
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
              ),
            ] else if (_activeTab == 'inventory') ...[
              // 7 Status Chips Row (width 92px, height 64px, radius 14px, 1px #E5E7EB border, 8px gap)
              Stack(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildStatTile(cardBgColor, label: 'Total', value: '$totalAssets', icon: Icons.inventory_2_rounded, color: const Color(0xFF2563EB), isDark: isDark),
                        const SizedBox(width: 8),
                        _buildStatTile(cardBgColor, label: 'Available', value: '$availableAssets', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF10B981), isDark: isDark),
                        const SizedBox(width: 8),
                        _buildStatTile(cardBgColor, label: 'Assigned', value: '$assignedAssets', icon: Icons.assignment_ind_rounded, color: const Color(0xFF0284C7), isDark: isDark),
                        const SizedBox(width: 8),
                        _buildStatTile(cardBgColor, label: 'Repair', value: '$underRepair', icon: Icons.build_rounded, color: const Color(0xFFF59E0B), isDark: isDark),
                        const SizedBox(width: 8),
                        _buildStatTile(cardBgColor, label: 'Returned', value: '0', icon: Icons.assignment_return_rounded, color: const Color(0xFF8B5CF6), isDark: isDark),
                        const SizedBox(width: 8),
                        _buildStatTile(cardBgColor, label: 'Lost', value: '0', icon: Icons.warning_amber_rounded, color: const Color(0xFFEF4444), isDark: isDark),
                        const SizedBox(width: 8),
                        _buildStatTile(cardBgColor, label: 'Pending', value: '$pendingAckCount', icon: Icons.hourglass_empty_rounded, color: const Color(0xFFD97706), isDark: isDark),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 20,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground).withOpacity(0.0),
                              (isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. ASSIGNED HARDWARE ASSETS
              Text('Assigned Hardware Assets (${_assets.length})', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155))),
              const SizedBox(height: 8),
              _assets.isEmpty
                  ? Container(
                      height: 100,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.laptop_outlined, size: 24, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('No hardware assets are currently assigned to you.', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _assets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final a = _assets[index];
                        final assetName = a['assetName']?.toString() ?? a['name']?.toString() ?? 'Hardware Asset';
                        final assetCode = a['assetCode']?.toString() ?? a['assetTag']?.toString() ?? 'AST-001';
                        final acknowledged = a['acknowledgedAt'] != null;
                        final id = a['id']?.toString() ?? '';
                        final issued = _formatDate(a['issuedAt']?.toString());
                        final condition = a['condition']?.toString() ?? 'Good';
                        final notes = a['notes']?.toString();

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.laptop, color: AppColors.primary, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(assetCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              const SizedBox(height: 2),
                                              Text(assetName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
              const SizedBox(height: 16),

              // 2. ASSIGNED SOFTWARE & SUBSCRIPTIONS
              Text('Assigned Software & Subscriptions (${_softwareLicenses.length})', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155))),
              const SizedBox(height: 8),
              _softwareLicenses.isEmpty
                  ? Container(
                      height: 100,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.key_outlined, size: 24, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('No software licenses currently assigned to you.', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _softwareLicenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = _softwareLicenses[index];
                        final swName = s['licenseName']?.toString() ?? s['name']?.toString() ?? 'Software License';
                        final vendor = s['vendor']?.toString() ?? 'IT Subscription';
                        final assigned = _formatDate(s['assignedAt']?.toString());
                        final expiry = s['expiryDate'] != null ? _formatDate(s['expiryDate'].toString()) : 'Never';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.code, color: Colors.green, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(vendor, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                              const SizedBox(height: 2),
                                              Text(swName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText), overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
              Text('Asset Requests Management (${_requests.length})', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? AppColors.darkPrimaryText : const Color(0xFF334155))),
              const SizedBox(height: 8),
              _requests.isEmpty
                  ? Container(
                      height: 100,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                      ),
                      child: Center(
                        child: Text('You have not requested any assets.', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569))),
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

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.devices_other_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(cat, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                                        ),
                                        StatusChip(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text('Requested on $reqDate', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B))),
                                      ],
                                    ),
                                    if (reason.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('"$reason"', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppColors.darkMutedText : const Color(0xFF64748B))),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ],
        ),
      ),
    );

    final wrappedContent = Stack(
      children: [
        content,
        if (_showRequestModal) _buildRequestModal(context, isDark, cardBgColor),
      ],
    );

    if (!_showAppBar) return wrappedContent;

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'My Assets',
        actions: [
          SizedBox(
            width: 36,
            height: 36,
            child: Material(
              color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Request New Asset',
                onPressed: () => setState(() => _showRequestModal = true),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: wrappedContent,
    );
  }

  Widget _buildStatTile(Color cardBgColor, {required String label, required String value, required IconData icon, required Color color, required bool isDark}) {
    final numVal = int.tryParse(value) ?? 0;
    final valColor = numVal > 0 ? (isDark ? AppColors.darkPrimaryText : const Color(0xFF1E293B)) : const Color(0xFF64748B);

    return Container(
      width: 92,
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkMainSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: color),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: valColor),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestModal(BuildContext context, bool isDark, Color cardBgColor) {
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      color: Colors.black.withOpacity(0.45),
      alignment: Alignment.center,
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 32,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkMainSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Request Asset', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText)),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => setState(() => _showRequestModal = false),
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(Icons.close_rounded, size: 18, color: isDark ? AppColors.darkSecondaryText : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Text('Category', style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w500)),
                  const Text(' *', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: DropdownButtonFormField<String>(
                  value: _requestCategory,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.darkMainSurface : Colors.white,
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                  items: _categories.map((c) => DropdownMenuItem(value: c['value']!, child: Text(c['label']!, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _requestCategory = val);
                  },
                ),
              ),
              const SizedBox(height: 14),

              Text('Reason', style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 4,
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Why do you need this asset?',
                  hintStyle: TextStyle(color: isDark ? AppColors.darkMutedText : const Color(0xFF94A3B8), fontSize: 13),
                  filled: true,
                  fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(13, 110, 100, 0.22), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: ElevatedButton(
                    onPressed: _requesting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_requesting ? 'Submitting...' : 'Submit Request', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
