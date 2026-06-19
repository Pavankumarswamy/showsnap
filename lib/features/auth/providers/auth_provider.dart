import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/whatsapp_otp_service.dart';

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final WhatsAppOtpService _otpService;

  AuthNotifier(this._authService, this._otpService) : super(const AsyncValue.data(null));

  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _otpService.sendOtp(phone));
  }

  Future<void> verifyOtp(String phone, String otp) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _otpService.verifyOtpAndSignIn(phone, otp));
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authService.signInWithGoogle());
  }

  Future<void> signInWithGoogleWeb() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authService.signInWithGoogleWeb());
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authService.signOut());
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(whatsappOtpServiceProvider),
  );
});
