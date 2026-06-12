import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/movie_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/models/show_model.dart';
import '../../../core/models/seat_status_model.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';

final _tmScreensProvider = FutureProvider<List<ScreenModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final theaters = await ref.watch(databaseServiceProvider).getAllTheaters();
  final theater =
      theaters.cast<dynamic>().firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) return [];
  return ref.watch(databaseServiceProvider).getScreensForTheater(theater.theaterId);
});

final _tmMoviesProvider = FutureProvider<List<MovieModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final db = ref.watch(databaseServiceProvider);
  final theaters = await db.getAllTheaters();
  final theater =
      theaters.cast<TheaterModel?>().firstWhere((t) => t?.managerId == uid, orElse: () => null);
  
  final Set<String> scheduledMovieIds = {};
  if (theater != null) {
    final shows = await db.getShowsForTheater(theater.theaterId);
    for (final s in shows) {
      scheduledMovieIds.add(s.movieId);
    }
  }

  final movies = await db.getAllMovies();
  return movies.where((m) => m.addedByTm == uid || scheduledMovieIds.contains(m.movieId)).toList();
});

class MovieManagerScreen extends ConsumerWidget {
  const MovieManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(_tmMoviesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Manager'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: moviesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (movies) => movies.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.movie_outlined,
                        size: 80, color: ShowSnapColors.grey600),
                    const SizedBox(height: 16),
                    const Text('No movies added yet'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          _showAddMovieDialog(context, ref),
                      child: const Text('Add Movie'),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
                itemCount: movies.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _MovieManagerCard(movie: movies[i])
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (i * 80).ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMovieDialog(context, ref),
        label: const Text('Add Movie'),
        icon: const Icon(Icons.add),
        backgroundColor: ShowSnapColors.primary,
      ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  void _showAddMovieDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AddMovieSelectionScreen()),
    );
  }
}

