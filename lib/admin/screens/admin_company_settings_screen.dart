import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/api_exception.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_header.dart';
import '../../core/widgets/glass_scaffold.dart';

class AdminCompanySettingsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const AdminCompanySettingsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<AdminCompanySettingsScreen> createState() => _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState extends ConsumerState<AdminCompanySettingsScreen> {
  bool get _showAppBar => widget.showAppBar;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController(text: 'Envision Beyond India Pvt Ltd');
  final TextEditingController _websiteController = TextEditingController(text: 'https://www.envisionbeyond.com');
  final TextEditingController _emailController = TextEditingController(text: 'admin@envisionbeyond.com');
  final TextEditingController _phoneController = TextEditingController(text: '+91-22-12345678');
  final TextEditingController _addressController = TextEditingController(text: 'Prarthana Raw House, 33, Anand Mahal Rd, Giriraj Society, Narotam Nagar, Surat, Gujarat 395009, India');
  final TextEditingController _cityController = TextEditingController(text: 'Surat');
  final TextEditingController _stateController = TextEditingController(text: 'Gujarat');
  final TextEditingController _countryController = TextEditingController(text: 'India');
  final TextEditingController _zipController = TextEditingController(text: '395009');
  final TextEditingController _regController = TextEditingController(text: 'U74999MH2020PTC345678');
  final TextEditingController _taxController = TextEditingController(text: 'GSTIN-27AAACH7409R1ZD');
  final TextEditingController _currencyController = TextEditingController(text: 'INR (₹)');
  final TextEditingController _fiscalYearController = TextEditingController(text: 'April');
  final TextEditingController _workingDaysController = TextEditingController(text: 'Mon - Sat');
  final TextEditingController _latController = TextEditingController(text: '21.1986872');
  final TextEditingController _lngController = TextEditingController(text: '72.7965515');
  final TextEditingController _radiusController = TextEditingController(text: '100');

  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _isFetchingGps = false;
  bool _isFetchingAddress = false;
  String? _lastSyncedGpsText;
  Marker? _liveLocationMarker;

