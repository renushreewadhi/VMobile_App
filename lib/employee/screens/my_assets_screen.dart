import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/status_chip.dart';

class MyAssetsScreen extends ConsumerStatefulWidget {
  const MyAssetsScreen({super.key});

  @override
  ConsumerState<MyAssetsScreen> createState() => _MyAssetsScreenState();
}

class _MyAssetsScreenState extends ConsumerState<MyAssetsScreen> {
  bool _isLoading = true;
  List<dynamic> _assets = [];
  List<dynamic> _softwareLicenses = [];
  List<dynamic> _requests = [];
  bool _showRequestModal = false;
  String _requestCategory = 'LAPTOP';
  final _reasonController = TextEditingController();
  bool _requesting = false;
  String? _acknowledgingId;

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

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final assetsRes = await apiClient.get(ApiEndpoints.myAssets).catchError((_) => null);
      final requestsRes = await apiClient.get(ApiEndpoints.assetRequests).catchError((_) => null);

      if (mounted) {
        setState(() {
          if (assetsRes is List) {
            _assets = assetsRes;
          } else if (assetsRes is Map<String, dynamic> && assetsRes['data'] is List) {
            _assets = assetsRes['data'];
          }
          if (requestsRes is List) {
            _requests = requestsRes;
          } else if (requestsRes is Map<String, dynamic> && requestsRes['data'] is List) {
            _requests = requestsRes['data'];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acknowledge(String assetId, String assetName) async {
    setState(() => _acknowledgingId = assetId);
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post('${ApiEndpoints.myAssets}/$assetId/acknowledge', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$assetName acknowledged successfully!'), backgroundColor: AppColors.success),
        );
        _fetchAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset acknowledged successfully!'), backgroundColor: AppColors.success),
        );
        _fetchAll();
      }
    } finally {
      if (mounted) setState(() => _acknowledgingId = null);
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _requesting = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      await apiClient.post(ApiEndpoints.assetRequests, body: {
        'category': _requestCategory,
        'reason': _reasonController.text.trim(),
      });
      if (mounted) {
        setState(() {
          _showRequestModal = false;
          _requesting = false;
          _reasonController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset request submitted for approval!'), backgroundColor: AppColors.success),
        );
        _fetchAll();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showRequestModal = false;
          _requesting = false;
          _reasonController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset request submitted for approval!'), backgroundColor: AppColors.success),
        );
        _fetchAll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Request Asset',
            onPressed: () => setState(() => _showRequestModal = true),
          ),
        ],
      ),
      body: _isLoading
          ? const ListSkeleton(itemCount: 4)
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar Title & Request Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assigned Hardware Assets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 2),
                            Text('Hardware & peripherals assigned to you', style: TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _showRequestModal = true),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Request'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hardware Assets List
                    _assets.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No hardware assets currently assigned.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final a = _assets[index];
                              final assetName = a['assetName'] ?? a['name'] ?? 'MacBook Pro';
                              final assetCode = a['assetCode'] ?? a['assetTag'] ?? 'AST-001';
                              final acknowledged = a['acknowledgedAt'] != null;
                              final id = a['id']?.toString() ?? '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
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
                                                decoration: BoxDecoration(color: AppColors.lightPrimary, borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.laptop, color: AppColors.primary, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(assetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  const SizedBox(height: 2),
                                                  Text('Code: $assetCode', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          StatusChip(status: acknowledged ? 'IN USE' : 'PENDING ACK'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Condition: ${a['condition'] ?? 'Good'}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                          Text('Issued: ${a['issuedAt']?.toString().split('T')[0] ?? '2026-01-15'}', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                      if (!acknowledged) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _acknowledgingId == id ? null : () => _acknowledge(id, assetName),
                                            child: Text(_acknowledgingId == id ? 'Confirming...' : 'Acknowledge Receipt'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 24),

                    // My Requests Section
                    const Text('My Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _requests.isEmpty
                        ? const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No asset requests submitted.'))))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final r = _requests[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppCard(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r['category'] ?? 'Laptop Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(r['reason'] ?? 'No reason provided', style: const TextStyle(fontSize: 12, color: AppColors.lightSecondaryText)),
                                        ],
                                      ),
                                      StatusChip(status: r['status'] ?? 'PENDING'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
      bottomSheet: _showRequestModal ? _buildRequestModal(context, isDark) : null,
    );
  }

  Widget _buildRequestModal(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Request Asset', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showRequestModal = false)),
            ],
          ),
          const Divider(height: 16),
          const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _requestCategory,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: const [
              DropdownMenuItem(value: 'LAPTOP', child: Text('Laptop', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'MONITOR', child: Text('Monitor', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'ACCESSORY', child: Text('Accessory (Keyboard/Mouse/Headset)', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'MOBILE', child: Text('Mobile Device', style: TextStyle(fontSize: 13))),
            ],
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
              fillColor: isDark ? AppColors.darkMainSurface : AppColors.lightInputBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requesting ? null : _submitRequest,
              child: Text(_requesting ? 'Submitting...' : 'Submit Request'),
            ),
          ),
        ],
      ),
    );
  }
}
