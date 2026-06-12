import 'dart:io';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/ad_request_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';
import '../../../core/widgets/tappable_scale.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _theatersProvider =
    FutureProvider.autoDispose<List<TheaterModel>>((ref) =>
        ref.watch(databaseServiceProvider).getAllTheaters());

final _screensProvider =
    FutureProvider.autoDispose.family<List<ScreenModel>, String>(
        (ref, theaterId) =>
            ref.watch(databaseServiceProvider).getScreensForTheater(theaterId));

// ─── Constants ────────────────────────────────────────────────────────────────

const _stepLabels = [
  'Brand Info',
  'Theaters',
  'Schedule',
  'Creatives',
  'Review',
];

const _campaignGoals = [
  'Brand Awareness',
  'Direct Bookings',
  'Event Promotion',
  'Product Launch',
];

const _displaySlots = ['Morning', 'Afternoon', 'Evening', 'Late Night'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdRequestFormScreen extends ConsumerStatefulWidget {
  const AdRequestFormScreen({super.key});

  @override
  ConsumerState<AdRequestFormScreen> createState() =>
      _AdRequestFormScreenState();
}

class _AdRequestFormScreenState extends ConsumerState<AdRequestFormScreen> {
  int _step = 0;
  final _pageCtrl = PageController();

  // ── Step 1: Brand Info ─────────────────────────────────────────────────────
  final _formKey1 = GlobalKey<FormState>();
  final _brandCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _phone = '';
  bool _phoneValid = false;
  final _campaignTitleCtrl = TextEditingController();
  String _campaignGoal = _campaignGoals[0];

  // ── Step 2: Theater & Screen Selection ────────────────────────────────────
  final Set<String> _selectedTheaters = {};
  final Map<String, Set<String>> _selectedScreens = {};

  // ── Step 3: Schedule & Budget ──────────────────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _selectedSlots = {'Evening'};
  RangeValues _budgetRange = const RangeValues(10000, 100000);
  final _notesCtrl = TextEditingController();

  // ── Step 4: Creative Upload ────────────────────────────────────────────────
  File? _creativeFile;
  String? _creativeUrl;
  double _uploadProgress = 0;
  bool _uploading = false;
  String _creativeType = 'image';

  // ── Step 5: Review & Submit ────────────────────────────────────────────────
  bool _termsAccepted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _contactCtrl.dispose();
    _campaignTitleCtrl.dispose();
    _notesCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_step == 0 && !(_formKey1.currentState?.validate() ?? false)) return;
    if (_step == 0 && !_phoneValid) {
      ShowSnapToast.show(context, message: 'Enter a valid phone number', type: ToastType.error);
      return;
    }
    if (_step == 1 && _selectedTheaters.isEmpty) {
      ShowSnapToast.show(context, message: 'Select at least one theater', type: ToastType.error);
      return;
    }
    if (_step == 2 && (_startDate == null || _endDate == null)) {
      ShowSnapToast.show(context, message: 'Select campaign dates', type: ToastType.error);
      return;
    }
    if (_step == 2 && _selectedSlots.isEmpty) {
      ShowSnapToast.show(context,
          message: 'Select at least one display slot', type: ToastType.error);
      return;
    }
    if (_step == 3 && _creativeUrl == null) {
      ShowSnapToast.show(context, message: 'Upload a creative first', type: ToastType.error);
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: ShowSnapDuration.page, curve: Curves.easeInOut);
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: ShowSnapDuration.page, curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _pickCreative() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final ext = path.split('.').last.toLowerCase();
    setState(() {
      _creativeFile = File(path);
      _creativeType = ['mp4', 'mov'].contains(ext) ? 'video' : 'image';
      _creativeUrl = null;
      _uploadProgress = 0;
    });
    await _uploadCreative();
  }

  Future<void> _uploadCreative() async {
    if (_creativeFile == null) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      // Tick progress indicator while upload runs in background
      var ticking = true;
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!ticking || !mounted) return false;
        setState(() => _uploadProgress = (_uploadProgress + 0.05).clamp(0, 0.9));
        return ticking;
      });

      final svc = ref.read(cloudinaryServiceProvider);
      final url = _creativeType == 'video'
          ? await svc.uploadVideo(_creativeFile!, 'ad_creatives')
          : await svc.uploadImage(_creativeFile!, 'ad_creatives');
      ticking = false;
      if (mounted) {
        setState(() {
          _creativeUrl = url;
          _uploading = false;
          _uploadProgress = 1.0;
        });
        ShowSnapToast.show(context, message: 'Creative uploaded!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
        });
        ShowSnapToast.show(context, message: 'Upload failed: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      ShowSnapToast.show(context, message: 'Accept terms to continue', type: ToastType.error);
      return;
    }
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      ShowSnapToast.show(context, message: 'Please log in', type: ToastType.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      final allScreens =
          _selectedScreens.values.expand((s) => s).toList();

      final request = AdRequestModel(
        requestId: '',
        uid: uid,
        brandName: _brandCtrl.text.trim(),
        campaignTitle: _campaignTitleCtrl.text.trim(),
        description:
            '$_campaignGoal. Contact: ${_contactCtrl.text.trim()} | $_phone\n'
            'Slots: ${_selectedSlots.join(", ")}\n'
            '${_notesCtrl.text.trim()}',
        targetTheaters: _selectedTheaters.toList(),
        targetScreens: allScreens,
        creativeUrls: [if (_creativeUrl != null) _creativeUrl!],
        startDateTs: _startDate!.millisecondsSinceEpoch,
        endDateTs: _endDate!.millisecondsSinceEpoch,
        budgetRange:
            '${_budgetRange.start.toInt()}-${_budgetRange.end.toInt()}',
        status: AdRequestStatus.pending,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await ref.read(databaseServiceProvider).submitAdRequest(request);
      if (mounted) {
        setState(() => _submitting = false);
        _showSuccessSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ShowSnapToast.show(context, message: 'Submission failed: $e', type: ToastType.error);
      }
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(ShowSnapRadius.lg))),
      builder: (_) => _SuccessSheet(
        campaignTitle: _campaignTitleCtrl.text.trim(),
        onDone: () {
          Navigator.pop(context);
          context.go('/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShowSnapColors.grey100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _goBack,
        ),
        title: Text(
          _step < _stepLabels.length ? _stepLabels[_step] : 'Review',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1BrandInfo(
                  formKey: _formKey1,
                  brandCtrl: _brandCtrl,
                  contactCtrl: _contactCtrl,
                  campaignTitleCtrl: _campaignTitleCtrl,
                  campaignGoal: _campaignGoal,
                  onGoalChanged: (g) => setState(() => _campaignGoal = g),
                  onPhoneChanged: (p, v) =>
                      setState(() {
                        _phone = p;
                        _phoneValid = v;
                      }),
                ),
                _Step2Theaters(
                  selectedTheaters: _selectedTheaters,
                  selectedScreens: _selectedScreens,
                  onToggleTheater: (id) => setState(() {
                    if (_selectedTheaters.contains(id)) {
                      _selectedTheaters.remove(id);
                      _selectedScreens.remove(id);
                    } else {
                      _selectedTheaters.add(id);
                    }
                  }),
                  onToggleScreen: (theaterId, screenId) => setState(() {
                    _selectedScreens.putIfAbsent(theaterId, () => {});
                    final s = _selectedScreens[theaterId]!;
                    if (s.contains(screenId)) {
                      s.remove(screenId);
                    } else {
                      s.add(screenId);
                    }
                  }),
                ),
                _Step3Schedule(
                  startDate: _startDate,
                  endDate: _endDate,
                  selectedSlots: _selectedSlots,
                  budgetRange: _budgetRange,
                  notesCtrl: _notesCtrl,
                  onStartDate: (d) => setState(() => _startDate = d),
                  onEndDate: (d) => setState(() => _endDate = d),
                  onToggleSlot: (s) => setState(() {
                    if (_selectedSlots.contains(s)) {
                      _selectedSlots.remove(s);
                    } else {
                      _selectedSlots.add(s);
                    }
                  }),
                  onBudgetChanged: (r) => setState(() => _budgetRange = r),
                ),
                _Step4Creative(
                  creativeFile: _creativeFile,
                  creativeUrl: _creativeUrl,
                  creativeType: _creativeType,
                  uploading: _uploading,
                  uploadProgress: _uploadProgress,
                  onPick: _pickCreative,
                ),
                _Step5Review(
                  brandName: _brandCtrl.text,
                  campaignTitle: _campaignTitleCtrl.text,
                  campaignGoal: _campaignGoal,
                  contact: _contactCtrl.text,
                  phone: _phone,
                  theaterCount: _selectedTheaters.length,
                  screenCount: _selectedScreens.values
                      .fold(0, (s, e) => s + e.length),
                  startDate: _startDate,
                  endDate: _endDate,
                  slots: _selectedSlots.toList(),
                  budgetRange: _budgetRange,
                  creativeUrl: _creativeUrl,
                  termsAccepted: _termsAccepted,
                  onTermsChanged: (v) =>
                      setState(() => _termsAccepted = v ?? false),
                  submitting: _submitting,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
          if (_step < 4)
            _BottomBar(
              step: _step,
              onNext: _goNext,
              onBack: _goBack,
            ),
        ],
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: List.generate(_stepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done = stepIdx < current;
            return Expanded(
              child: AnimatedContainer(
                duration: ShowSnapDuration.normal,
                height: 2,
                color:
                    done ? ShowSnapColors.primary : ShowSnapColors.grey300,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx < current;
          final active = idx == current;
          return AnimatedContainer(
            duration: ShowSnapDuration.normal,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || active
                  ? ShowSnapColors.primary
                  : ShowSnapColors.grey300,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.black87)
                  : Text('${idx + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.black87
                            : ShowSnapColors.grey600,
                      )),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Bottom Nav Bar ───────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _BottomBar(
      {required this.step, required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.md)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: TappableScale(
              onTap: onNext,
              child: Container(
                height: 52,
                decoration: ShowSnapTheme.primaryButtonDecoration,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    onTap: onNext,
                    child: Center(
                      child: Text(
                        step == 3 ? 'Review' : 'Continue',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: Brand Info ───────────────────────────────────────────────────────

class _Step1BrandInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController brandCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController campaignTitleCtrl;
  final String campaignGoal;
  final void Function(String) onGoalChanged;
  final void Function(String phone, bool valid) onPhoneChanged;

  const _Step1BrandInfo({
    required this.formKey,
    required this.brandCtrl,
    required this.contactCtrl,
    required this.campaignTitleCtrl,
    required this.campaignGoal,
    required this.onGoalChanged,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Brand Details'),
            const SizedBox(height: 12),
            _Field(
              controller: brandCtrl,
              label: 'Brand / Company Name',
              icon: Icons.business_outlined,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Brand name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            _Field(
              controller: contactCtrl,
              label: 'Contact Person Name',
              icon: Icons.person_outline_rounded,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Contact name is required'
                  : null,
            ),
            const SizedBox(height: 14),
            IntlPhoneField(
              decoration: InputDecoration(
                labelText: 'Phone Number',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              initialCountryCode: 'IN',
              onChanged: (phone) => onPhoneChanged(
                  phone.completeNumber, phone.isValidNumber()),
            ),
            const SizedBox(height: 20),
            const _SectionHeader('Campaign Details'),
            const SizedBox(height: 12),
            _Field(
              controller: campaignTitleCtrl,
              label: 'Campaign Title',
              icon: Icons.campaign_outlined,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Campaign title is required'
                  : null,
            ),
            const SizedBox(height: 16),
            const Text('Campaign Goal',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            ...List.generate(_campaignGoals.length, (i) {
              final goal = _campaignGoals[i];
              return RadioListTile<String>(
                value: goal,
                groupValue: campaignGoal,
                onChanged: (v) => onGoalChanged(v!),
                title: Text(goal),
                activeColor: ShowSnapColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Theaters ─────────────────────────────────────────────────────────

class _Step2Theaters extends ConsumerWidget {
  final Set<String> selectedTheaters;
  final Map<String, Set<String>> selectedScreens;
  final void Function(String) onToggleTheater;
  final void Function(String, String) onToggleScreen;

  const _Step2Theaters({
    required this.selectedTheaters,
    required this.selectedScreens,
    required this.onToggleTheater,
    required this.onToggleScreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theatersAsync = ref.watch(_theatersProvider);
    return theatersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading theaters: $e')),
      data: (theaters) {
        if (theaters.isEmpty) {
          return const Center(
            child: Text('No theaters available',
                style: TextStyle(color: ShowSnapColors.grey600)),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionHeader('Select Target Theaters'),
            const SizedBox(height: 4),
            const Text(
              'Choose theaters where your ad will run',
              style: TextStyle(
                  color: ShowSnapColors.grey600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...theaters.map((t) => _TheaterTile(
                  theater: t,
                  isSelected: selectedTheaters.contains(t.theaterId),
                  selectedScreens:
                      selectedScreens[t.theaterId] ?? const {},
                  onToggle: () => onToggleTheater(t.theaterId),
                  onToggleScreen: (sid) =>
                      onToggleScreen(t.theaterId, sid),
                )),
          ],
        );
      },
    );
  }
}

class _TheaterTile extends ConsumerWidget {
  final TheaterModel theater;
  final bool isSelected;
  final Set<String> selectedScreens;
  final VoidCallback onToggle;
  final void Function(String) onToggleScreen;

  const _TheaterTile({
    required this.theater,
    required this.isSelected,
    required this.selectedScreens,
    required this.onToggle,
    required this.onToggleScreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screensAsync =
        isSelected ? ref.watch(_screensProvider(theater.theaterId)) : null;

    return AnimatedContainer(
      duration: ShowSnapDuration.normal,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(
          color: isSelected
              ? ShowSnapColors.primary
              : ShowSnapColors.grey300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: isSelected,
            onChanged: (_) => onToggle(),
            title: Text(theater.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            activeColor: ShowSnapColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
          ),
          if (isSelected && screensAsync != null)
            screensAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (screens) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Screens:',
                        style: TextStyle(
                            fontSize: 12,
                            color: ShowSnapColors.grey600,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: screens.map((sc) {
                        final picked =
                            selectedScreens.contains(sc.screenId);
                        return FilterChip(
                          label: Text(
                              '${sc.name} · ${sc.technology}'),
                          selected: picked,
                          onSelected: (_) =>
                              onToggleScreen(sc.screenId),
                          selectedColor:
                              ShowSnapColors.primary.withOpacity(0.2),
                          checkmarkColor: ShowSnapColors.primary,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: picked
                                ? ShowSnapColors.primary
                                : Colors.black87,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step 3: Schedule & Budget ────────────────────────────────────────────────

class _Step3Schedule extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> selectedSlots;
  final RangeValues budgetRange;
  final TextEditingController notesCtrl;
  final void Function(DateTime) onStartDate;
  final void Function(DateTime) onEndDate;
  final void Function(String) onToggleSlot;
  final void Function(RangeValues) onBudgetChanged;

  const _Step3Schedule({
    required this.startDate,
    required this.endDate,
    required this.selectedSlots,
    required this.budgetRange,
    required this.notesCtrl,
    required this.onStartDate,
    required this.onEndDate,
    required this.onToggleSlot,
    required this.onBudgetChanged,
  });

  String _fmt(DateTime? d) =>
      d == null ? 'Select' : DateFormat('dd MMM yyyy').format(d);

  String _fmtBudget(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Campaign Duration'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'Start Date',
                  value: _fmt(startDate),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: startDate ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (d != null) onStartDate(d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateButton(
                  label: 'End Date',
                  value: _fmt(endDate),
                  onTap: () async {
                    final first =
                        startDate ?? DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: endDate ??
                          first.add(const Duration(days: 14)),
                      firstDate: first,
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (d != null) onEndDate(d);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Display Slots'),
          const SizedBox(height: 6),
          const Text('Select when your ad will be shown',
              style: TextStyle(
                  color: ShowSnapColors.grey600, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _displaySlots.map((slot) {
              final active = selectedSlots.contains(slot);
              return FilterChip(
                label: Text(slot),
                selected: active,
                onSelected: (_) => onToggleSlot(slot),
                selectedColor:
                    ShowSnapColors.primary.withOpacity(0.2),
                checkmarkColor: ShowSnapColors.primary,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active
                      ? ShowSnapColors.primary
                      : Colors.black87,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Budget Range'),
          const SizedBox(height: 6),
          Text(
            '₹${_fmtBudget(budgetRange.start.toInt())} — ₹${_fmtBudget(budgetRange.end.toInt())}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: ShowSnapColors.primary),
          ),
          RangeSlider(
            values: budgetRange,
            min: 10000,
            max: 500000,
            divisions: 49,
            activeColor: ShowSnapColors.primary,
            onChanged: onBudgetChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${_fmtBudget(10000)}',
                  style: const TextStyle(
                      color: ShowSnapColors.grey600, fontSize: 12)),
              Text('₹${_fmtBudget(500000)}',
                  style: const TextStyle(
                      color: ShowSnapColors.grey600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Additional Notes'),
          const SizedBox(height: 10),
          TextFormField(
            controller: notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Any specific requirements or target audience notes...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateButton(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          boxShadow: ShowSnapShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: ShowSnapColors.grey600)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: ShowSnapColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 4: Creative Upload ──────────────────────────────────────────────────

class _Step4Creative extends StatelessWidget {
  final File? creativeFile;
  final String? creativeUrl;
  final String creativeType;
  final bool uploading;
  final double uploadProgress;
  final VoidCallback onPick;

  const _Step4Creative({
    required this.creativeFile,
    required this.creativeUrl,
    required this.creativeType,
    required this.uploading,
    required this.uploadProgress,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Upload Creative'),
          const SizedBox(height: 6),
          const Text('Supported: JPG, PNG, MP4, MOV',
              style: TextStyle(
                  color: ShowSnapColors.grey600, fontSize: 13)),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: uploading ? null : onPick,
            child: AnimatedContainer(
              duration: ShowSnapDuration.normal,
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ShowSnapRadius.lg),
                border: Border.all(
                  color: creativeUrl != null
                      ? ShowSnapColors.primary
                      : ShowSnapColors.grey300,
                  width: 2,
                ),
                boxShadow: ShowSnapShadow.card,
              ),
              child: creativeUrl != null
                  ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.lg - 2),
                      child: creativeType == 'image' && creativeFile != null
                          ? kIsWeb
                              ? Image.network(creativeFile!.path, fit: BoxFit.cover)
                              : Image.file(creativeFile!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam_outlined,
                                    size: 64,
                                    color: ShowSnapColors.primary),
                                const SizedBox(height: 8),
                                const Text('Video uploaded',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if (creativeFile != null)
                                  Text(
                                    creativeFile!.path
                                        .split(Platform.pathSeparator)
                                        .last,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: ShowSnapColors.grey600),
                                  ),
                              ],
                            ),
                    )
                  : uploading
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined,
                                  size: 52,
                                  color: ShowSnapColors.primary),
                              const SizedBox(height: 20),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: uploadProgress,
                                  backgroundColor: ShowSnapColors.grey300,
                                  color: ShowSnapColors.primary,
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(uploadProgress * 100).toStringAsFixed(0)}% uploading...',
                                style: const TextStyle(
                                    color: ShowSnapColors.grey600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 60, color: ShowSnapColors.grey600),
                            const SizedBox(height: 12),
                            const Text('Tap to upload creative',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text(
                              'JPG, PNG up to 10 MB\nMP4, MOV up to 50 MB',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: ShowSnapColors.grey600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
            ),
          ),

          if (creativeUrl != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                border:
                    Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Creative ready',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: onPick,
                    child: const Text('Replace'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ShowSnapColors.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 18, color: ShowSnapColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your creative is uploaded using a secure unsigned '
                    'preset. The Cloudinary API secret is never stored on '
                    'your device.',
                    style: TextStyle(
                        color: ShowSnapColors.grey600,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 5: Review & Submit ──────────────────────────────────────────────────

class _Step5Review extends StatelessWidget {
  final String brandName;
  final String campaignTitle;
  final String campaignGoal;
  final String contact;
  final String phone;
  final int theaterCount;
  final int screenCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> slots;
  final RangeValues budgetRange;
  final String? creativeUrl;
  final bool termsAccepted;
  final void Function(bool?) onTermsChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  const _Step5Review({
    required this.brandName,
    required this.campaignTitle,
    required this.campaignGoal,
    required this.contact,
    required this.phone,
    required this.theaterCount,
    required this.screenCount,
    required this.startDate,
    required this.endDate,
    required this.slots,
    required this.budgetRange,
    required this.creativeUrl,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.submitting,
    required this.onSubmit,
  });

  String _fmt(DateTime? d) =>
      d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Campaign Summary'),
          const SizedBox(height: 14),
          _ReviewCard(title: 'Brand & Campaign', rows: [
            ('Brand', brandName.isEmpty ? '—' : brandName),
            ('Contact', contact.isEmpty ? '—' : contact),
            ('Phone', phone.isEmpty ? '—' : phone),
            ('Campaign', campaignTitle.isEmpty ? '—' : campaignTitle),
            ('Goal', campaignGoal),
          ]),
          const SizedBox(height: 12),
          _ReviewCard(title: 'Placement', rows: [
            ('Theaters',
                '$theaterCount theater${theaterCount != 1 ? "s" : ""}'),
            ('Screens',
                '$screenCount screen${screenCount != 1 ? "s" : ""}'),
          ]),
          const SizedBox(height: 12),
          _ReviewCard(title: 'Schedule & Budget', rows: [
            ('Start', _fmt(startDate)),
            ('End', _fmt(endDate)),
            ('Slots', slots.isEmpty ? '—' : slots.join(', ')),
            ('Budget',
                '₹${budgetRange.start.toInt()} – ₹${budgetRange.end.toInt()}'),
          ]),
          const SizedBox(height: 12),
          _ReviewCard(title: 'Creative', rows: [
            ('Status',
                creativeUrl != null ? 'Uploaded ✓' : 'Not uploaded'),
          ]),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: termsAccepted,
            onChanged: onTermsChanged,
            activeColor: ShowSnapColors.primary,
            title: RichText(
              text: TextSpan(
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  const TextSpan(
                    text: 'ShowSnap Ad Campaign Terms',
                    style: TextStyle(
                        color: ShowSnapColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(
                      text:
                          ' and confirm all information is accurate.'),
                ],
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TappableScale(
            onTap: submitting ? null : onSubmit,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: ShowSnapTheme.primaryButtonDecoration,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  onTap: submitting ? null : onSubmit,
                  child: Center(
                    child: submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black87),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded,
                                  color: Colors.black87),
                              SizedBox(width: 10),
                              Text('Submit Campaign',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                      color: Colors.black87)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _ReviewCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const Divider(height: 1),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(row.$1,
                          style: const TextStyle(
                              color: ShowSnapColors.grey600,
                              fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(row.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─── Success Sheet ────────────────────────────────────────────────────────────

class _SuccessSheet extends StatefulWidget {
  final String campaignTitle;
  final VoidCallback onDone;
  const _SuccessSheet(
      {required this.campaignTitle, required this.onDone});

  @override
  State<_SuccessSheet> createState() => _SuccessSheetState();
}

class _SuccessSheetState extends State<_SuccessSheet> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    HapticFeedback.heavyImpact();
    Future.microtask(() => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, 32, 24, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: ShowSnapTheme.appBarGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.black87, size: 44),
              )
                  .animate()
                  .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: const Duration(milliseconds: 800))
                  .fadeIn(),
              const SizedBox(height: 20),
              const Text('Campaign Submitted!',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 22))
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 10),
              Text(
                '"${widget.campaignTitle}" is under review.\n'
                'Our team will reach out within 2–3 business days.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ShowSnapColors.grey600,
                    fontSize: 14,
                    height: 1.5),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShowSnapColors.primary,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ShowSnapRadius.md)),
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 30,
          gravity: 0.15,
          colors: const [
            ShowSnapColors.primary,
            ShowSnapColors.secondary,
            Colors.white,
            Colors.deepPurple,
          ],
        ),
      ],
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 16));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ShowSnapColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: ShowSnapColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: ShowSnapColors.error),
        ),
      ),
    );
  }
}