  int _requestId = 0;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkUserAndLoad();
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    _regController.dispose();
    _taxController.dispose();
    _currencyController.dispose();
    _fiscalYearController.dispose();
    _workingDaysController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _updateLocationFromMap(LatLng latLng) {
    setState(() {
      _latController.text = latLng.latitude.toStringAsFixed(7);
      _lngController.text = latLng.longitude.toStringAsFixed(7);
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(latLng),
    );
    _fetchAddressFromCoordinates(latLng.latitude, latLng.longitude);
  }

  void _onCoordinatesChanged() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      setState(() {});
      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
      _fetchAddressFromCoordinates(lat, lng);
    }
  }

  Future<void> _fetchAddressFromCoordinates(double lat, double lng) async {
    if (!mounted) return;
    setState(() {
      _isFetchingAddress = true;
      _lastSyncedGpsText = '${lat.toStringAsFixed(6)} , ${lng.toStringAsFixed(6)}';
    });

    try {
      // 1. Try Google Maps Geocoding API if key is configured
      final googleApiKey = AppConfig.googleMapsApiKey;
      if (googleApiKey.isNotEmpty) {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$googleApiKey',
        );
        final res = await http.get(googleUrl).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
            final result = data['results'][0];
            final formattedAddress = result['formatted_address'];
            if (formattedAddress != null && formattedAddress.toString().trim().isNotEmpty) {
              if (mounted) {
                setState(() {
                  _addressController.text = formattedAddress.toString().trim();
                });

                final components = result['address_components'] as List?;
                if (components != null) {
                  for (var comp in components) {
                    final types = (comp['types'] as List?)?.cast<String>() ?? [];
                    final longName = comp['long_name']?.toString().trim() ?? '';
                    if (types.contains('locality') || types.contains('administrative_area_level_2')) {
                      if (longName.isNotEmpty) _cityController.text = longName;
                    }
                    if (types.contains('administrative_area_level_1')) {
                      if (longName.isNotEmpty) _stateController.text = longName;
                    }
                    if (types.contains('country')) {
                      if (longName.isNotEmpty) _countryController.text = longName;
                    }
                    if (types.contains('postal_code')) {
                      if (longName.isNotEmpty) _zipController.text = longName;
                    }
                  }
                }
              }
            }
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Fallback to OpenStreetMap Nominatim reverse geocoding API
    try {
      final osmUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final res = await http.get(osmUrl, headers: {
        'User-Agent': 'EtapriseHRMS/1.0',
      }).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final displayName = data['display_name'];
        if (displayName != null && displayName.toString().trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _addressController.text = displayName.toString().trim();
            });

            final addrObj = data['address'];
            if (addrObj is Map<String, dynamic>) {
              final city = addrObj['city'] ?? addrObj['town'] ?? addrObj['village'] ?? addrObj['county'] ?? addrObj['suburb'];
              final state = addrObj['state'];
              final country = addrObj['country'];
              final postcode = addrObj['postcode'];

              if (city != null) _cityController.text = city.toString();
              if (state != null) _stateController.text = state.toString();
              if (country != null) _countryController.text = country.toString();
              if (postcode != null) _zipController.text = postcode.toString();
            }
          }
        }
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isFetchingAddress = false);
      }
    }
  }

  Future<Position?> _getCurrentPosition() async {
    setState(() => _isFetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable GPS.')),
          );
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied permanently. Please allow in settings.')),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch GPS location: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isFetchingGps = false);
    }
  }

  Future<void> _pinCurrentGpsAsHq() async {
    final pos = await _getCurrentPosition();
    if (pos != null) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      _updateLocationFromMap(latLng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current GPS position pinned as HQ location!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Future<void> _showLiveLocation() async {
    final pos = await _getCurrentPosition();
    if (pos != null) {
      final liveLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _liveLocationMarker = Marker(
          markerId: const MarkerId('live_user_position'),
          position: liveLatLng,
          infoWindow: const InfoWindow(title: '📍 Live Device Position'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
      });

      final hqLat = double.tryParse(_latController.text.trim()) ?? pos.latitude;
      final hqLng = double.tryParse(_lngController.text.trim()) ?? pos.longitude;

      final southWest = LatLng(
        hqLat < pos.latitude ? hqLat : pos.latitude,
        hqLng < pos.longitude ? hqLng : pos.longitude,
      );
      final northEast = LatLng(
        hqLat > pos.latitude ? hqLat : pos.latitude,
        hqLng > pos.longitude ? hqLng : pos.longitude,
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southWest, northeast: northEast),
          60.0,
        ),
      );
    }
  }

  void _checkUserAndLoad() {
    _requestId++;
    final authState = ref.read(authServiceProvider);
    final user = authState.user;

    if (user == null || !authState.isAuthenticated) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated user found.';
      });
      return;
    }

    if (_currentUserId != user.id) {
      _currentUserId = user.id;
      _resetState();
    }

    final userRole = user.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;

    if (!isAuthorized) {
      if (!mounted) return;
      _resetState();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _loadProfile();
  }

  void _resetState() {
    _nameController.text = 'Envision Beyond India Pvt Ltd';
    _websiteController.text = 'https://www.envisionbeyond.com';
    _emailController.text = 'admin@envisionbeyond.com';
    _phoneController.text = '+91-22-12345678';
    _addressController.text = 'Prarthana Raw House, 33, Anand Mahal Rd, Giriraj Society, Narotam Nagar, Surat, Gujarat 395009, India';
    _cityController.text = 'Surat';
    _stateController.text = 'Gujarat';
    _countryController.text = 'India';
    _zipController.text = '395009';
    _regController.text = 'U74999MH2020PTC345678';
    _taxController.text = 'GSTIN-27AAACH7409R1ZD';
    _currencyController.text = 'INR (₹)';
    _fiscalYearController.text = 'April';
    _workingDaysController.text = 'Mon - Sat';
    _latController.text = '21.1986872';
    _lngController.text = '72.7965515';
    _radiusController.text = '100';
  }

  Future<void> _loadProfile() async {
    final currentReq = ++_requestId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiClient = ref.read(apiClientProvider);
    final storageService = ref.read(storageServiceProvider);
    final token = await storageService.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setAuthToken(token);
    }

    try {
      dynamic res;
      try {
        res = await apiClient.get(ApiEndpoints.companyProfile).timeout(const Duration(seconds: 4));
      } catch (_) {
        res = null;
      }

      if (!mounted || currentReq != _requestId) return;

      dynamic rawData = res is Map<String, dynamic> && res.containsKey('data') ? res['data'] : res;
      if (rawData == null || rawData is! Map || (rawData as Map).isEmpty) {
        rawData = {
          'companyName': 'Etaprise Technologies',
          'website': 'https://etaprise.ai',
          'email': 'admin@etaprise.ai',
          'phone': '+91 9876543210',
          'address': 'Tech Park, Phase 2',
          'city': 'Bangalore',
          'state': 'Karnataka',
          'country': 'India',
          'zipCode': '560100',
          'registrationNumber': 'U72900KA2023PTC123456',
          'taxId': '29ABCDE1234F1Z5',
          'currency': 'INR (₹)',
          'fiscalYearStart': 'April',
          'workingDays': 'Monday - Friday',
          'latitude': 12.9716,
          'longitude': 77.5946,
          'geofenceRadiusMeters': 100,
        };
      }

      if (rawData is Map<String, dynamic>) {
        if (rawData['companyName'] != null) _nameController.text = rawData['companyName'].toString();
        if (rawData['website'] != null) _websiteController.text = rawData['website'].toString();
        if (rawData['email'] != null) _emailController.text = rawData['email'].toString();
        if (rawData['phone'] != null) _phoneController.text = rawData['phone'].toString();
        if (rawData['address'] != null) _addressController.text = rawData['address'].toString();
        if (rawData['city'] != null) _cityController.text = rawData['city'].toString();
        if (rawData['state'] != null) _stateController.text = rawData['state'].toString();
        if (rawData['country'] != null) _countryController.text = rawData['country'].toString();
        if (rawData['zipCode'] != null) _zipController.text = rawData['zipCode'].toString();
        if (rawData['registrationNumber'] != null) _regController.text = rawData['registrationNumber'].toString();
        if (rawData['taxId'] != null) _taxController.text = rawData['taxId'].toString();
        if (rawData['currency'] != null) _currencyController.text = rawData['currency'].toString();
        if (rawData['fiscalYearStart'] != null) _fiscalYearController.text = rawData['fiscalYearStart'].toString();
        if (rawData['workingDays'] != null) _workingDaysController.text = rawData['workingDays'].toString();
        if (rawData['latitude'] != null) _latController.text = rawData['latitude'].toString();
        if (rawData['longitude'] != null) _lngController.text = rawData['longitude'].toString();
        if (rawData['geofenceRadiusMeters'] != null) _radiusController.text = rawData['geofenceRadiusMeters'].toString();
      }

      if (!mounted || currentReq != _requestId) return;
      setState(() => _isLoading = false);

      final loadedLat = double.tryParse(_latController.text.trim());
      final loadedLng = double.tryParse(_lngController.text.trim());
      if (loadedLat != null && loadedLng != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(loadedLat, loadedLng)));
      }
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name is required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final currentReq = ++_requestId;
    final apiClient = ref.read(apiClientProvider);

    final latVal = double.tryParse(_latController.text.trim()) ?? 21.1986872;
    final lngVal = double.tryParse(_lngController.text.trim()) ?? 72.7965515;

    final payload = {
      'companyName': _nameController.text.trim(),
      'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      'country': _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      'zipCode': _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
      'registrationNumber': _regController.text.trim().isEmpty ? null : _regController.text.trim(),
      'taxId': _taxController.text.trim().isEmpty ? null : _taxController.text.trim(),
      'currency': _currencyController.text.trim().isEmpty ? 'INR (₹)' : _currencyController.text.trim(),
      'fiscalYearStart': _fiscalYearController.text.trim().isEmpty ? 'April' : _fiscalYearController.text.trim(),
      'workingDays': _workingDaysController.text.trim().isEmpty ? 'Mon - Sat' : _workingDaysController.text.trim(),
      'latitude': latVal,
      'longitude': lngVal,
      'geofenceRadiusMeters': int.tryParse(_radiusController.text.trim()) ?? 100,
    };

    try {
      await apiClient.put(ApiEndpoints.companyProfile, body: payload);
      if (!mounted || currentReq != _requestId) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company profile & geofence updated successfully!')),
      );
    } catch (e) {
      if (!mounted || currentReq != _requestId) return;
      setState(() => _isSaving = false);
      final msg = e is ApiException ? e.message : 'Failed to save company profile.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141D2E) : Colors.white;

    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.user?.id != _currentUserId) {
        _checkUserAndLoad();
      }
    });

    final authState = ref.watch(authServiceProvider);
    final userRole = authState.user?.role;
    final bool isAuthorized = userRole == UserRole.ADMIN || userRole == UserRole.HR;
    final bool canEdit = userRole == UserRole.ADMIN;

    final mainContent = !isAuthorized
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AppCard(
                backgroundColor: cardBgColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text('Access Restricted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
                    const SizedBox(height: 8),
                    Text('You do not have permissions to view company profile settings.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadProfile,
            child: _buildMainContent(glass, cardBgColor, isDark, canEdit),
          );

    if (!_showAppBar) return Material(color: Colors.transparent, child: mainContent);

    return GlassScaffold(
      appBar: GlassHeader(
        title: 'Company Settings',
        actions: [
          if (canEdit)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Changes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.visibility_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text('Read-Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                ],
              ),
            ),
        ],
      ),
      body: mainContent,
    );
  }

  Widget _buildMainContent(GlassTheme glass, Color cardBgColor, bool dark, bool canEdit) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Unable to Load Company Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: glass.textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: glass.textSecondary)),
              const SizedBox(height: 24),
              AppButton(label: 'Retry', icon: Icons.refresh_rounded, width: 140, onPressed: _loadProfile),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HR Read-Only Banner
          if (!canEdit)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSecondarySurface : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Read-Only Mode: You are viewing company settings as HR. Only System Admins can modify settings.',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ),

          // 4 Top KPI Stat Cards matching Website
          Row(
            children: [
              Expanded(child: _buildMetricTile('COMPANY ENTITY', _nameController.text, Icons.apartment_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('TAX REGISTRATION', _taxController.text, Icons.verified_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMetricTile('GEOFENCE RADIUS', '${_radiusController.text} Meters', Icons.location_on_rounded, const Color(0xFF2563EB), const Color(0xFFE0EDFF))),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricTile('FISCAL YEAR', '${_fiscalYearController.text} Cycle', Icons.calendar_month_rounded, const Color(0xFF9333EA), const Color(0xFFF3E8FF))),
            ],
          ),
          const SizedBox(height: 20),

          // Geofence & Map Location Card
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.location_on_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Office Location & Dynamic Geofence Radius',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  canEdit
                      ? 'Click anywhere on the map or drag the HQ marker to pinpoint corporate location. Select Google Maps or Satellite view mode above. Live GPS dot shows your current device position.'
                      : 'Viewing corporate HQ location and geofence radius on map.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const Divider(height: 20),

                // Map Toolbar: Mode Switcher & GPS Action Buttons
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Map Type Selector (Google Maps / Satellite)
                    Container(
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _mapType = MapType.normal),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _mapType == MapType.normal ? const Color(0xFFFEF3C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_rounded,
                                    size: 14,
                                    color: _mapType == MapType.normal ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Google Maps',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _mapType == MapType.normal ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _mapType = MapType.satellite),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _mapType == MapType.satellite ? const Color(0xFFFEF3C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.satellite_alt_rounded,
                                    size: 14,
                                    color: _mapType == MapType.satellite ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Satellite',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _mapType == MapType.satellite ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Actions (Show Live Location & Pin Current GPS as HQ)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isFetchingGps ? null : _showLiveLocation,
                          icon: _isFetchingGps
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFFD97706)),
                          label: const Text('Show Live Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        if (canEdit)
                          ElevatedButton.icon(
                            onPressed: _isFetchingGps ? null : _pinCurrentGpsAsHq,
                            icon: const Icon(Icons.push_pin_rounded, size: 14),
                            label: const Text('Pin Current GPS as HQ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Interactive Google Map View
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          double.tryParse(_latController.text.trim()) ?? 21.1986872,
                          double.tryParse(_lngController.text.trim()) ?? 72.7965515,
                        ),
                        zoom: 15.0,
                      ),
                      mapType: _mapType,
                      zoomControlsEnabled: true,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: true,
                      onTap: canEdit ? (LatLng latLng) => _updateLocationFromMap(latLng) : null,
                      circles: {
                        Circle(
                          circleId: const CircleId('geofence_circle'),
                          center: LatLng(
                            double.tryParse(_latController.text.trim()) ?? 21.1986872,
                            double.tryParse(_lngController.text.trim()) ?? 72.7965515,
                          ),
                          radius: (double.tryParse(_radiusController.text.trim()) ?? 100.0),
                          fillColor: const Color(0x33D97706),
                          strokeColor: const Color(0xFFD97706),
                          strokeWidth: 2,
                        ),
                      },
                      markers: {
                        Marker(
                          markerId: const MarkerId('hq_marker'),
                          position: LatLng(
                            double.tryParse(_latController.text.trim()) ?? 21.1986872,
                            double.tryParse(_lngController.text.trim()) ?? 72.7965515,
                          ),
                          draggable: canEdit,
                          onDragEnd: canEdit ? (LatLng latLng) => _updateLocationFromMap(latLng) : null,
                          infoWindow: InfoWindow(
                            title: _nameController.text.isNotEmpty ? _nameController.text : 'Corporate HQ',
                            snippet: 'Geofence Active (${_radiusController.text}m radius)',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                        ),
                        if (_liveLocationMarker != null) _liveLocationMarker!,
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Dynamic Geofence Radius', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _radiusController,
                        enabled: !_isSaving && canEdit,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          suffixText: 'meters',
                          filled: true,
                          fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Radius Selector Buttons
                Wrap(
                  spacing: 6,
                  children: ['50m', '100m', '200m', '300m', '500m', '1000m'].map((rStr) {
                    final numVal = rStr.replaceAll('m', '');
                    final isSel = _radiusController.text == numVal;
                    return InkWell(
                      onTap: (_isSaving || !canEdit) ? null : () => setState(() => _radiusController.text = numVal),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? const Color(0xFFD97706) : const Color(0xFFCBD5E1)),
                        ),
                        child: Text(rStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFFD97706) : const Color(0xFF64748B))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latitude', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _latController,
                            enabled: !_isSaving && canEdit,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => _onCoordinatesChanged(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Longitude', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _lngController,
                            enabled: !_isSaving && canEdit,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => _onCoordinatesChanged(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 1: General Information Card
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.business_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text('General Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const Divider(height: 16),

                const Text('Company Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving && canEdit,
                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Website', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _websiteController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Phone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSaving && canEdit,
                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 14),

                const Text('Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  enabled: !_isSaving && canEdit,
                  maxLines: 2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: _isFetchingAddress
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                ),
                if (_lastSyncedGpsText != null || (_latController.text.isNotEmpty && _lngController.text.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0x2216A34A) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(
                          'Auto-synced GPS: ${_lastSyncedGpsText ?? "${_latController.text} , ${_lngController.text}"}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('City', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _cityController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('State', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _stateController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Country', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _countryController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ZIP / Postal Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _zipController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Registration & Taxation Card
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified_user_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text('Registration & Taxation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const Divider(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Registration Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _regController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tax ID / GSTIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _taxController,
                            enabled: !_isSaving && canEdit,
                            decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Preferences Card
          AppCard(
            backgroundColor: dark ? AppColors.darkMainSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.tune_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text('Preferences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const Divider(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          canEdit
                              ? DropdownButtonFormField<String>(
                                  value: ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AUD (\$)', 'CAD (\$)', 'SGD (\$)'].contains(_currencyController.text) ? _currencyController.text : 'INR (₹)',
                                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                  items: ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AUD (\$)', 'CAD (\$)', 'SGD (\$)']
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 13, color: dark ? Colors.white : Colors.black))))
                                      .toList(),
                                  onChanged: _isSaving ? null : (val) {
                                    if (val != null) {
                                      setState(() => _currencyController.text = val);
                                    }
                                  },
                                )
                              : TextFormField(
                                  controller: _currencyController,
                                  enabled: false,
                                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fiscal Year Starts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          canEdit
                              ? DropdownButtonFormField<String>(
                                  value: ['April', 'January', 'July', 'October', 'September'].contains(_fiscalYearController.text) ? _fiscalYearController.text : 'April',
                                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                  items: ['April', 'January', 'July', 'October', 'September']
                                      .map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontSize: 13, color: dark ? Colors.white : Colors.black))))
                                      .toList(),
                                  onChanged: _isSaving ? null : (val) {
                                    if (val != null) {
                                      setState(() => _fiscalYearController.text = val);
                                    }
                                  },
                                )
                              : TextFormField(
                                  controller: _fiscalYearController,
                                  enabled: false,
                                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Working Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _workingDaysController,
                  enabled: false,
                  decoration: InputDecoration(filled: true, fillColor: dark ? AppColors.darkSecondarySurface : const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 4),
                const Text('Read-only: System admins can configure company preferences', style: TextStyle(fontSize: 10, color: Color(0xFFD97706))),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Changes Primary Amber Button (Only for ADMIN)
          if (canEdit)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
