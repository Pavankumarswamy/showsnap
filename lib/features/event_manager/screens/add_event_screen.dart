import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win_web;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/widgets/showsnap_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/constants/app_constants.dart';

class AddEventScreen extends ConsumerStatefulWidget {
  final String? eventId;
  const AddEventScreen({super.key, this.eventId});

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _organizerCtrl = TextEditingController();
  final _venueNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _posterCtrl = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);

  String _category = AppConstants.eventCategories.first;
  final List<TicketTier> _tiers = [];
  bool _saving = false;
  bool _loading = false;

  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _existingPosterUrl;
  String _status = 'draft';

  LatLng _selectedLocation = const LatLng(20.5937, 78.9629); // Default center
  WebViewController? _webViewController;
  final win_web.WebviewController _windowsWebViewController = win_web.WebviewController();
  bool _isWebViewInitialized = false;
  bool _webViewInitFailed = false;
  
  String _fetchedCity = '';
  String _fetchedAddress = '';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
    if (widget.eventId != null) {
      _loadEvent();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCurrentLocation();
      });
    }
  }

  Future<void> _loadEvent() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final event = await db.getEvent(widget.eventId!);
      if (event == null) throw Exception('Event not found');
      
      _nameCtrl.text = event.name;
      _organizerCtrl.text = event.organizer;
      _venueNameCtrl.text = event.venueName;
      _cityCtrl.text = event.city;
      _descCtrl.text = event.description;
      _posterCtrl.text = event.posterUrl;
      _existingPosterUrl = event.posterUrl;
      _category = event.category;
      
      if (event.lat != 0 && event.lng != 0) {
        _selectedLocation = LatLng(event.lat, event.lng);
        _fetchedCity = event.city;
        _fetchedAddress = event.venueName;
      }

      final startDt = DateTime.fromMillisecondsSinceEpoch(event.startTs);
      _startDate = startDt;
      _startTime = TimeOfDay(hour: startDt.hour, minute: startDt.minute);

      final endDt = DateTime.fromMillisecondsSinceEpoch(event.endTs);
      _endDate = endDt;
      _endTime = TimeOfDay(hour: endDt.hour, minute: endDt.minute);
      _category = AppConstants.eventCategories.contains(event.category) 
          ? event.category 
          : 'Other';
      _status = event.status;
      _tiers.addAll(event.ticketTiers);
    } catch (e) {
      context.showErrorSnackbar('Failed to load event: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _organizerCtrl.dispose();
    _venueNameCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _posterCtrl.dispose();
    super.dispose();
  }

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
        _isWebViewInitialized = true;
      });
      return;
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

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _isLoadingAddress = true;
    });

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      setState(() {
        _fetchedCity = 'Unknown City';
        _fetchedAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        _isLoadingAddress = false;
      });
      return;
    }

    try {
      final res = await http.get(Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json?access_token=$token'));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final place = data['features'][0];
          String city = '';
          if (place['context'] != null) {
            for (var c in place['context']) {
              if ((c['id'] as String).startsWith('place')) {
                city = c['text'];
                break;
              }
            }
          }
          if (city.isEmpty && place['place_type'].contains('place')) {
            city = place['text'];
          }

          setState(() {
            _fetchedAddress = place['place_name'] ?? place['text'] ?? '';
            _fetchedCity = city.isEmpty ? 'Unknown City' : city;
            _cityCtrl.text = _fetchedCity;
          });
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLoadingAddress = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      final position = await Geolocator.getCurrentPosition();
      final newLocation = LatLng(position.latitude, position.longitude);
      
      _updateMarkerInWebView(newLocation);
      await _reverseGeocode(newLocation);
    } catch (e) {
      if (mounted) ShowSnapToast.error(context, 'Error getting location: $e');
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    
    // Ensure initialDate is not before firstDate
    DateTime initial = _startDate;
    if (initial.isBefore(first)) {
      initial = first;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );
      if (time != null) {
        setState(() {
          _startDate = date;
          _startTime = time;
          
          // Ensure end date is not before the new start date
          final startFull = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          final endFull = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);
          if (endFull.isBefore(startFull)) {
            _endDate = date;
            _endTime = time;
          }
        });
      }
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
        _posterCtrl.text = 'Uploading later...'; // just so user sees something
      });
    }
  }

  Future<void> _pickEnd() async {
    final first = DateTime(_startDate.year, _startDate.month, _startDate.day);
    
    // Ensure initialDate is not before firstDate
    DateTime initial = _endDate;
    if (initial.isBefore(first)) {
      initial = first;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _endTime,
      );
      if (time != null) {
        setState(() {
          _endDate = date;
          _endTime = time;
        });
      }
    }
  }

  void _addTier() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final seatsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Ticket Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tier Name (e.g. VIP, General)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: seatsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Seats Capacity'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = int.tryParse(priceCtrl.text) ?? 0;
              final seats = int.tryParse(seatsCtrl.text) ?? 0;
              if (name.isEmpty || price <= 0 || seats <= 0) return;

              setState(() {
                _tiers.add(TicketTier(
                  name: name,
                  price: price,
                  totalSeats: seats,
                  availableSeats: seats,
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tiers.isEmpty) {
      context.showErrorSnackbar('Please add at least one ticket tier.');
      return;
    }

    final managerId = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    if (managerId.isEmpty) return;

    setState(() => _saving = true);

    try {
      final startTs = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      ).millisecondsSinceEpoch;

      final endTs = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      ).millisecondsSinceEpoch;

      if (endTs <= startTs) {
        context.showErrorSnackbar('End time must be after start time.');
        setState(() => _saving = false);
        return;
      }

      String posterUrl = _existingPosterUrl ?? _posterCtrl.text.trim();
      if (_imageBytes != null && _imageFile != null) {
        posterUrl = await ref.read(cloudinaryServiceProvider).uploadImageBytes(
          _imageBytes!,
          _imageFile!.name,
          'event_posters',
        );
      }

      final event = EventModel(
        eventId: widget.eventId ?? '',
        name: _nameCtrl.text.trim(),
        organizer: _organizerCtrl.text.trim(),
        venueId: widget.eventId ?? 'venue_rtdb', // mock venue ID
        venueName: _venueNameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        startTs: startTs,
        endTs: endTs,
        lat: _selectedLocation.latitude,
        lng: _selectedLocation.longitude,
        category: _category,
        description: _descCtrl.text.trim(),
        posterUrl: posterUrl,
        ticketTiers: _tiers,
        managerId: managerId,
        status: widget.eventId == null ? 'published' : _status,
        isActive: widget.eventId == null ? true : (_status == 'published'),
      );

      final db = ref.read(databaseServiceProvider);
      await db.saveEvent(event);

      if (mounted) {
        context.showSnackbar(widget.eventId == null
            ? 'Event created successfully!'
            : 'Event updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed to save event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final startDateTimeLabel = '${_startDate.dateLabel} at ${_startTime.format(context)}';
    final endDateTimeLabel = '${_endDate.dateLabel} at ${_endTime.format(context)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventId == null ? 'Create Event' : 'Edit Event'),
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
            _SectionHeader('Event Details')
              .animate()
              .fadeIn(duration: 300.ms, delay: 50.ms),
            const SizedBox(height: 12),
            _Field(
              controller: _nameCtrl,
              label: 'Event Name *',
              icon: Icons.event_note_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            _Field(
              controller: _organizerCtrl,
              label: 'Organizer Name *',
              icon: Icons.business_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _venueNameCtrl,
                    label: 'Venue Name *',
                    icon: Icons.place_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _cityCtrl,
                    label: 'City *',
                    icon: Icons.location_city_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),
            _SectionHeader('Venue Location')
              .animate()
              .fadeIn(duration: 300.ms, delay: 220.ms),
            const SizedBox(height: 12),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: ShowSnapColors.grey100,
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
            ).animate().fadeIn(duration: 300.ms, delay: 230.ms).slideY(begin: 0.05, end: 0),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tap map or use your current location:', 
                    style: TextStyle(color: ShowSnapColors.grey600, fontSize: 13)),
                  ElevatedButton.icon(
                    onPressed: _fetchCurrentLocation,
                    icon: const Icon(Icons.my_location, size: 16, color: ShowSnapColors.primary),
                    label: const Text('My Location', style: TextStyle(color: ShowSnapColors.primary)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShowSnapColors.primary.withOpacity(0.1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            if (_fetchedAddress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShowSnapColors.grey100,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                    border: Border.all(color: ShowSnapColors.grey300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop, color: ShowSnapColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fetched Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('City: $_fetchedCity', style: const TextStyle(fontSize: 13)),
                            Text('Full Address: $_fetchedAddress', style: TextStyle(color: ShowSnapColors.grey600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: AppConstants.eventCategories.map((c) => 
                DropdownMenuItem(value: c, child: Text(c))
              ).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Other'),
            ).animate().fadeIn(duration: 300.ms, delay: 250.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 140,
                  height: 180,
                  decoration: BoxDecoration(
                    color: ShowSnapColors.grey100,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    border: Border.all(color: ShowSnapColors.grey300),
                    image: _imageBytes != null
                        ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                        : _existingPosterUrl != null && _existingPosterUrl!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(_existingPosterUrl!), fit: BoxFit.cover)
                            : null,
                  ),
                  child: _imageBytes == null && (_existingPosterUrl == null || _existingPosterUrl!.isEmpty)
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: ShowSnapColors.grey600, size: 36),
                            SizedBox(height: 8),
                            Text('Upload Poster', style: TextStyle(fontSize: 12, color: ShowSnapColors.grey600)),
                          ],
                        )
                      : null,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),
            _Field(
              controller: _descCtrl,
              label: 'Description',
              icon: Icons.description_outlined,
              maxLines: 3,
            ).animate().fadeIn(duration: 300.ms, delay: 350.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 24),
            _SectionHeader('Date & Time')
              .animate()
              .fadeIn(duration: 300.ms, delay: 400.ms),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Starts At', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(startDateTimeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Ends At', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(endDateTimeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 450.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _SectionHeader('Ticket Tiers')),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: ShowSnapColors.primary),
                  onPressed: _addTier,
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 500.ms),
            const SizedBox(height: 8),
            if (_tiers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No ticket tiers added. Click "+" to add.',
                      style: TextStyle(color: ShowSnapColors.grey600, fontSize: 13)),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 550.ms)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tiers.length,
                itemBuilder: (ctx, i) {
                  final t = _tiers[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: ShowSnapColors.grey100,
                    child: ListTile(
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Price: ₹${t.price}  •  Capacity: ${t.totalSeats} seats'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _tiers.removeAt(i);
                          });
                        },
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: (550 + i * 50).ms);
                },
              ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: ShowSnapTheme.primaryButtonDecoration,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.save_outlined, color: Colors.black),
                  label: Text(
                    _saving ? 'Saving…' : (widget.eventId == null ? 'Create Event' : 'Save Changes'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 600.ms).slideY(begin: 0.05, end: 0),
          ],
        ),
      ),
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
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}
