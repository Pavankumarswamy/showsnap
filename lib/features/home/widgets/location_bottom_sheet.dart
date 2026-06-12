import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/address_model.dart';
import '../providers/location_provider.dart';

class LocationBottomSheet extends ConsumerStatefulWidget {
  const LocationBottomSheet({super.key});

  @override
  ConsumerState<LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends ConsumerState<LocationBottomSheet> {
  bool _isLoadingLoc = false;

  final List<String> _popularCities = [
    'Mumbai', 'Delhi-NCR', 'Bengaluru', 'Hyderabad',
    'Chandigarh', 'Chennai', 'Pune', 'Kolkata', 'Kochi',
  ];

  Future<void> _handleUseCurrentLocation() async {
    setState(() => _isLoadingLoc = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        _selectCity(p.locality ?? p.subAdministrativeArea ?? 'Unknown');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLoc = false);
    }
  }

  void _selectCity(String city) {
    final newAddress = AddressModel.create(
      label: AddressLabel.other,
      fullAddress: city,
      city: city,
      lat: 0.0,
      lng: 0.0,
    );
    ref.read(selectedAddressProvider.notifier).setAddress(newAddress);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: ShowSnapColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(76),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const Text(
            'Select your city',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),

          // Auto detect
          Container(
            decoration: BoxDecoration(
              color: ShowSnapColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withAlpha(51)),
            ),
            child: ListTile(
              leading: _isLoadingLoc 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: ShowSnapColors.primary),
              title: const Text('Auto Detect My City', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: const Text('Using GPS', style: TextStyle(fontSize: 12, color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white54),
              onTap: _isLoadingLoc ? null : _handleUseCurrentLocation,
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Popular Cities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          
          // Popular cities grid
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _popularCities.length,
              itemBuilder: (context, index) {
                final city = _popularCities[index];
                return InkWell(
                  onTap: () => _selectCity(city),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withAlpha(51)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      city,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