class _MovieManagerCard extends ConsumerWidget {
  final MovieModel movie;
  const _MovieManagerCard({required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: movie.posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: movie.posterUrl,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 50,
                  height: 70,
                  color: ShowSnapColors.grey300,
                  child: const Icon(Icons.movie_outlined),
                ),
        ),
        title: Text(movie.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${movie.language} • ${movie.certificate} • ${movie.durationMinutes} min'),
            Text(movie.genres.take(2).join(', '),
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'close') {
              await ref.read(databaseServiceProvider).updateMovie(
                  movie.movieId, {'status': 'closed'});
              ref.invalidate(_tmMoviesProvider);
              if (context.mounted) {
                context.showSnackbar('Movie closed');
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'close', child: Text('Close Movie')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

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
  File? _posterFile;
  bool _saving = false;
  
  ScreenModel? _selectedScreen;
  final List<TimeOfDay> _timeStamps = [];

  final _genres_list = [
    'Action', 'Comedy', 'Drama', 'Thriller', 'Horror',
    'Romance', 'Sci-Fi', 'Animation', 'Documentary', 'Fantasy',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Movie'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
            children: [
              // Poster upload
              GestureDetector(
                onTap: _pickPoster,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: ShowSnapColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShowSnapColors.grey300),
                  ),
                  child: _posterFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(_posterFile!.path, fit: BoxFit.cover)
                              : Image.file(_posterFile!, fit: BoxFit.cover))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 40, color: ShowSnapColors.grey600),
                            SizedBox(height: 8),
                            Text('Tap to upload poster'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _language,
                      decoration: const InputDecoration(labelText: 'Language'),
                      items: ['Hindi', 'English', 'Tamil', 'Telugu', 'Kannada', 'Malayalam']
                          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => _language = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _certificate,
                      decoration: const InputDecoration(labelText: 'Certificate'),
                      items: ['U', 'UA', 'A', 'S']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _certificate = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _trailerUrlCtrl,
                decoration: const InputDecoration(labelText: 'YouTube Trailer URL'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text('Start: ${DateFormat('dd MMM yyyy').format(_startDate)}', style: const TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      label: Text('End: ${DateFormat('dd MMM yyyy').format(_endDate)}', style: const TextStyle(fontSize: 12)),
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
              const SizedBox(height: 12),
              ref.watch(_tmScreensProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading screens: $e'),
                data: (screens) {
                  if (screens.isEmpty) return const Text('No screens available.');
                  return DropdownButtonFormField<ScreenModel>(
                    value: _selectedScreen,
                    decoration: const InputDecoration(labelText: 'Schedule on Screen (Optional)'),
                    items: screens
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedScreen = v),
                  );
                },
              ),
              if (_selectedScreen != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Show Times', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Time'),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) {
                          setState(() => _timeStamps.add(t));
                        }
                      },
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeStamps.map((t) {
                    return Chip(
                      label: Text(t.format(context)),
                      onDeleted: () => setState(() => _timeStamps.remove(t)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (min)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ['nowShowing', 'upcoming', 'closed']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _directorCtrl,
                decoration: const InputDecoration(labelText: 'Director'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _castCtrl,
                decoration: const InputDecoration(
                    labelText: 'Cast (comma-separated)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _synopsisCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Synopsis'),
              ),
              const SizedBox(height: 16),
              Text('Genres',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _genres_list.map((g) {
                  final selected = _genres.contains(g);
                  return FilterChip(
                    label: Text(g),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) _genres.add(g);
                      else _genres.remove(g);
                    }),
                    selectedColor: ShowSnapColors.primaryLighter,
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

  Future<void> _pickPoster() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (img != null) setState(() => _posterFile = File(img.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      String posterUrl = '';
      if (_posterFile != null) {
        posterUrl = await ref.read(cloudinaryServiceProvider).uploadImage(
            _posterFile!, AppConstants.cloudinaryMoviePosters);
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

        DateTime current = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final end = DateTime(_endDate.year, _endDate.month, _endDate.day);

        while (!current.isAfter(end)) {
          for (final t in _timeStamps) {
            final startDt = DateTime(current.year, current.month, current.day, t.hour, t.minute);
            final endDt = startDt.add(Duration(minutes: duration + 15));
            
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
        context.showSnackbar('Movie added and scheduled successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

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
      backgroundColor: ShowSnapColors.background,
      appBar: AppBar(
        title: const Text('Select Movie from Library'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search movie title...',
                      prefixIcon: const Icon(Icons.search, color: ShowSnapColors.grey600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShowSnapColors.primary,
                  foregroundColor: Colors.black87,
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
          ),
          const SizedBox(height: 12),
          Expanded(
            child: moviesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (movies) {
                final filtered = movies.where((m) {
                  return m.title.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No movies found in library',
                        style: TextStyle(color: ShowSnapColors.grey600)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final movie = filtered[i];
                    return Card(
                      color: ShowSnapColors.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _ScheduleExistingMovieForm(movie: movie),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: movie.posterUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: movie.posterUrl,
                                        width: 50,
                                        height: 75,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 50,
                                        height: 75,
                                        color: ShowSnapColors.grey300,
                                        child: const Icon(Icons.movie_outlined),
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
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${movie.language} • ${movie.certificate} • ${movie.durationMinutes} min',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: ShowSnapColors.grey600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      movie.genres.join(', '),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: ShowSnapColors.grey600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: ShowSnapColors.grey600),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: (i * 50).ms);
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
      backgroundColor: ShowSnapColors.background,
      appBar: AppBar(
        title: const Text('Schedule Movie'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: ShowSnapColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
                              color: ShowSnapColors.grey300,
                              child: const Icon(Icons.movie_outlined),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.movie.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.movie.language} • ${widget.movie.certificate} • ${widget.movie.durationMinutes} min',
                            style: const TextStyle(
                                fontSize: 13,
                                color: ShowSnapColors.grey600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.movie.genres.join(', '),
                            style: const TextStyle(
                                fontSize: 12,
                                color: ShowSnapColors.grey600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ref.watch(_tmScreensProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading screens: $e'),
              data: (screens) {
                if (screens.isEmpty) {
                  return const Text('No screens available. Please create a screen first.',
                      style: TextStyle(color: ShowSnapColors.error));
                }
                return DropdownButtonFormField<ScreenModel>(
                  value: _selectedScreen,
                  decoration: const InputDecoration(labelText: 'Schedule on Screen *'),
                  items: screens
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedScreen = v),
                  validator: (v) => v == null ? 'Screen is required' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                        'Start: ${DateFormat('dd MMM yyyy').format(_startDate)}',
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _startDate = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                        'End: ${DateFormat('dd MMM yyyy').format(_endDate)}',
                        style: const TextStyle(fontSize: 12)),
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
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Time'),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) {
                      setState(() => _timeStamps.add(t));
                    }
                  },
                ),
              ],
            ),
            if (_timeStamps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('At least one show time is required',
                    style: TextStyle(color: ShowSnapColors.grey600, fontSize: 12)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeStamps.map((t) {
                return Chip(
                  label: Text(t.format(context)),
                  onDeleted: () => setState(() => _timeStamps.remove(t)),
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
      context.showErrorSnackbar('Please add at least one show time.');
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

      DateTime current = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day);

      while (!current.isAfter(end)) {
        for (final t in _timeStamps) {
          final startDt = DateTime(current.year, current.month, current.day, t.hour, t.minute);
          final endDt = startDt.add(Duration(minutes: widget.movie.durationMinutes + 15));
          
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
        context.showSnackbar('Movie scheduled successfully!');
        ref.invalidate(_tmMoviesProvider);
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed to schedule: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
