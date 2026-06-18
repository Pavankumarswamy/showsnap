import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _tmScreensProvider = FutureProvider<List<ScreenModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final theaters = await ref.watch(databaseServiceProvider).getAllTheaters();
  final theater = theaters
      .cast<dynamic>()
      .firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) return [];
  return ref
      .watch(databaseServiceProvider)
      .getScreensForTheater(theater.theaterId);
});

final _tmMoviesProvider = FutureProvider<List<MovieModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final db = ref.watch(databaseServiceProvider);
  final theaters = await db.getAllTheaters();
  final theater = theaters
      .cast<TheaterModel?>()
      .firstWhere((t) => t?.managerId == uid, orElse: () => null);

  final Set<String> scheduledMovieIds = {};
  if (theater != null) {
    final shows = await db.getShowsForTheater(theater.theaterId);
    for (final s in shows) {
      scheduledMovieIds.add(s.movieId);
    }
  }

  final movies = await db.getAllMovies();
  return movies
      .where((m) => m.addedByTm == uid || scheduledMovieIds.contains(m.movieId))
      .toList();
});

class MovieManagerScreen extends ConsumerWidget {
  const MovieManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(_tmMoviesProvider);

    return PushDrawerLayout(
      backgroundColor: TMColors.background,
      drawer: TMDrawer(
        currentRoute: AppRoutes.movieManager,
        onNavigateTo: (route) => context.push(route),
        theaterName: 'My Theater',
      ),
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: TMColors.border),
        ),
        title: const Text(
          'Movie Manager',
          style: TextStyle(
              color: TMColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _AddMovieSelectionScreen()));
        },
        label:
            const Text('Add Movie', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: TMColors.primary,
        foregroundColor: Colors.black,
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
      body: moviesAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaffShimmerCard(
              height: 100,
              baseColor: TMColors.surface,
              highlightColor: TMColors.surfaceElevated,
            ),
          ),
        ),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AdminColors.error))),
        data: (movies) => movies.isEmpty
            ? StaffEmptyState(
                icon: Icons.movie_outlined,
                message:
                    'No movies added yet.\nTap + to add a movie to your library.',
                ctaLabel: 'Add Movie',
                onCta: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const _AddMovieSelectionScreen())),
              )
            : RefreshIndicator(
                color: TMColors.primary,
                backgroundColor: TMColors.surface,
                onRefresh: () => ref.refresh(_tmMoviesProvider.future),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 110,
                        ),
                        itemCount: movies.length,
                        itemBuilder: (_, i) => _MovieCard(movie: movies[i])
                            .animate()
                            .fadeIn(duration: 400.ms, delay: (i * 60).ms)
                            .slideY(begin: 0.08, end: 0),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: movies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _MovieCard(movie: movies[i])
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (i * 60).ms)
                          .slideY(begin: 0.08, end: 0),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _MovieCard extends ConsumerWidget {
  final MovieModel movie;
  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color statusColor;
    String statusLabel;
    switch (movie.status) {
      case 'nowShowing':
        statusColor = TMColors.primary;
        statusLabel = 'Now Showing';
        break;
      case 'upcoming':
        statusColor = const Color(0xFF42A5F5);
        statusLabel = 'Upcoming';
        break;
      default:
        statusColor = TMColors.textMuted;
        statusLabel = 'Closed';
    }

    return StaffGlassCard(
      padding: const EdgeInsets.all(12),
      surfaceColor: TMColors.surface,
      glowColor: statusColor.withOpacity(0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
            child: movie.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: movie.posterUrl,
                    width: 54,
                    height: 76,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _PosterPlaceholder(),
                  )
                : _PosterPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movie.title,
                        style: const TextStyle(
                            color: TMColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StaffBadge(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${movie.language} · ${movie.certificate} · ${movie.durationMinutes} min',
                  style: const TextStyle(
                      color: TMColors.textSecondary, fontSize: 12),
                ),
                if (movie.genres.isNotEmpty)
                  Text(
                    movie.genres.take(3).join(', '),
                    style: const TextStyle(
                        color: TMColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: TMColors.surfaceElevated,
            icon: const Icon(Icons.more_vert_rounded,
                color: TMColors.textSecondary, size: 20),
            onSelected: (action) async {
              if (action == 'edit') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _EditMovieForm(movie: movie),
                ));
              } else if (action == 'close') {
                final ok = await StaffConfirmDialog.show(
                  context,
                  title: 'Close Movie',
                  message:
                      'Mark "${movie.title}" as closed? No new bookings will be accepted.',
                  confirmLabel: 'Close Movie',
                  isDangerous: true,
                );
                if (ok == true) {
                  await ref.read(databaseServiceProvider).updateMovie(
                      movie.movieId, {'status': 'closed'});
                  ref.invalidate(_tmMoviesProvider);
                  if (context.mounted) {
                    ShowSnapToast.success(context, 'Movie closed');
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: TMColors.textSecondary, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Movie', style: TextStyle(color: TMColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'close',
                child: Row(
                  children: [
                    Icon(Icons.block_outlined, color: AdminColors.error, size: 18),
                    SizedBox(width: 8),
                    Text('Close Movie', style: TextStyle(color: AdminColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditMovieForm extends ConsumerStatefulWidget {
  final MovieModel movie;
  const _EditMovieForm({required this.movie});

  @override
  ConsumerState<_EditMovieForm> createState() => _EditMovieFormState();
}

class _EditMovieFormState extends ConsumerState<_EditMovieForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _synopsisCtrl;
  late final TextEditingController _directorCtrl;
  late final TextEditingController _castCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _trailerUrlCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _language;
  late String _certificate;
  late String _status;
  late final Set<String> _genres;
  XFile? _posterFile;
  Uint8List? _posterBytes;
  bool _saving = false;

  // ignore: non_constant_identifier_names
  final _genres_list = [
    'Action', 'Comedy', 'Drama', 'Thriller', 'Horror',
    'Romance', 'Sci-Fi', 'Animation', 'Documentary', 'Fantasy',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.movie.title);
    _synopsisCtrl = TextEditingController(text: widget.movie.synopsis);
    _directorCtrl = TextEditingController(text: widget.movie.director);
    _castCtrl = TextEditingController(text: widget.movie.cast.join(', '));
    _durationCtrl = TextEditingController(text: '${widget.movie.durationMinutes}');
    _trailerUrlCtrl = TextEditingController(text: widget.movie.trailerUrl);
    _startDate = DateTime.fromMillisecondsSinceEpoch(widget.movie.releaseDateTs);
    _endDate = DateTime.fromMillisecondsSinceEpoch(widget.movie.endDateTs);
    _language = widget.movie.language;
    if (!_language.isNotEmpty) _language = 'Hindi';
    _certificate = widget.movie.certificate;
    if (!_certificate.isNotEmpty) _certificate = 'UA';
    _status = widget.movie.status;
    _genres = Set.from(widget.movie.genres);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _synopsisCtrl.dispose();
    _directorCtrl.dispose();
    _castCtrl.dispose();
    _durationCtrl.dispose();
    _trailerUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TMColors.background,
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        title: const Text('Edit Movie',
            style: TextStyle(
                color: TMColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TMColors.primary))
                : const Text('SAVE',
                    style: TextStyle(
                        color: TMColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Poster
              GestureDetector(
                onTap: _pickPoster,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: TMColors.surface,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    border: Border.all(color: TMColors.border),
                  ),
                  child: _posterBytes != null
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md),
                          child: Image.memory(_posterBytes!, fit: BoxFit.cover))
                      : widget.movie.posterUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.md),
                              child: CachedNetworkImage(
                                imageUrl: widget.movie.posterUrl,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_outlined,
                                    size: 40, color: TMColors.textMuted),
                                const SizedBox(height: 8),
                                Text('Tap to change poster',
                                    style: TextStyle(
                                        color: TMColors.textSecondary)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),
              _formField(_titleCtrl, 'Title *',
                  validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _formDropdown<String>('Language', _language,
                      ['Hindi', 'English', 'Tamil', 'Telugu', 'Kannada', 'Malayalam'],
                      (v) => setState(() => _language = v!))),
                  const SizedBox(width: 12),
                  Expanded(child: _formDropdown<String>('Certificate', _certificate,
                      ['U', 'UA', 'A', 'S'],
                      (v) => setState(() => _certificate = v!))),
                ],
              ),
              const SizedBox(height: 12),
              _formField(_trailerUrlCtrl, 'YouTube Trailer URL'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today,
                          size: 16, color: TMColors.textSecondary),
                      label: Text(
                          'Start: ${DateFormat('dd MMM').format(_startDate)}',
                          style: const TextStyle(
                              color: TMColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: TMColors.surfaceElevated,
                        side: const BorderSide(color: TMColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.md)),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (d != null) setState(() => _startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event,
                          size: 16, color: TMColors.textSecondary),
                      label: Text(
                          'End: ${DateFormat('dd MMM').format(_endDate)}',
                          style: const TextStyle(
                              color: TMColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: TMColors.surfaceElevated,
                        side: const BorderSide(color: TMColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.md)),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime(2100));
                        if (d != null) setState(() => _endDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _formField(_durationCtrl, 'Duration (min)',
                        type: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _formDropdown<String>('Status', _status,
                        ['nowShowing', 'upcoming', 'closed'],
                        (v) => setState(() => _status = v!)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _formField(_directorCtrl, 'Director'),
              const SizedBox(height: 12),
              _formField(_castCtrl, 'Cast (comma-separated)'),
              const SizedBox(height: 12),
              _formField(_synopsisCtrl, 'Synopsis', maxLines: 4),
              const SizedBox(height: 16),
              const Text('Genres',
                  style: TextStyle(
                      color: TMColors.textSecondary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _genres_list.map((g) {
                  final selected = _genres.contains(g);
                  return FilterChip(
                    label: Text(g,
                        style: TextStyle(
                            color: selected
                                ? Colors.black
                                : TMColors.textSecondary)),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _genres.add(g);
                      } else {
                        _genres.remove(g);
                      }
                    }),
                    selectedColor: TMColors.primary,
                    backgroundColor: TMColors.surfaceElevated,
                    side: BorderSide(
                        color: selected ? TMColors.primary : TMColors.border),
                    checkmarkColor: Colors.black,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label,
      {TextInputType type = TextInputType.text,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: TMColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TMColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        filled: true,
        fillColor: TMColors.surfaceElevated,
      ),
    );
  }

  DropdownButtonFormField<T> _formDropdown<T>(
    String label,
    T? value,
    List<T> items,
    void Function(T?) onChanged, {
    String Function(T)? labelOf,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: TMColors.surfaceElevated,
      style: const TextStyle(color: TMColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TMColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.primary),
        ),
        filled: true,
        fillColor: TMColors.surfaceElevated,
      ),
      items: items.map((t) {
        final l = labelOf != null ? labelOf(t) : t.toString();
        return DropdownMenuItem(value: t, child: Text(l));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _pickPoster() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() {
        _posterFile = img;
        _posterBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String posterUrl = widget.movie.posterUrl;
      if (_posterBytes != null && _posterFile != null) {
        posterUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadImageBytes(
              _posterBytes!,
              _posterFile!.name,
              AppConstants.cloudinaryMoviePosters,
            );
      }
      final db = ref.read(databaseServiceProvider);
      final duration = int.tryParse(_durationCtrl.text) ?? 120;
      
      await db.updateMovie(widget.movie.movieId, {
        'title': _titleCtrl.text.trim(),
        'language': _language,
        'genres': _genres.toList(),
        'durationMinutes': duration,
        'certificate': _certificate,
        'synopsis': _synopsisCtrl.text.trim(),
        'cast': _castCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'director': _directorCtrl.text.trim(),
        'posterUrl': posterUrl,
        'trailerUrl': _trailerUrlCtrl.text.trim(),
        'status': _status,
        'releaseDateTs': _startDate.millisecondsSinceEpoch,
        'endDateTs': _endDate.millisecondsSinceEpoch,
      });

      ref.invalidate(_tmMoviesProvider);
      if (mounted) {
        ShowSnapToast.success(context, 'Movie updated!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.error(context, 'Failed: $e');
        setState(() => _saving = false);
      }
    }
  }
}

class _PosterPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 76,
        color: TMColors.surfaceElevated,
        child: const Icon(Icons.movie_outlined,
            color: TMColors.textMuted, size: 24),
      );
}

// ─── Add Movie Selection Screen ───────────────────────────────────────────────

final _allGlobalMoviesProvider = FutureProvider<List<MovieModel>>((ref) async {
  return ref.watch(databaseServiceProvider).getAllMovies();
});

class _AddMovieSelectionScreen extends ConsumerStatefulWidget {
  const _AddMovieSelectionScreen();

  @override
  ConsumerState<_AddMovieSelectionScreen> createState() =>
      _AddMovieSelectionScreenState();
}

class _AddMovieSelectionScreenState
    extends ConsumerState<_AddMovieSelectionScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(_allGlobalMoviesProvider);

    return Scaffold(
      backgroundColor: TMColors.background,
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Select Movie',
          style: TextStyle(
              color: TMColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                StaffSearchBar(
                  hint: 'Search movie title…',
                  onChanged: (v) => setState(() => _searchQuery = v),
                  bgColor: TMColors.surface,
                  borderColor: TMColors.border,
                  textColor: TMColors.textPrimary,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TMColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Brand New Movie',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => _AddMovieForm()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: TMColors.border, height: 1),
          Expanded(
            child: moviesAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StaffShimmerCard(
                    height: 90,
                    baseColor: TMColors.surface,
                    highlightColor: TMColors.surfaceElevated,
                  ),
                ),
              ),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AdminColors.error))),
              data: (movies) {
                final filtered = movies
                    .where((m) => m.title
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                if (filtered.isEmpty) {
                  return StaffEmptyState(
                    icon: Icons.movie_filter_outlined,
                    message: 'No movies found in library',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final movie = filtered[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              _ScheduleExistingMovieForm(movie: movie),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TMColors.surface,
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md),
                          border: Border.all(color: TMColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(ShowSnapRadius.sm),
                              child: movie.posterUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: movie.posterUrl,
                                      width: 46,
                                      height: 66,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 46,
                                      height: 66,
                                      color: TMColors.surfaceElevated,
                                      child: const Icon(Icons.movie_outlined,
                                          color: TMColors.textMuted),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: const TextStyle(
                                        color: TMColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${movie.language} · ${movie.certificate} · ${movie.durationMinutes} min',
                                    style: const TextStyle(
                                        color: TMColors.textSecondary,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    movie.genres.join(', '),
                                    style: const TextStyle(
                                        color: TMColors.textMuted,
                                        fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: TMColors.textMuted),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: (i * 40).ms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Movie Form (new) ─────────────────────────────────────────────────────

class _AddMovieForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddMovieForm> createState() => _AddMovieFormState();
}

class _AddMovieFormState extends ConsumerState<_AddMovieForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _synopsisCtrl = TextEditingController();
  final _directorCtrl = TextEditingController();
  final _castCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '120');
  final _trailerUrlCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  String _language = 'Hindi';
  String _certificate = 'UA';
  String _status = 'nowShowing';
  final Set<String> _genres = {};
  XFile? _posterFile;
  Uint8List? _posterBytes;
  bool _saving = false;
  ScreenModel? _selectedScreen;
  final List<TimeOfDay> _timeStamps = [];

  // ignore: non_constant_identifier_names
  final _genres_list = [
    'Action', 'Comedy', 'Drama', 'Thriller', 'Horror',
    'Romance', 'Sci-Fi', 'Animation', 'Documentary', 'Fantasy',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _synopsisCtrl.dispose();
    _directorCtrl.dispose();
    _castCtrl.dispose();
    _durationCtrl.dispose();
    _trailerUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TMColors.background,
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        title: const Text('Add Movie',
            style: TextStyle(
                color: TMColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TMColors.primary))
                : const Text('SAVE',
                    style: TextStyle(
                        color: TMColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Poster
              GestureDetector(
                onTap: _pickPoster,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: TMColors.surface,
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                    border: Border.all(color: TMColors.border),
                  ),
                  child: _posterBytes != null
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md),
                          child: Image.memory(_posterBytes!, fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 40, color: TMColors.textMuted),
                            const SizedBox(height: 8),
                            Text('Tap to upload poster',
                                style: TextStyle(
                                    color: TMColors.textSecondary)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _formField(_titleCtrl, 'Title *',
                  validator: (v) => v?.isEmpty == true ? 'Required' : null),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _formDropdown<String>('Language', _language,
                      ['Hindi', 'English', 'Tamil', 'Telugu', 'Kannada', 'Malayalam'],
                      (v) => setState(() => _language = v!))),
                  const SizedBox(width: 12),
                  Expanded(child: _formDropdown<String>('Certificate', _certificate,
                      ['U', 'UA', 'A', 'S'],
                      (v) => setState(() => _certificate = v!))),
                ],
              ),
              const SizedBox(height: 12),
              _formField(_trailerUrlCtrl, 'YouTube Trailer URL'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today,
                          size: 16, color: TMColors.textSecondary),
                      label: Text(
                          'Start: ${DateFormat('dd MMM').format(_startDate)}',
                          style: const TextStyle(
                              color: TMColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: TMColors.surfaceElevated,
                        side: const BorderSide(color: TMColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.md)),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (d != null) setState(() => _startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event,
                          size: 16, color: TMColors.textSecondary),
                      label: Text(
                          'End: ${DateFormat('dd MMM').format(_endDate)}',
                          style: const TextStyle(
                              color: TMColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: TMColors.surfaceElevated,
                        side: const BorderSide(color: TMColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.md)),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime(2100));
                        if (d != null) setState(() => _endDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ref.watch(_tmScreensProvider).when(
                    loading: () => const SizedBox(
                        height: 48,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: TMColors.primary, strokeWidth: 2))),
                    error: (e, _) =>
                        Text('Error loading screens: $e',
                            style: const TextStyle(color: AdminColors.error)),
                    data: (screens) {
                      if (screens.isEmpty) {
                        return const Text('No screens available.',
                            style: TextStyle(color: TMColors.textMuted));
                      }
                      return _formDropdown<ScreenModel>(
                          'Schedule on Screen (Optional)', _selectedScreen, screens,
                          (v) => setState(() => _selectedScreen = v),
                          labelOf: (s) => s.name);
                    },
                  ),
              if (_selectedScreen != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Show Times',
                        style: TextStyle(
                            color: TMColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, color: TMColors.primary),
                      label: const Text('Add Time',
                          style: TextStyle(color: TMColors.primary)),
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (t != null) setState(() => _timeStamps.add(t));
                      },
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _timeStamps.map((t) {
                    return Chip(
                      label: Text(t.format(context),
                          style:
                              const TextStyle(color: TMColors.textPrimary)),
                      backgroundColor: TMColors.surfaceElevated,
                      side: const BorderSide(color: TMColors.border),
                      onDeleted: () => setState(() => _timeStamps.remove(t)),
                      deleteIconColor: TMColors.textMuted,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _formField(_durationCtrl, 'Duration (min)',
                        type: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _formDropdown<String>('Status', _status,
                        ['nowShowing', 'upcoming', 'closed'],
                        (v) => setState(() => _status = v!)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _formField(_directorCtrl, 'Director'),
              const SizedBox(height: 12),
              _formField(_castCtrl, 'Cast (comma-separated)'),
              const SizedBox(height: 12),
              _formField(_synopsisCtrl, 'Synopsis', maxLines: 4),
              const SizedBox(height: 16),
              const Text('Genres',
                  style: TextStyle(
                      color: TMColors.textSecondary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _genres_list.map((g) {
                  final selected = _genres.contains(g);
                  return FilterChip(
                    label: Text(g,
                        style: TextStyle(
                            color: selected
                                ? Colors.black
                                : TMColors.textSecondary)),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _genres.add(g);
                      } else {
                        _genres.remove(g);
                      }
                    }),
                    selectedColor: TMColors.primary,
                    backgroundColor: TMColors.surfaceElevated,
                    side: BorderSide(
                        color: selected ? TMColors.primary : TMColors.border),
                    checkmarkColor: Colors.black,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label,
      {TextInputType type = TextInputType.text,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: TMColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TMColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        filled: true,
        fillColor: TMColors.surfaceElevated,
      ),
    );
  }

  DropdownButtonFormField<T> _formDropdown<T>(
    String label,
    T? value,
    List<T> items,
    void Function(T?) onChanged, {
    String Function(T)? labelOf,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: TMColors.surfaceElevated,
      style: const TextStyle(color: TMColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TMColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          borderSide: const BorderSide(color: TMColors.primary),
        ),
        filled: true,
        fillColor: TMColors.surfaceElevated,
      ),
      items: items.map((t) {
        final l = labelOf != null ? labelOf(t) : t.toString();
        return DropdownMenuItem(value: t, child: Text(l));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _pickPoster() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() {
        _posterFile = img;
        _posterBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      String posterUrl = '';
      if (_posterBytes != null && _posterFile != null) {
        posterUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadImageBytes(
              _posterBytes!,
              _posterFile!.name,
              AppConstants.cloudinaryMoviePosters,
            );
      }
      final db = ref.read(databaseServiceProvider);
      final duration = int.tryParse(_durationCtrl.text) ?? 120;
      final movieId = await db.createMovie(MovieModel(
        movieId: '',
        title: _titleCtrl.text.trim(),
        language: _language,
        genres: _genres.toList(),
        durationMinutes: duration,
        certificate: _certificate,
        synopsis: _synopsisCtrl.text.trim(),
        cast: _castCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        director: _directorCtrl.text.trim(),
        posterUrl: posterUrl,
        trailerUrl: _trailerUrlCtrl.text.trim(),
        status: _status,
        addedByTm: uid,
        releaseDateTs: _startDate.millisecondsSinceEpoch,
        endDateTs: _endDate.millisecondsSinceEpoch,
      ));

      if (_selectedScreen != null && _timeStamps.isNotEmpty) {
        final screen = _selectedScreen!;
        final pricing = {'silver': 200, 'gold': 300, 'platinum': 500};
        final seats = <String, SeatStatusModel>{};
        for (final seat in screen.seatLayout) {
          seats[seat.seatId] = const SeatStatusModel();
        }

        DateTime current =
            DateTime(_startDate.year, _startDate.month, _startDate.day);
        final end = DateTime(_endDate.year, _endDate.month, _endDate.day);

        while (!current.isAfter(end)) {
          for (final t in _timeStamps) {
            final startDt = DateTime(
                current.year, current.month, current.day, t.hour, t.minute);
            final endDt =
                startDt.add(Duration(minutes: duration + 15));
            await db.createShow(ShowModel(
              showId: '',
              movieId: movieId,
              theaterId: screen.theaterId,
              screenId: screen.screenId,
              startTs: startDt.millisecondsSinceEpoch,
              endTs: endDt.millisecondsSinceEpoch,
              pricing: pricing,
              bookingOpen: true,
              seats: seats,
              seatsAvailable: screen.seatLayout.length,
            ));
          }
          current = current.add(const Duration(days: 1));
        }
      }

      if (mounted) {
        ShowSnapToast.success(context, 'Movie added and scheduled!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.error(context, 'Failed: $e');
        setState(() => _saving = false);
      }
    }
  }
}

// ─── Schedule Existing Movie Form ─────────────────────────────────────────────

class _ScheduleExistingMovieForm extends ConsumerStatefulWidget {
  final MovieModel movie;
  const _ScheduleExistingMovieForm({required this.movie});

  @override
  ConsumerState<_ScheduleExistingMovieForm> createState() =>
      _ScheduleExistingMovieFormState();
}

class _ScheduleExistingMovieFormState
    extends ConsumerState<_ScheduleExistingMovieForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  ScreenModel? _selectedScreen;
  final List<TimeOfDay> _timeStamps = [];
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TMColors.background,
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        title: const Text('Schedule Movie',
            style: TextStyle(
                color: TMColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TMColors.primary))
                : const Text('SAVE',
                    style: TextStyle(
                        color: TMColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Movie info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TMColors.surface,
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                border: Border.all(color: TMColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                    child: widget.movie.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.movie.posterUrl,
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 90,
                            color: TMColors.surfaceElevated,
                            child: const Icon(Icons.movie_outlined,
                                color: TMColors.textMuted)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.movie.title,
                            style: const TextStyle(
                                color: TMColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.movie.language} · ${widget.movie.certificate} · ${widget.movie.durationMinutes} min',
                          style: const TextStyle(
                              color: TMColors.textSecondary, fontSize: 13),
                        ),
                        Text(
                          widget.movie.genres.join(', '),
                          style: const TextStyle(
                              color: TMColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ref.watch(_tmScreensProvider).when(
                  loading: () => const SizedBox(
                      height: 48,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: TMColors.primary, strokeWidth: 2))),
                  error: (e, _) => Text('Error loading screens: $e',
                      style: const TextStyle(color: AdminColors.error)),
                  data: (screens) {
                    if (screens.isEmpty) {
                      return const Text(
                        'No screens available. Please create a screen first.',
                        style: TextStyle(color: AdminColors.error),
                      );
                    }
                    return DropdownButtonFormField<ScreenModel>(
                      value: _selectedScreen,
                      dropdownColor: TMColors.surfaceElevated,
                      style: const TextStyle(color: TMColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Screen *',
                        labelStyle:
                            const TextStyle(color: TMColors.textSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md),
                          borderSide:
                              const BorderSide(color: TMColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md),
                          borderSide:
                              const BorderSide(color: TMColors.primary),
                        ),
                        filled: true,
                        fillColor: TMColors.surfaceElevated,
                      ),
                      items: screens
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedScreen = v),
                      validator: (v) =>
                          v == null ? 'Screen is required' : null,
                    );
                  },
                ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today,
                        size: 16, color: TMColors.textSecondary),
                    label: Text(
                        'Start: ${DateFormat('dd MMM yyyy').format(_startDate)}',
                        style: const TextStyle(
                            color: TMColors.textPrimary, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: TMColors.surfaceElevated,
                      side: const BorderSide(color: TMColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md)),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _startDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event,
                        size: 16, color: TMColors.textSecondary),
                    label: Text(
                        'End: ${DateFormat('dd MMM yyyy').format(_endDate)}',
                        style: const TextStyle(
                            color: TMColors.textPrimary, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: TMColors.surfaceElevated,
                      side: const BorderSide(color: TMColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.md)),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _endDate = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Show Times *',
                    style: TextStyle(
                        color: TMColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                TextButton.icon(
                  icon: const Icon(Icons.add, color: TMColors.primary),
                  label: const Text('Add Time',
                      style: TextStyle(color: TMColors.primary)),
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (t != null) setState(() => _timeStamps.add(t));
                  },
                ),
              ],
            ),
            if (_timeStamps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('At least one show time is required',
                    style: TextStyle(
                        color: TMColors.textMuted, fontSize: 12)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _timeStamps.map((t) {
                return Chip(
                  label: Text(t.format(context),
                      style: const TextStyle(color: TMColors.textPrimary)),
                  backgroundColor: TMColors.surfaceElevated,
                  side: const BorderSide(color: TMColors.border),
                  onDeleted: () => setState(() => _timeStamps.remove(t)),
                  deleteIconColor: TMColors.textMuted,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_timeStamps.isEmpty) {
      ShowSnapToast.warning(context, 'Please add at least one show time');
      return;
    }
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final screen = _selectedScreen!;
      final pricing = {'silver': 200, 'gold': 300, 'platinum': 500};
      final seats = <String, SeatStatusModel>{};
      for (final seat in screen.seatLayout) {
        seats[seat.seatId] = const SeatStatusModel();
      }

      DateTime current =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day);

      while (!current.isAfter(end)) {
        for (final t in _timeStamps) {
          final startDt = DateTime(
              current.year, current.month, current.day, t.hour, t.minute);
          final endDt = startDt
              .add(Duration(minutes: widget.movie.durationMinutes + 15));
          await db.createShow(ShowModel(
            showId: '',
            movieId: widget.movie.movieId,
            theaterId: screen.theaterId,
            screenId: screen.screenId,
            startTs: startDt.millisecondsSinceEpoch,
            endTs: endDt.millisecondsSinceEpoch,
            pricing: pricing,
            bookingOpen: true,
            seats: seats,
            seatsAvailable: screen.seatLayout.length,
          ));
        }
        current = current.add(const Duration(days: 1));
      }

      if (mounted) {
        ShowSnapToast.success(context, 'Movie scheduled successfully!');
        ref.invalidate(_tmMoviesProvider);
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.error(context, 'Failed to schedule: $e');
        setState(() => _saving = false);
      }
    }
  }
}
