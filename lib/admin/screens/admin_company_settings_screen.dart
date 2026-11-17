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
  bool _isSavePressed = false;
  bool _isLiveLocationPressed = false;
  bool _isPinHqPressed = false;
  bool _isLocationConfigured = false;

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
      _isLocationConfigured = true;
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
      setState(() {
        _isLocationConfigured = true;
      });
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
      setState(() => _isLocationConfigured = true);
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
    _isLocationConfigured = true;
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
      bool isLocationSet = false;

      if (rawData is Map<String, dynamic>) {
        final lat = rawData['latitude'] ?? rawData['lat'];
        final lng = rawData['longitude'] ?? rawData['lng'] ?? rawData['lon'];
        if (lat != null && lng != null) {
          final latD = double.tryParse(lat.toString());
          final lngD = double.tryParse(lng.toString());
          if (latD != null && lngD != null && (latD != 0.0 || lngD != 0.0)) {
            isLocationSet = true;
          }
        }
      }

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
        isLocationSet = true;
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
      setState(() {
        _isLoading = false;
        _isLocationConfigured = isLocationSet || (_latController.text.trim().isNotEmpty && _lngController.text.trim().isNotEmpty);
      });

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

      setState(() {
        _isSaving = false;
        _isLocationConfigured = true;
      });
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

  Widget _buildFieldWrapper({
    required String label,
    required bool isRequired,
    required Widget child,
    String? helperText,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkSecondaryText : const Color(0xFF334155),
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkMutedText : const Color(0xFF475569),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    required bool isDark,
    required Color borderColor,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? AppColors.darkMainSurface : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F6B63), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? AppColors.darkMainSurface : Colors.white;

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
          if (!canEdit)
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F6B63)));
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

    final borderColor = dark ? AppColors.darkBordersAndDividers : const Color(0xFFE5E7EB);
    final fieldBorderColor = dark ? AppColors.darkBordersAndDividers : const Color(0xFFCBD5E1);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // HR Read-Only Banner
              if (!canEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSecondarySurface : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1),
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

              // Default Company Location Status Banner (Checks if default company location is set or not)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSecondarySurface : (_isLocationConfigured ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isLocationConfigured ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isLocationConfigured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: _isLocationConfigured ? const Color(0xFF10B981) : const Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLocationConfigured
                            ? 'Default Company HQ Location is configured & active.'
                            : 'Default Company HQ Location is NOT set. Please select on map or pin GPS.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _isLocationConfigured ? const Color(0xFF047857) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 1. SUMMARY TILES (2x2 grid, neutral white cards, 1px #E5E7EB border, radius 16px, padding 12px, 8px gap)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: [
                  _buildSummaryTile('COMPANY ENTITY', _nameController.text, Icons.apartment_rounded, dark, cardBgColor, borderColor),
                  _buildSummaryTile('TAX REGISTRATION', _taxController.text, Icons.verified_rounded, dark, cardBgColor, borderColor, isMonospace: true),
                  _buildSummaryTile('GEOFENCE RADIUS', '${_radiusController.text} Meters', Icons.location_on_rounded, dark, cardBgColor, borderColor),
                  _buildSummaryTile('FISCAL YEAR', '${_fiscalYearController.text} Cycle', Icons.calendar_month_rounded, dark, cardBgColor, borderColor),
                ],
              ),
              const SizedBox(height: 16),

              // 2. LOCATION CARD (Office Location & Dynamic Geofence Radius)
              _buildSectionCard(
                title: 'Office Location & Dynamic Geofence Radius',
                helper: canEdit
                    ? 'Click anywhere on the map or drag the HQ marker to pinpoint corporate location. Select Google Maps or Satellite view mode above. Live GPS dot shows your current device position.'
                    : 'Viewing corporate HQ location and geofence radius on map.',
                icon: Icons.location_on_rounded,
                dark: dark,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                children: [
                  // Map Type Segmented Control
                  Row(
                    children: [
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSecondarySurface : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _mapType = MapType.normal),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _mapType == MapType.normal ? cardBgColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _mapType == MapType.normal
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))]
                                      : [],
                                ),
                                child: Text(
                                  'Google Maps',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _mapType == MapType.normal ? const Color(0xFF0F6B63) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _mapType = MapType.satellite),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _mapType == MapType.satellite ? cardBgColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _mapType == MapType.satellite
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))]
                                      : [],
                                ),
                                child: Text(
                                  'Satellite',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _mapType == MapType.satellite ? const Color(0xFF0F6B63) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Map Action Buttons (Show Live Location & Pin Current GPS as HQ)
                  Row(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: GestureDetector(
                            onTapDown: (_) => setState(() => _isLiveLocationPressed = true),
                            onTapUp: (_) {
                              setState(() => _isLiveLocationPressed = false);
                              if (!_isFetchingGps) _showLiveLocation();
                            },
                            onTapCancel: () => setState(() => _isLiveLocationPressed = false),
                            child: AnimatedScale(
                              scale: _isLiveLocationPressed ? 0.98 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0F6B63), width: 1),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _isFetchingGps
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F6B63)))
                                        : const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF0F6B63)),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Show Live Location',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F6B63)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (canEdit) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: GestureDetector(
                              onTapDown: (_) => setState(() => _isPinHqPressed = true),
                              onTapUp: (_) {
                                setState(() => _isPinHqPressed = false);
                                if (!_isFetchingGps) _pinCurrentGpsAsHq();
                              },
                              onTapCancel: () => setState(() => _isPinHqPressed = false),
                              child: AnimatedScale(
                                scale: _isPinHqPressed ? 0.98 : 1.0,
                                duration: const Duration(milliseconds: 100),
                                child: Container(
                                  height: 36,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F6B63),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.push_pin_rounded, size: 16, color: Colors.white),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Pin Current GPS',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Map Container (radius 16px, 1px #E5E7EB border, height ~220px)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1),
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
                            fillColor: const Color(0x260F6B63),
                            strokeColor: const Color(0xFF0F6B63),
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
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                          ),
                          if (_liveLocationMarker != null) _liveLocationMarker!,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Geofence Radius Field
                  _buildFieldWrapper(
                    label: 'Dynamic Geofence Radius',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _radiusController,
                        enabled: !_isSaving && canEdit,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        decoration: InputDecoration(
                          suffixText: 'meters',
                          suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          filled: true,
                          fillColor: dark ? AppColors.darkMainSurface : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F6B63), width: 1.5)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Presets: single horizontally scrollable row, chips 32px high, equal min-width 56px, 12px text, radius 999px, 1px border, white background, selected = teal tint background (#E6F4F1), 1px teal border, teal text 600
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: ['50m', '100m', '200m', '300m', '500m', '1000m'].map((rStr) {
                        final numVal = rStr.replaceAll('m', '');
                        final isSel = _radiusController.text == numVal;
                        return Container(
                          constraints: const BoxConstraints(minWidth: 56),
                          margin: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: (_isSaving || !canEdit) ? null : () => setState(() => _radiusController.text = numVal),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 32,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFFE6F4F1) : (dark ? AppColors.darkMainSurface : Colors.white),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF0F6B63) : fieldBorderColor,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                rStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                                  color: isSel ? const Color(0xFF0F6B63) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Latitude and Longitude Side by Side (tabular-nums, monospace, 14px)
                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'Latitude',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: _latController,
                              enabled: !_isSaving && canEdit,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              onChanged: (_) => _onCoordinatesChanged(),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: dark ? AppColors.darkMainSurface : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F6B63), width: 1.5)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'Longitude',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: _lngController,
                              enabled: !_isSaving && canEdit,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              onChanged: (_) => _onCoordinatesChanged(),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: dark ? AppColors.darkMainSurface : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F6B63), width: 1.5)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. GENERAL INFORMATION CARD
              _buildSectionCard(
                title: 'General Information',
                helper: 'Core corporate identity and contact details.',
                icon: Icons.business_rounded,
                dark: dark,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                children: [
                  _buildFieldWrapper(
                    label: 'Company Name',
                    isRequired: true,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _nameController,
                        enabled: !_isSaving && canEdit,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        decoration: _fieldDecoration(icon: Icons.apartment_rounded, isDark: dark, borderColor: fieldBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stack Website full width
                  _buildFieldWrapper(
                    label: 'Website',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _websiteController,
                        enabled: !_isSaving && canEdit,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        decoration: _fieldDecoration(icon: Icons.language_rounded, isDark: dark, borderColor: fieldBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stack Email full width
                  _buildFieldWrapper(
                    label: 'Email',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _emailController,
                        enabled: !_isSaving && canEdit,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        decoration: _fieldDecoration(icon: Icons.email_rounded, isDark: dark, borderColor: fieldBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone (tabular figures, monospace)
                  _buildFieldWrapper(
                    label: 'Phone',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _phoneController,
                        enabled: !_isSaving && canEdit,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]),
                        decoration: _fieldDecoration(icon: Icons.phone_rounded, isDark: dark, borderColor: fieldBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Address (min-height 80px)
                  _buildFieldWrapper(
                    label: 'Address',
                    isRequired: false,
                    isDark: dark,
                    child: TextFormField(
                      controller: _addressController,
                      enabled: !_isSaving && canEdit,
                      minLines: 2,
                      maxLines: 4,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, height: 1.5),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                        filled: true,
                        fillColor: dark ? AppColors.darkMainSurface : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fieldBorderColor, width: 1)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F6B63), width: 1.5)),
                        suffixIcon: _isFetchingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F6B63))),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Auto-synced GPS chip (height 28px, radius 999px, 12px text, soft green tint #ECFDF5 with darker green #047857 text, 14px check icon, 8px below Address field)
                  if (_lastSyncedGpsText != null || (_latController.text.isNotEmpty && _lngController.text.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF047857)),
                          const SizedBox(width: 6),
                          Text(
                            'Auto-synced GPS: ${_lastSyncedGpsText ?? "${_latController.text} , ${_lngController.text}"}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // City / State (two columns)
                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'City',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: _cityController,
                              enabled: !_isSaving && canEdit,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                              decoration: _fieldDecoration(icon: Icons.location_city_rounded, isDark: dark, borderColor: fieldBorderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'State',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: _stateController,
                              enabled: !_isSaving && canEdit,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                              decoration: _fieldDecoration(icon: Icons.map_rounded, isDark: dark, borderColor: fieldBorderColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Country / ZIP Code (two columns)
                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'Country',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: _countryController,
                              enabled: !_isSaving && canEdit,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                              decoration: _fieldDecoration(icon: Icons.public_rounded, isDark: dark, borderColor: fieldBorderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'ZIP / Postal Code',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: TextFormField(
                              controller: _zipController,
                              enabled: !_isSaving && canEdit,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]),
                              decoration: _fieldDecoration(icon: Icons.pin_drop_rounded, isDark: dark, borderColor: fieldBorderColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. REGISTRATION & TAXATION CARD (Stack Registration Number and Tax ID / GSTIN full width)
              _buildSectionCard(
                title: 'Registration & Taxation',
                helper: 'Corporate statutory identification and tax details.',
                icon: Icons.verified_user_rounded,
                dark: dark,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                children: [
                  _buildFieldWrapper(
                    label: 'Registration Number',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _regController,
                        enabled: !_isSaving && canEdit,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]),
                        decoration: _fieldDecoration(icon: Icons.confirmation_number_rounded, isDark: dark, borderColor: fieldBorderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildFieldWrapper(
                    label: 'Tax ID / GSTIN',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _taxController,
                        enabled: !_isSaving && canEdit,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]),
                        decoration: _fieldDecoration(icon: Icons.receipt_long_rounded, isDark: dark, borderColor: fieldBorderColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. PREFERENCES CARD
              _buildSectionCard(
                title: 'Preferences',
                helper: 'Default operational currency, fiscal calendar, and working schedules.',
                icon: Icons.tune_rounded,
                dark: dark,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                children: [
                  // Currency / Fiscal Year (two columns)
                  Row(
                    children: [
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'Currency',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: canEdit
                                ? DropdownButtonFormField<String>(
                                    value: ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AUD (\$)', 'CAD (\$)', 'SGD (\$)'].contains(_currencyController.text) ? _currencyController.text : 'INR (₹)',
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF0F6B63)),
                                    decoration: _fieldDecoration(icon: Icons.payments_rounded, isDark: dark, borderColor: fieldBorderColor),
                                    dropdownColor: cardBgColor,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                    items: ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AUD (\$)', 'CAD (\$)', 'SGD (\$)']
                                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
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
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                    decoration: _fieldDecoration(icon: Icons.payments_rounded, isDark: dark, borderColor: fieldBorderColor),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFieldWrapper(
                          label: 'Fiscal Year Starts',
                          isRequired: false,
                          isDark: dark,
                          child: SizedBox(
                            height: 48,
                            child: canEdit
                                ? DropdownButtonFormField<String>(
                                    value: ['April', 'January', 'July', 'October', 'September'].contains(_fiscalYearController.text) ? _fiscalYearController.text : 'April',
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF0F6B63)),
                                    decoration: _fieldDecoration(icon: Icons.calendar_month_rounded, isDark: dark, borderColor: fieldBorderColor),
                                    dropdownColor: cardBgColor,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                    items: ['April', 'January', 'July', 'October', 'September']
                                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
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
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                                    decoration: _fieldDecoration(icon: Icons.calendar_month_rounded, isDark: dark, borderColor: fieldBorderColor),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Working Days (Read-only field: background #F8FAFC, 1px #E5E7EB border, text #475569, with 16px lock icon on right)
                  _buildFieldWrapper(
                    label: 'Working Days',
                    isRequired: false,
                    isDark: dark,
                    child: SizedBox(
                      height: 48,
                      child: TextFormField(
                        controller: _workingDaysController,
                        enabled: false,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                        ),
                      ),
                    ),
                    helperText: 'Read-only: System admins can configure company preferences',
                  ),
                ],
              ),
              if (canEdit) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTapDown: (_) => setState(() => _isSavePressed = true),
              onTapUp: (_) {
                setState(() => _isSavePressed = false);
                if (!_isSaving) _save();
              },
              onTapCancel: () => setState(() => _isSavePressed = false),
              child: AnimatedScale(
                scale: _isSavePressed ? 0.98 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F6B63),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(15, 107, 99, 0.22),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon, bool dark, Color cardBgColor, Color borderColor, {bool isMonospace = false}) {
    final isZero = value == '0' || value.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black12 : const Color(0x0A0F172A),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F6B63).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFF0F6B63), size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isZero ? const Color(0xFF64748B) : (dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A)),
              fontFamily: isMonospace ? 'monospace' : null,
              fontFeatures: isMonospace ? const [FontFeature.tabularFigures()] : null,
              letterSpacing: isMonospace ? 0.2 : 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String helper,
    required IconData icon,
    required bool dark,
    required Color cardBgColor,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black12 : const Color(0x0A0F172A),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F6B63).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF0F6B63), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark ? AppColors.darkPrimaryText : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: borderColor,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
