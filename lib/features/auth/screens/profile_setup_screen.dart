import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/extensions.dart';

const _genres = [
  'Action',
  'Comedy',
  'Drama',
  'Thriller',
  'Horror',
  'Romance',
  'Sci-Fi',
  'Animation',
  'Documentary',
  'Fantasy',
  'Crime',
  'Adventure',
];

const _cities = [
  'Mumbai',
  'Delhi',
  'Bangalore',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Pune',
  'Ahmedabad',
  'Jaipur',
  'Lucknow',
];

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _phoneCtrl = TextEditingController();
  String? _selectedCity;
  final Set<String> _selectedGenres = {};
  bool _saving = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).updateUserProfile(
            phone: _phoneCtrl.text.trim(),
            city: _selectedCity ?? '',
            preferredGenres: _selectedGenres.toList(),
          );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) context.showErrorSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Profile'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        automaticallyImplyLeading: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'One more step!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us personalise your experience',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ShowSnapColors.grey600,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                hint: const Text('Select your city'),
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCity = v),
              ),
              const SizedBox(height: 24),
              Text(
                'Favourite Genres',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _genres.map((g) {
                  final selected = _selectedGenres.contains(g);
                  return FilterChip(
                    label: Text(g),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedGenres.add(g);
                        } else {
                          _selectedGenres.remove(g);
                        }
                      });
                    },
                    selectedColor: ShowSnapColors.primaryLighter,
                    checkmarkColor: ShowSnapColors.onPrimary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
