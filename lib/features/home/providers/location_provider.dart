import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/address_model.dart';

final selectedAddressProvider = StateNotifierProvider<SelectedAddressNotifier, AddressModel?>((ref) {
  return SelectedAddressNotifier();
});

class SelectedAddressNotifier extends StateNotifier<AddressModel?> {
  SelectedAddressNotifier() : super(null) {
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final addressJson = prefs.getString('selectedAddress');
    if (addressJson != null) {
      try {
        final map = jsonDecode(addressJson);
        state = AddressModel.fromMap(map);
        return;
      } catch (_) {}
    }

    // Auto detect if not found
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        final city = p.locality ?? p.subAdministrativeArea ?? 'Unknown';
        final newAddress = AddressModel.create(
          label: AddressLabel.other,
          fullAddress: city,
          city: city,
          lat: 0.0,
          lng: 0.0,
        );
        setAddress(newAddress);
      }
    } catch (_) {}
  }

  void setAddress(AddressModel address) async {
    state = address;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('selectedAddress', jsonEncode(address.toMap()));
  }
}
