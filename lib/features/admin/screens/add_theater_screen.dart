import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win_web;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/showsnap_toast.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AddTheaterScreen extends ConsumerStatefulWidget {
  final String? fixedManagerId;
  final String? fixedManagerName;
  final String? theaterId;

  const AddTheaterScreen({
    super.key,
    this.fixedManagerId,
    this.fixedManagerName,
    this.theaterId,
  });

  @override
  ConsumerState<AddTheaterScreen> createState() => _AddTheaterScreenState();
}

class _AddTheaterScreenState extends ConsumerState<AddTheaterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _existingLogoUrl;
  
  LatLng _selectedLocation = const LatLng(20.5937, 78.9629); // Default center (India)
  WebViewController? _webViewController;
  final win_web.WebviewController _windowsWebViewController = win_web.WebviewController();
  bool _isWebViewInitialized = false;
  bool _webViewInitFailed = false;

  String _generateMapboxHTML(LatLng center) {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    return '''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
        <script src="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js"></script>
        <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet" />
        <script src="https://cdn.jsdelivr.net/npm/@turf/turf@6/turf.min.js"></script>
        <style>
          body { margin: 0; padding: 0; }
          #map { position: absolute; top: 0; bottom: 0; width: 100%; }
          .mapboxgl-ctrl-bottom-left, .mapboxgl-ctrl-bottom-right { display: none !important; }
        </style>
      </head>
      <body>
        <div id="map"></div>
        <script>
          mapboxgl.accessToken = '$token';
          var map = new mapboxgl.Map({
            container: 'map',
            style: 'mapbox://styles/mapbox/streets-v12',
            center: [${center.longitude}, ${center.latitude}],
            zoom: 14
          });

          var marker = new mapboxgl.Marker({ color: '#E50914' })
            .setLngLat([${center.longitude}, ${center.latitude}])
            .addTo(map);

          map.on('click', function(e) {
            marker.setLngLat([e.lngLat.lng, e.lngLat.lat]);
            var msg = JSON.stringify({
                type: 'MAP_CLICK',
                lat: e.lngLat.lat,
                lng: e.lngLat.lng
              });
            if (window.MapChannel) {
              window.MapChannel.postMessage(msg);
            }
            if (window.chrome && window.chrome.webview) {
              window.chrome.webview.postMessage(msg);
            }
          });

          window.updateMarker = function(lng, lat) {
             marker.setLngLat([lng, lat]);
             map.flyTo({ center: [lng, lat], zoom: 14 });
          };
        </script>
      </body>
    </html>
    ''';
  }

  Future<void> _initWebView() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        await _windowsWebViewController.initialize();
        _windowsWebViewController.webMessage.listen((message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'MAP_CLICK') {
              final lat = data['lat'] as double;
              final lng = data['lng'] as double;
              _reverseGeocode(LatLng(lat, lng));
            }
          } catch (e) {
            debugPrint('Web message error: $e');
          }
        });
        await _windowsWebViewController.loadStringContent(_generateMapboxHTML(_selectedLocation));
      } catch (e) {
        debugPrint('Windows WebView initialization failed: $e');
        if (mounted) setState(() => _webViewInitFailed = true);
      } finally {
        if (mounted) {
          setState(() {
            _isWebViewInitialized = true;
          });
        }
      }
      return;
    }

    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
      setState(() {
        _isWebViewInitialized = true; // Mark as initialized to stop loading
      });
      return; // Skip WebView setup for unsupported desktop platforms
    }

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'MapChannel',
          onMessageReceived: (message) {
            final data = jsonDecode(message.message);
            if (data['type'] == 'MAP_CLICK') {
              final lat = data['lat'] as double;
              final lng = data['lng'] as double;
              _reverseGeocode(LatLng(lat, lng));
            }
          },
        );
      _loadMapHtml(_selectedLocation);
      if (mounted) {
        setState(() {
          _isWebViewInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('WebViewController initialization failed: $e');
      if (mounted) {
        setState(() {
          _webViewInitFailed = true;
          _isWebViewInitialized = true;
        });
      }
    }
  }

  void _loadMapHtml(LatLng location) {
    if (!kIsWeb && Platform.isWindows) {
      if (!_webViewInitFailed) {
        _windowsWebViewController.loadStringContent(_generateMapboxHTML(location));
      }
      return;
    }
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) return;
    _webViewController?.loadHtmlString(_generateMapboxHTML(location));
  }

  void _updateMarkerInWebView(LatLng location) {
    final script = 'if(window.updateMarker) window.updateMarker(${location.longitude}, ${location.latitude});';
    if (!kIsWeb && Platform.isWindows) {
      if (!_webViewInitFailed) {
        _windowsWebViewController.executeScript(script);
      }
    } else if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
      return;
    } else {
      _webViewController?.runJavaScript(script);
    }
  }

  String _fetchedCity = '';
  String _fetchedStreet = '';
  String _fetchedAddress = '';
  bool _isLoadingAddress = false;

  UserModel? _selectedManager;
  bool _saving = false;
  bool _isLoadingData = false;
  
  TheaterModel? _existingTheater;

  @override
  void initState() {
    super.initState();
    _initWebView();
    if (widget.theaterId != null) {
      _loadExistingTheater();
    } else {
      // Automatically fetch current location for new theaters
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCurrentLocation();
      });
    }
  }

  Future<void> _loadExistingTheater() async {
    setState(() => _isLoadingData = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final theater = await db.getTheater(widget.theaterId!);
      if (theater != null) {
        _existingTheater = theater;
        _nameCtrl.text = theater.name;
        _phoneCtrl.text = theater.contactPhone;
        _selectedLocation = LatLng(theater.lat, theater.lng);
        _fetchedCity = theater.city;
        _fetchedAddress = theater.address;
        _existingLogoUrl = theater.logoUrl;
        
        if (widget.fixedManagerId == null && theater.managerId.isNotEmpty) {
          final users = await db.getAllUsers();
          _selectedManager = users.firstWhere((u) => u.uid == theater.managerId);
        }
        _updateMarkerInWebView(_selectedLocation);
      }
    } catch (e) {
      debugPrint('Error loading theater: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoadingAddress = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ShowSnapToast.error(context, 'Location permission denied');
          setState(() => _isLoadingAddress = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ShowSnapToast.error(context, 'Location permissions are permanently denied, we cannot request permissions.');
        setState(() => _isLoadingAddress = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newLocation = LatLng(position.latitude, position.longitude);
      
      _updateMarkerInWebView(newLocation);
      await _reverseGeocode(newLocation);
    } catch (e) {
      if (mounted) ShowSnapToast.error(context, 'Error getting location: $e');
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _isLoadingAddress = true;
    });

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      setState(() {
        _fetchedCity = 'Unknown City';
        _fetchedStreet = '';
        _fetchedAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        _isLoadingAddress = false;
      });
      return;
    }

    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json?access_token=$token');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final feature = data['features'][0];
          
          String city = 'Unknown City';
          String street = feature['text'] ?? '';
          
          if (feature['context'] != null) {
            for (var c in feature['context']) {
              if (c['id'].toString().startsWith('place') || c['id'].toString().startsWith('locality')) {
                city = c['text'];
                break;
              }
            }
          }
          final fullAddress = feature['place_name'] ?? 'Unknown Address';

          setState(() {
            _fetchedCity = city;
            _fetchedStreet = street;
            _fetchedAddress = fullAddress;
          });
        } else {
          if (mounted) ShowSnapToast.error(context, 'No address found for this location.');
        }
      } else {
        if (mounted) ShowSnapToast.error(context, 'Geocoding failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      if (mounted) ShowSnapToast.error(context, 'Geocoding error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final managerId = widget.fixedManagerId ?? _selectedManager?.uid ?? '';

    if (_fetchedAddress.isEmpty || _fetchedCity.isEmpty) {
      ShowSnapToast.error(context, 'Please drop a pin on the map to fetch the address');
      return;
    }

    setState(() => _saving = true);
    try {
      String logoUrl = _existingLogoUrl ?? '';
      if (_imageBytes != null && _imageFile != null) {
        logoUrl = await ref.read(cloudinaryServiceProvider).uploadImageBytes(
          _imageBytes!,
          _imageFile!.name,
          'theaters'
        );
      }

      final theater = TheaterModel(
        theaterId: _existingTheater?.theaterId ?? '',
        name: _nameCtrl.text.trim(),
        city: _fetchedCity,
        address: _fetchedAddress,
        contactPhone: _phoneCtrl.text.trim(),
        lat: _selectedLocation.latitude,
        lng: _selectedLocation.longitude,
        logoUrl: logoUrl,
        managerId: managerId,
        isActive: _existingTheater?.isActive ?? true,
      );

      final db = ref.read(databaseServiceProvider);
      if (_existingTheater != null) {
        await db.updateTheater(theater.theaterId, theater.toJson());
      } else {
        await db.createTheater(theater);
      }

      if (mounted) {
        ShowSnapToast.success(context, _existingTheater != null ? 'Theater updated' : 'Theater created');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ShowSnapToast.error(context, 'Failed to save theater: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFixedManager = widget.fixedManagerId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existingTheater != null ? 'Edit Theater' : 'Add Theater'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            // ── Theater Info Card ─────────────────────────────────────────
            _SectionHeader('Theater Details')
              .animate()
              .fadeIn(duration: 300.ms, delay: 50.ms),
            const SizedBox(height: 16),
            
            // Image Picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: ShowSnapColors.grey100,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    border: Border.all(color: ShowSnapColors.grey300),
                    image: _imageBytes != null
                        ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                        : _existingLogoUrl != null && _existingLogoUrl!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(_existingLogoUrl!), fit: BoxFit.cover)
                            : null,
                  ),
                  child: _imageBytes == null && (_existingLogoUrl == null || _existingLogoUrl!.isEmpty)
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: ShowSnapColors.grey600),
                            SizedBox(height: 4),
                            Text('Add Picture', style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600)),
                          ],
                        )
                      : null,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
            const SizedBox(height: 16),

            _Field(
              controller: _nameCtrl,
              label: 'Theater Name *',
              icon: Icons.business_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            _Field(
              controller: _phoneCtrl,
              label: 'Contact Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ).animate().fadeIn(duration: 300.ms, delay: 250.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),

            // Coordinates Map Picker
            _SectionHeader('Theater Location')
              .animate()
              .fadeIn(duration: 300.ms, delay: 280.ms),
            const SizedBox(height: 10),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                border: Border.all(color: ShowSnapColors.grey300),
              ),
              clipBehavior: Clip.antiAlias,
              child: _isWebViewInitialized
                  ? (_webViewInitFailed || (!kIsWeb && (Platform.isLinux || Platform.isMacOS)))
                      ? (dotenv.env['MAPBOX_ACCESS_TOKEN']?.isNotEmpty == true)
                          ? Image.network(
                              'https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/pin-s+ea4335(${_selectedLocation.longitude},${_selectedLocation.latitude})/${_selectedLocation.longitude},${_selectedLocation.latitude},14,0/600x300?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(child: Text('Map preview unavailable')),
                            )
                          : Container(
                              color: ShowSnapColors.grey100,
                              child: const Center(
                                child: Text('MAPBOX_ACCESS_TOKEN missing in .env\nCannot load static map.', textAlign: TextAlign.center, style: TextStyle(color: ShowSnapColors.grey600)),
                              ),
                            )
                      : (!kIsWeb && Platform.isWindows)
                          ? win_web.Webview(_windowsWebViewController)
                          : WebViewWidget(controller: _webViewController!)
                  : const Center(child: CircularProgressIndicator()),
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tap map or use your current location:',
                      style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShowSnapColors.primary.withOpacity(0.2),
                      foregroundColor: ShowSnapColors.primaryLighter,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                      ),
                    ),
                    onPressed: _isLoadingAddress ? null : _fetchCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('My Location', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 320.ms),

            // Display Fetched Address
            if (_isLoadingAddress)
              const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              )).animate().fadeIn(duration: 200.ms)
            else if (_fetchedAddress.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ShowSnapColors.grey100,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  border: Border.all(color: ShowSnapColors.grey300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 Fetched Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('City: $_fetchedCity', style: const TextStyle(fontSize: 14, color: Colors.white)),
                    if (_fetchedStreet.isNotEmpty)
                      Text('Street: $_fetchedStreet', style: const TextStyle(fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Full Address: $_fetchedAddress', style: const TextStyle(fontSize: 14, color: ShowSnapColors.grey600)),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            // ── Manager Assignment ────────────────────────────────────────
            _SectionHeader('Manager Assignment')
              .animate()
              .fadeIn(duration: 300.ms, delay: 350.ms),
            const SizedBox(height: 10),

            if (isFixedManager) ...[
              // TM creating their own theater — show their own name locked
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ShowSnapColors.primaryLighter,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  border: Border.all(color: ShowSnapColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outlined,
                        color: ShowSnapColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.fixedManagerName ?? 'You',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ShowSnapColors.primary)),
                          const Text('Assigned as manager of this theater',
                              style: TextStyle(
                                  fontSize: 12, color: ShowSnapColors.primary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline,
                        size: 16, color: ShowSnapColors.primary),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
            ] else ...[
              // Admin view — pick from theater manager users
              _ManagerPicker(
                selected: _selectedManager,
                onSelected: (u) => setState(() => _selectedManager = u),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
            ],

            const SizedBox(height: 28),

            // ── Save Button ───────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _saving || _isLoadingData ? ShowSnapColors.grey300 : ShowSnapColors.primary,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    ),
                  ),
                  onPressed: _saving || _isLoadingData ? null : _save,
                  child: _saving || _isLoadingData
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _existingTheater != null ? 'Update Theater' : 'Create Theater',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 450.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Manager Picker ────────────────────────────────────────────────────────────

class _ManagerPicker extends ConsumerWidget {
  final UserModel? selected;
  final ValueChanged<UserModel?> onSelected;

  const _ManagerPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_tmUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading users: $e'),
      data: (users) {
        if (users.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ShowSnapColors.grey100,
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            ),
            child: const Text(
              'No theater managers found.\nCreate a user first and assign them the Theater Manager role.',
              style: TextStyle(color: ShowSnapColors.grey600, fontSize: 13),
            ),
          );
        }

        final isSelectedInList = selected == null || users.any((u) => u.uid == selected!.uid);
        final allUsersForDropdown = List<UserModel>.from(users);
        if (selected != null && !isSelectedInList) {
          allUsersForDropdown.insert(0, selected!);
        }

        // Deduplicate users by UID to prevent duplicate value errors
        final seenUids = <String>{};
        final uniqueUsers = allUsersForDropdown.where((u) => seenUids.add(u.uid)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Theater Manager (optional)',
                style: TextStyle(fontSize: 13, color: ShowSnapColors.grey600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selected?.uid,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.manage_accounts_outlined),
                hintText: 'Select a theater manager',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None (assign later)'),
                ),
                ...uniqueUsers.map((u) => DropdownMenuItem<String>(
                      value: u.uid,
                      child: Text(
                          '${u.displayName.isNotEmpty ? u.displayName : u.email} · ${u.role}'),
                    )),
              ],
              onChanged: (uid) {
                if (uid == null) {
                  onSelected(null);
                } else {
                  onSelected(uniqueUsers.firstWhere((u) => u.uid == uid));
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// Provider: all users who are theaterManagers OR regular users eligible to manage
final _tmUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final all = await ref.watch(databaseServiceProvider).getAllUsers();
  // Show theaterManagers + users (admin can promote them)
  return all
      .where((u) =>
          u.role == AppConstants.roleTheaterManager ||
          u.role == AppConstants.roleUser)
      .toList();
});

// ── Reusable Field ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
