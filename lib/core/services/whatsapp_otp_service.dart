import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WhatsAppOtpService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _baseUrl = 'https://shootxpress-showsnap.hf.space';

  Future<bool> sendOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': cleanPhone}),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return true;
      } else {
        throw Exception(data['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  Future<UserCredential> verifyOtpAndSignIn(String phoneNumber, String otpCode) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': cleanPhone, 'otp': otpCode}),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['customToken'] != null) {
        final userCredential = await _auth.signInWithCustomToken(data['customToken']);
        return userCredential;
      } else {
        throw Exception(data['error'] ?? 'Failed to verify OTP');
      }
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }
}

final whatsappOtpServiceProvider = Provider<WhatsAppOtpService>((ref) => WhatsAppOtpService());
