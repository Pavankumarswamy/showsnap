import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';
import '../../home/providers/location_provider.dart';
import '../../../core/widgets/main_app_bar.dart';

class AdRequestFormScreen extends ConsumerStatefulWidget {
  const AdRequestFormScreen({super.key});

  @override
  ConsumerState<AdRequestFormScreen> createState() => _AdRequestFormScreenState();
}

class _AdRequestFormScreenState extends ConsumerState<AdRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandCtrl = TextEditingController();
  
  String _phone = '';
  bool _phoneValid = false;
  bool _submitting = false;

  String _mainAdType = 'Theater Ad';
  String _subType = 'On-Screen Ad';

  final Map<String, List<String>> _subTypesMap = {
    'Theater Ad': ['On-Screen Ad', 'Lobby Standee', 'Box Office Screen', 'Washroom Poster'],
    'Influencer Ad': ['Instagram Reel', 'Instagram Story', 'YouTube Integration', 'Twitter Post'],
  };

  @override
  void dispose() {
    _brandCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_phoneValid) {
      ShowSnapToast.show(context, message: 'Enter a valid phone number', type: ToastType.error);
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      ShowSnapToast.show(context, message: 'Please log in', type: ToastType.error);
      return;
    }

    final address = ref.read(selectedAddressProvider);
    final city = address?.city ?? 'Unknown City';

    setState(() => _submitting = true);

    try {
      final request = AdRequestModel(
        requestId: '', // DB generates it
        uid: uid,
        brandName: _brandCtrl.text.trim(),
        campaignTitle: '$_mainAdType - $_subType',
        description: 'Main Category: $_mainAdType\nSpecific Type: $_subType\nContact: $_phone\nLocation: $city',
        targetTheaters: [city], // Saving city in theaters array for filtering if needed
        targetScreens: [],
        creativeUrls: [],
        startDateTs: DateTime.now().millisecondsSinceEpoch,
        endDateTs: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        budgetRange: 'Pending',
        status: AdRequestStatus.pending,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(databaseServiceProvider).submitAdRequest(request);

      if (mounted) {
        ShowSnapToast.show(context, message: 'Ad Request Submitted Successfully!');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.show(context, message: 'Submission failed: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSubTypes = _subTypesMap[_mainAdType] ?? [];
    if (!availableSubTypes.contains(_subType)) {
      _subType = availableSubTypes.first;
    }

    return Scaffold(
      backgroundColor: ShowSnapColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ad Category',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                
                // Radio Buttons for Main Ad Type
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Theater Ad', style: TextStyle(color: Colors.white, fontSize: 14)),
                        value: 'Theater Ad',
                        groupValue: _mainAdType,
                        activeColor: ShowSnapColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _mainAdType = val);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Influencer Ad', style: TextStyle(color: Colors.white, fontSize: 14)),
                        value: 'Influencer Ad',
                        groupValue: _mainAdType,
                        activeColor: ShowSnapColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _mainAdType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Specific Ad Type
                Text('Type of $_mainAdType', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: ShowSnapColors.surface,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _subType,
                      dropdownColor: ShowSnapColors.surface,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                      items: availableSubTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _subType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                const Text('Brand / Your Name', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _brandCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ShowSnapColors.surface,
                    hintText: 'Enter name',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 24),

                // Phone
                const Text('Contact Number', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                IntlPhoneField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: ShowSnapColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                  ),
                  dropdownTextStyle: const TextStyle(color: Colors.white),
                  initialCountryCode: 'IN',
                  onChanged: (phone) {
                    _phone = phone.completeNumber;
                    _phoneValid = phone.isValidNumber();
                  },
                ),
                const SizedBox(height: 40),

                // Submit Button
                TappableScale(
                  onTap: _submitting ? () {} : _submit,
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: ShowSnapTheme.primaryButtonDecoration,
                    child: Center(
                      child: _submitting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                          : const Text(
                              'Submit Request',
                              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
