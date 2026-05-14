import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../../../core/auth/auth_repository.dart';
import '../../../core/constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../../features/students/data/student_repository.dart';
import '../../../features/debug/log_screen.dart';
import '../data/assessment_repository.dart';
import '../data/stats_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../features/ota_update/ota_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../logic/assessment_calculator.dart';

final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

enum EvalState { idle, recording, analyzing, reviewing }

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  // Estudiantes
  List<Student> _allStudents = [];
  List<String> _cursos = [];
  String? _selectedCurso;
  List<Student> _studentsInCurso = [];
  Student? _selectedStudent;

  // Textos
  List<ReadingText> _textos = [];
  ReadingText? _selectedTexto;

  bool _syncing = false;
  bool _checkingUpdate = false;
  EvalState _state = EvalState.idle;
  int _titleTaps = 0;

  // Contadores
  int _errores = 0;
  int _palabrasLeidas = 0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // Evaluación cualitativa
  String _calidad = 'fluida';
  String _prosodia = 'adecuada';

  // Audio
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioPath;

  // Análisis Whisper
  String? _transcript;
  bool _whisperFailed = false;
  bool _whisperAnalyzed = false;
  List<Map<String, dynamic>> _erroresDetalle = [];

  // Scroll
  final GlobalKey _timerSectionKey = GlobalKey();
  final GlobalKey _resultsKey = GlobalKey();
  ScrollController? _leftPanelScrollController;
  ScrollController? _rightPanelScrollController;

  // Contexto post-análisis
  CourseStats? _courseStats;
  List<StudentHistory> _studentHistory = [];
  bool _loadingContext = false;

  @override
  void initState() {
    super.initState();
    _leftPanelScrollController = ScrollController();
    _rightPanelScrollController = ScrollController();
    _syncAndLoad();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _leftPanelScrollController?.dispose();
    _rightPanelScrollController?.dispose();
    super.dispose();
  }

  Future<void> _syncAndLoad() async {
    final db = ref.read(dbProvider);
    final local = await db.getAllStudents();
    if (mounted) _updateStudentLists(local);

    // Subir evaluaciones pendientes de sesiones anteriores (fire & forget)
    AssessmentRepository(db, ApiClient()).syncPending().catchError((_) {});

    setState(() => _syncing = true);
    try {
      log.info('Sincronizando estudiantes desde el servidor...');
      final repo = StudentRepository(db, ApiClient());
      await repo.syncFromServer();
      final updated = await db.getAllStudents();
      log.info('Sync OK — ${updated.length} estudiantes cargados');
      if (mounted) _updateStudentLists(updated);
    } catch (e) {
      log.error('Error sincronizando estudiantes', e);
      if (mounted && _allStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sin conexión — sin estudiantes disponibles. Error: $e',
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _updateStudentLists(List<Student> students) {
    final cursos = students.map((s) => s.curso).toSet().toList()..sort();
    setState(() {
      _allStudents = students;
      _cursos = cursos;
      // Si el curso seleccionado ya no existe, resetear
      if (_selectedCurso != null && !cursos.contains(_selectedCurso)) {
        _selectedCurso = null;
        _selectedStudent = null;
        _studentsInCurso = [];
      }
    });
  }

  void _onCursoChanged(String? curso) async {
    if (curso == null) return;
    final db = ref.read(dbProvider);
    final students = await db.getStudentsByCurso(curso);
    // Extraer número de nivel del curso ("2°A" → "2")
    final nivel = RegExp(r'\d+').firstMatch(curso)?.group(0) ?? '';
    final textos = nivel.isNotEmpty
        ? await db.getTextsByNivel(nivel)
        : <ReadingText>[];
    setState(() {
      _selectedCurso = curso;
      _studentsInCurso = students;
      _selectedStudent = null;
      _textos = textos;
      _selectedTexto = null;
    });
  }

  void _onStudentChanged(Student? student) {
    setState(() {
      _selectedStudent = student;
      _selectedTexto = null;
      _courseStats = null;
      _studentHistory = [];
    });
  }

  void _scrollToTimer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _timerSectionKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final apiClient = ApiClient();
      final otaService = OtaService(apiClient.dio);
      await otaService.checkAndUpdate(
        onProgress: (p) =>
            log.info('OTA descargando: ${(p * 100).toStringAsFixed(0)}%'),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    log.info('Cerrando sesión');
    await AuthRepository(ApiClient()).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _onTitleTap() {
    _titleTaps++;
    if (_titleTaps >= 5) {
      _titleTaps = 0;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LogScreen()));
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      log.warn('Permiso de micrófono denegado');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/eval_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _audioPath = path;
      _state = EvalState.recording;
      _elapsed = Duration.zero;
      _errores = 0;
      _palabrasLeidas = _selectedTexto?.totalPalabras ?? 0;
      _erroresDetalle = [];
      _whisperAnalyzed = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _state = EvalState.analyzing);
    await _transcribeAudio();
  }

  Future<void> _transcribeAudio() async {
    if (_audioPath == null || _selectedTexto == null) {
      setState(() => _state = EvalState.reviewing);
      return;
    }
    try {
      final formData = dio_pkg.FormData.fromMap({
        'audio': await dio_pkg.MultipartFile.fromFile(
          _audioPath!,
          filename: 'eval.m4a',
        ),
        'texto_esperado': _selectedTexto!.contenido,
      });
      final client = dio_pkg.Dio(
        dio_pkg.BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final response = await client.post(
        kWhisperUrl,
        data: formData,
        options: dio_pkg.Options(headers: {'X-API-Key': kWhisperApiKey}),
      );
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _transcript = data['transcript'] as String? ?? '';
        _palabrasLeidas =
            (data['palabras_leidas'] as num?)?.toInt() ??
            (_selectedTexto?.totalPalabras ?? 0);
        _errores = (data['errores'] as num?)?.toInt() ?? 0;
        _erroresDetalle =
            (data['errores_detalle'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _whisperFailed = false;
        _whisperAnalyzed = true;
        _state = EvalState.reviewing;
      });
    } catch (e) {
      log.error('Error transcribiendo audio', e);
      if (!mounted) return;
      setState(() {
        _transcript = null;
        _palabrasLeidas = _selectedTexto?.totalPalabras ?? 0;
        _errores = 0;
        _erroresDetalle = [];
        _whisperFailed = true;
        _whisperAnalyzed = false;
        _state = EvalState.reviewing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo analizar el audio — ingrese datos manualmente',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
    // Cargar audio para reproducción
    if (_audioPath != null) {
      try {
        await _audioPlayer.setFilePath(_audioPath!);
      } catch (_) {}
    }
    _scrollToResults();
    _loadContextData();
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultsKey.currentContext;
      if (ctx == null || _rightPanelScrollController == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  Future<void> _loadContextData() async {
    if (_selectedStudent == null) return;
    setState(() => _loadingContext = true);
    try {
      final repo = StatsRepository(ApiClient());
      final results = await Future.wait([
        repo.fetchCourseStats(_selectedStudent!.curso, DateTime.now().year),
        repo.fetchStudentHistory(_selectedStudent!.id),
      ]);
      if (!mounted) return;
      setState(() {
        _courseStats = results[0] as CourseStats;
        _studentHistory = results[1] as List<StudentHistory>;
      });
    } catch (_) {
      // Los datos de contexto son opcionales; no bloquear la UX
    } finally {
      if (mounted) setState(() => _loadingContext = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    }
  }

  Future<void> _saveEvaluation() async {
    if (_selectedStudent == null) return;
    final db = ref.read(dbProvider);
    final segundos = _elapsed.inSeconds.toDouble();
    final pcpm = AssessmentCalculator.calcularPcpm(
      _palabrasLeidas,
      _errores,
      segundos,
    );
    final nivelLogro = AssessmentCalculator.clasificarNivelLogro(
      pcpm,
      _selectedStudent!.curso,
    );
    final velocidad = AssessmentCalculator.clasificarVelocidad(
      pcpm,
      _selectedStudent!.curso,
    );

    final repo = AssessmentRepository(db, ApiClient());
    await repo.saveLocal(
      studentId: _selectedStudent!.id,
      fecha: DateTime.now(),
      pcpm: pcpm,
      velocidad: velocidad,
      nivelLogro: nivelLogro,
      calidad: _calidad,
      nivelLogroCalidad: nivelLogro,
      prosodia: _prosodia,
      audioPath: _audioPath,
    );

    // Sync asíncrono: no bloquea la UX; si falla, queda pendiente offline
    repo.syncPending().catchError((_) {});

    if (!mounted) return;
    _showResult(pcpm, velocidad, nivelLogro);
  }

  void _showResult(double pcpm, String velocidad, String nivelLogro) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Evaluación guardada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('PCPM', pcpm.toStringAsFixed(1)),
            _resultRow('Velocidad', velocidad),
            _resultRow('Nivel de logro', nivelLogro),
            _resultRow('Calidad', _calidad),
            _resultRow('Prosodia', _prosodia),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _audioPlayer.stop();
              setState(() {
                _state = EvalState.idle;
                _selectedStudent = null;
                _errores = 0;
                _palabrasLeidas = 0;
                _elapsed = Duration.zero;
                _audioPath = null;
                _transcript = null;
                _erroresDetalle = [];
                _whisperFailed = false;
                _whisperAnalyzed = false;
                _courseStats = null;
                _studentHistory = [];
              });
            },
            child: const Text('Nueva evaluación'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    ),
  );

  String _stateLabel() {
    switch (_state) {
      case EvalState.idle:
        return 'Lista para evaluar';
      case EvalState.recording:
        return 'Grabando lectura';
      case EvalState.analyzing:
        return 'Analizando audio';
      case EvalState.reviewing:
        return 'Revisión manual';
    }
  }

  IconData _stateIcon() {
    switch (_state) {
      case EvalState.idle:
        return Icons.check_circle_outline_rounded;
      case EvalState.recording:
        return Icons.fiber_manual_record_rounded;
      case EvalState.analyzing:
        return Icons.auto_awesome_rounded;
      case EvalState.reviewing:
        return Icons.fact_check_outlined;
    }
  }

  Color _stateAccentColor() {
    switch (_state) {
      case EvalState.idle:
        return const Color(0xFF9FE4D1);
      case EvalState.recording:
        return const Color(0xFFFFC1BA);
      case EvalState.analyzing:
        return const Color(0xFFFFD57A);
      case EvalState.reviewing:
        return const Color(0xFFB7D8FF);
    }
  }

  Widget _buildSurfacePanel({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final panelChild = padding == null
        ? child
        : Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: panelChild,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    IconData? icon,
    required Widget child,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final isPhoneLandscape = MediaQuery.sizeOf(context).height < 450;
    final cardPadding = isPhoneLandscape ? 12.0 : 18.0;
    final headerGap = isPhoneLandscape ? 8.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFCEC7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null && !isPhoneLandscape) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
          SizedBox(height: headerGap),
          child,
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white54,
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _buildWorkflowChip({required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppTheme.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppTheme.surfaceStrong : const Color(0xFFCEC7F0),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active ? AppTheme.primary : AppTheme.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 88),
            const SizedBox(height: 20),
            Text(
              'Todo listo para comenzar',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectionPrompt(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildWorkflowChip(
                  label: '1. Curso',
                  active: _selectedCurso != null,
                ),
                _buildWorkflowChip(
                  label: '2. Estudiante',
                  active: _selectedStudent != null,
                ),
                _buildWorkflowChip(
                  label: '3. Lectura',
                  active: _selectedTexto != null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    Map<int, String> errorMap,
    TextStyle baseStyle,
  ) {
    final wordRegex = RegExp(r'[\p{L}\p{N}]+|[^\p{L}\p{N}]+', unicode: true);
    final spans = <InlineSpan>[];
    int wordIdx = 0;

    for (final match in wordRegex.allMatches(text)) {
      final segment = match.group(0)!;
      final isWord = RegExp(r'^[\p{L}\p{N}]+$', unicode: true).hasMatch(segment);
      if (isWord) {
        final tipo = errorMap[wordIdx];
        final isError = tipo == 'sustitución' || tipo == 'omisión';
        spans.add(
          TextSpan(
            text: segment,
            style: baseStyle.copyWith(
              color: isError ? const Color(0xFFB91C1C) : baseStyle.color,
              backgroundColor:
                  isError ? const Color(0xFFFEE2E2) : Colors.transparent,
            ),
          ),
        );
        wordIdx++;
      } else {
        spans.add(TextSpan(text: segment, style: baseStyle));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildReviewTextCard({
    required String label,
    required String content,
    Color? accentColor,
    int? totalWords,
    Map<int, String>? errorMap,
  }) {
    final theme = Theme.of(context);
    final baseTextStyle = AppTheme.readingTextStyle(
      theme.textTheme,
      fontSize: 18,
      height: 1.75,
      color: accentColor == null ? AppTheme.ink : AppTheme.primary,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor == null
            ? Colors.white
            : accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor == null
              ? const Color(0xFFCEC7F0)
              : accentColor.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor ?? AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (totalWords != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor == null
                        ? const Color(0xFFEDE9FE)
                        : accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalWords palabras totales',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor ?? AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (errorMap != null && errorMap.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    border: Border.all(
                      color: const Color(0xFFB91C1C),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'palabra incorrecta u omitida',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          errorMap != null
              ? _buildHighlightedText(content, errorMap, baseTextStyle)
              : Text(content, style: baseTextStyle),
        ],
      ),
    );
  }

  String _formatChoiceLabel(String value) {
    final words = value.split('_').where((word) => word.isNotEmpty);
    return words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _formatTime(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _selectionPrompt() {
    if (_selectedCurso == null) return 'Selecciona un curso';
    if (_selectedStudent == null) return 'Selecciona un estudiante';
    if (_textos.isEmpty) return 'No hay lecturas disponibles para este curso';
    return 'Selecciona una lectura\ny luego inicia la evaluación';
  }

  String _readingExcerpt(ReadingText text) {
    return text.contenido
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(2)
        .join(' ');
  }

  String _getCoverImagePath(ReadingText text) {
    var slug = text.titulo.toLowerCase();
    // Reemplazar acentos
    slug = slug
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    // Reemplazar espacios y caracteres especiales
    slug = slug.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return 'assets/reading_covers/${text.nivel}_$slug.png';
  }

  ({List<Color> colors, String badge, String scene}) _readingCoverSpec(
    ReadingText text,
  ) {
    final title = text.titulo.toLowerCase();

    if (title.contains('perro') || title.contains('pelota')) {
      return (
        colors: [const Color(0xFFFB923C), const Color(0xFFF97316)],
        badge: 'Aventura',
        scene: 'playground',
      );
    }
    if (title.contains('mochila') ||
        title.contains('cuaderno') ||
        title.contains('carta')) {
      return (
        colors: [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
        badge: 'Escuela',
        scene: 'school',
      );
    }
    if (title.contains('nubes')) {
      return (
        colors: [const Color(0xFF93C5FD), const Color(0xFF38BDF8)],
        badge: 'Imaginación',
        scene: 'sky',
      );
    }
    if (title.contains('semilla') ||
        title.contains('huerto') ||
        title.contains('quínoa')) {
      return (
        colors: [const Color(0xFF86EFAC), const Color(0xFF16A34A)],
        badge: 'Naturaleza',
        scene: 'garden',
      );
    }
    if (title.contains('feria') || title.contains('mercado')) {
      return (
        colors: [const Color(0xFFFDE68A), const Color(0xFFF59E0B)],
        badge: 'Vida cotidiana',
        scene: 'market',
      );
    }
    if (title.contains('faro') ||
        title.contains('isla') ||
        title.contains('río') ||
        title.contains('agua') ||
        title.contains('canal')) {
      return (
        colors: [const Color(0xFF67E8F9), const Color(0xFF0EA5E9)],
        badge: 'Entorno',
        scene: 'sea',
      );
    }
    if (title.contains('puente') || title.contains('cerro')) {
      return (
        colors: [const Color(0xFFA7F3D0), const Color(0xFF059669)],
        badge: 'Territorio',
        scene: 'mountains',
      );
    }
    if (title.contains('volantines') || title.contains('estrellas')) {
      return (
        colors: [const Color(0xFFC4B5FD), const Color(0xFF7C3AED)],
        badge: 'Exploración',
        scene: 'night',
      );
    }
    if (title.contains('fotógrafa') || title.contains('entrevista')) {
      return (
        colors: [const Color(0xFFF9A8D4), const Color(0xFFDB2777)],
        badge: 'Observación',
        scene: 'studio',
      );
    }
    if (title.contains('ciudad') ||
        title.contains('archivo') ||
        title.contains('energía')) {
      return (
        colors: [const Color(0xFFD8B4FE), const Color(0xFF8B5CF6)],
        badge: 'Sociedad',
        scene: 'city',
      );
    }

    switch (text.nivel) {
      case '1':
      case '2':
        return (
          colors: [const Color(0xFFFDE68A), const Color(0xFFF97316)],
          badge: 'Cuento',
          scene: 'playground',
        );
      case '3':
      case '4':
        return (
          colors: [const Color(0xFF93C5FD), const Color(0xFF2563EB)],
          badge: 'Lectura guiada',
          scene: 'mountains',
        );
      case '5':
      case '6':
        return (
          colors: [const Color(0xFFA7F3D0), const Color(0xFF059669)],
          badge: 'Texto informativo',
          scene: 'garden',
        );
      default:
        return (
          colors: [const Color(0xFFD8B4FE), const Color(0xFF7C3AED)],
          badge: 'Texto de análisis',
          scene: 'city',
        );
    }
  }

  Widget _buildCoverCloud({
    required double left,
    required double top,
    required double width,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: width,
        height: width * 0.42,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: width * 0.46,
                height: width * 0.28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
            Positioned(
              left: width * 0.18,
              top: 0,
              child: Container(
                width: width * 0.34,
                height: width * 0.26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: width * 0.02,
              child: Container(
                width: width * 0.42,
                height: width * 0.24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverStar({
    required double left,
    required double top,
    required double size,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildReadingCoverArt(
    ({List<Color> colors, String badge, String scene}) spec,
    bool isCompact, {
    bool isPhoneLandscape = false,
  }) {
    final coverHeight = isPhoneLandscape ? 100.0 : (isCompact ? 168.0 : 196.0);

    List<Widget> buildSceneWidgets() {
      switch (spec.scene) {
        case 'school':
          return [
            Positioned(
              right: 22,
              top: 20,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.amber[200],
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 18,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Positioned(
              left: 48,
              right: 48,
              bottom: 44,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 40,
              right: 40,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (_) => Container(
                    width: 10,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ];
        case 'sky':
          return [
            Positioned(
              right: 24,
              top: 20,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            _buildCoverCloud(left: 20, top: 28, width: 56),
            _buildCoverCloud(left: 108, top: 18, width: 48),
            Positioned(
              left: -16,
              right: -12,
              bottom: -10,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(44),
                ),
              ),
            ),
          ];
        case 'garden':
          return [
            Positioned(
              right: 22,
              top: 18,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -18,
              right: -18,
              bottom: -16,
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(46),
                ),
              ),
            ),
            Positioned(
              left: 34,
              bottom: 24,
              child: Container(
                width: 6,
                height: 36,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            Positioned(
              left: 22,
              bottom: 42,
              child: Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: 22,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 35,
              bottom: 46,
              child: Transform.rotate(
                angle: 0.55,
                child: Container(
                  width: 22,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 78,
              bottom: 24,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ];
        case 'market':
          return [
            Positioned(
              left: 18,
              right: 18,
              top: 24,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: List.generate(
                    6,
                    (index) => Expanded(
                      child: Container(
                        color: index.isEven
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 18,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            Positioned(
              left: 36,
              bottom: 30,
              child: Row(
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.58),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ];
        case 'sea':
          return [
            Positioned(
              right: 24,
              top: 18,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 30,
              child: Container(
                width: 18,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 70,
              child: Container(
                width: 26,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Positioned(
              left: -20,
              right: -20,
              bottom: 18,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: -10,
              right: -10,
              bottom: -2,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ];
        case 'mountains':
          return [
            Positioned(
              left: 8,
              right: 8,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(80),
                          topRight: Radius.circular(80),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(90),
                          topRight: Radius.circular(90),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(70),
                          topRight: Radius.circular(70),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        case 'night':
          return [
            Positioned(
              right: 28,
              top: 18,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            _buildCoverStar(left: 26, top: 24, size: 16),
            _buildCoverStar(left: 92, top: 38, size: 12),
            _buildCoverStar(left: 142, top: 20, size: 14),
            Positioned(
              left: 42,
              bottom: 22,
              child: Container(
                width: 60,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(40),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 70,
              bottom: 54,
              child: Container(
                width: 16,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ];
        case 'studio':
          return [
            Positioned(
              left: 26,
              top: 24,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 42,
              top: 40,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                    width: 4,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ];
        case 'city':
          return [
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final height in [46.0, 66.0, 54.0, 74.0, 42.0]) ...[
                    Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ];
        default:
          return [
            Positioned(
              left: 0,
              right: 0,
              bottom: -8,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(44),
                ),
              ),
            ),
          ];
      }
    }

    return SizedBox(
      height: coverHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(color: spec.colors.first),
        child: Stack(
          children: [
            Positioned(
              top: -18,
              right: -10,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -22,
              left: -8,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            ...buildSceneWidgets(),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  spec.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(ReadingText text, bool isCompact, {bool isPhoneLandscape = false}) {
    final coverHeight = isPhoneLandscape ? 100.0 : (isCompact ? 168.0 : 196.0);
    final imagePath = _getCoverImagePath(text);
    final spec = _readingCoverSpec(text);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheH = (coverHeight * dpr).round();

    return SizedBox(
      height: coverHeight,
      width: double.infinity,
      child: ColoredBox(
        color: spec.colors.first.withValues(alpha: 0.18),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: coverHeight,
          cacheHeight: cacheH,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _buildReadingCoverArt(spec, isCompact, isPhoneLandscape: isPhoneLandscape);
          },
        ),
      ),
    );
  }

  Widget _buildAnalyzingPanel() {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _buildSectionCard(
          title: 'Analizando lectura',
          subtitle:
              'Estamos procesando la grabación y estimando palabras leídas, errores y transcripción.',
          icon: Icons.auto_awesome_rounded,
          backgroundColor: AppTheme.surfaceAlt,
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceStrong,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Transcribiendo audio de ${_formatTime(_elapsed)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes continuar en cuanto termine el análisis.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewPanel(bool isCompact, double textFontSize) {
    final theme = Theme.of(context);
    final Map<int, String> errorMap = {
      for (final e in _erroresDetalle)
        if (e['indice'] != null) (e['indice'] as int): (e['tipo'] as String),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de estado (fijo, no scrollea)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _whisperFailed
                ? const Color(0xFFFFF5E8)
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _whisperFailed
                  ? const Color(0xFFF8D5A1)
                  : AppTheme.surfaceStrong,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _whisperFailed
                      ? const Color(0xFFFFE1B3)
                      : AppTheme.surfaceStrong,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _whisperFailed
                      ? Icons.warning_amber_rounded
                      : Icons.auto_awesome_rounded,
                  size: 20,
                  color: _whisperFailed
                      ? const Color(0xFFB54708)
                      : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _whisperFailed
                      ? 'Análisis no disponible. Ajusta los datos manualmente antes de guardar.'
                      : 'La IA preparó una transcripción preliminar. Revísala y corrige si hace falta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _whisperFailed
                        ? const Color(0xFF93370D)
                        : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Contenido scrolleable unificado
        Expanded(
          child: SingleChildScrollView(
            controller: _rightPanelScrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Textos: original + transcripción
                if (_transcript != null && !isCompact)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildReviewTextCard(
                          label: 'Texto original',
                          content: _selectedTexto?.contenido ?? '',
                          totalWords: _selectedTexto?.totalPalabras,
                          errorMap: errorMap.isNotEmpty ? errorMap : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildReviewTextCard(
                          label: 'Lo que escuchó la IA',
                          content: _transcript!,
                          accentColor: AppTheme.secondary,
                        ),
                      ),
                    ],
                  )
                else ...[
                  if (_transcript != null) ...[
                    _buildReviewTextCard(
                      label: 'Lo que escuchó la IA',
                      content: _transcript!,
                      accentColor: AppTheme.secondary,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildReviewTextCard(
                    label: 'Texto original',
                    content: _selectedTexto?.contenido ?? '',
                    totalWords: _selectedTexto?.totalPalabras,
                    errorMap: errorMap.isNotEmpty ? errorMap : null,
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                _buildResultsCard(theme),
                const SizedBox(height: 16),
                _buildDistributionChart(theme),
                const SizedBox(height: 16),
                _buildProgressionChart(theme),
                const SizedBox(height: 16),
                _buildSuggestions(theme),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCard(ThemeData theme) {
    if (_selectedStudent == null) return const SizedBox.shrink();
    final segundos = _elapsed.inSeconds.toDouble();
    final pcpm = AssessmentCalculator.calcularPcpm(
      _palabrasLeidas,
      _errores,
      segundos,
    );
    final velocidad = AssessmentCalculator.clasificarVelocidad(
      pcpm,
      _selectedStudent!.curso,
    );
    final nivelLogro = AssessmentCalculator.clasificarNivelLogro(
      pcpm,
      _selectedStudent!.curso,
    );

    return Container(
      key: _resultsKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultado actual',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _resultRow('PCPM', pcpm.toStringAsFixed(1)),
          _resultRow('Velocidad', velocidad),
          _resultRow('Nivel de logro', nivelLogro),
          _resultRow('Calidad', _calidad),
          _resultRow('Prosodia', _prosodia),
        ],
      ),
    );
  }

  Widget _buildDistributionChart(ThemeData theme) {
    const categories = [
      'Muy Lenta',
      'Lenta',
      'Medio Baja',
      'Medio Alta',
      'Rápida',
      'Muy Rápida',
    ];
    const shortLabels = ['M.Lenta', 'Lenta', 'M.Baja', 'M.Alta', 'Rápida', 'M.Rápida'];

    String? currentCat;
    if (_selectedStudent != null) {
      final segundos = _elapsed.inSeconds.toDouble();
      final pcpm = AssessmentCalculator.calcularPcpm(
        _palabrasLeidas,
        _errores,
        segundos,
      );
      currentCat = AssessmentCalculator.clasificarVelocidad(
        pcpm,
        _selectedStudent!.curso,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Distribución del curso',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_loadingContext) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            ],
          ),
          if (_courseStats == null && !_loadingContext)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Sin datos del servidor',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
              ),
            )
          else if (_courseStats != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  barGroups: categories.asMap().entries.map((e) {
                    final isCurrent = e.value == currentCat;
                    final count = (_courseStats!.distribucionVelocidad[e.value] ?? 0).toDouble();
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          color: isCurrent ? AppTheme.primary : AppTheme.surfaceStrong,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= shortLabels.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              shortLabels[idx],
                              style: const TextStyle(fontSize: 8),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressionChart(ThemeData theme) {
    if (_selectedStudent == null) return const SizedBox.shrink();

    final segundos = _elapsed.inSeconds.toDouble();
    final currentPcpm = AssessmentCalculator.calcularPcpm(
      _palabrasLeidas,
      _errores,
      segundos,
    );

    final historyAsc = [..._studentHistory]
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final allPcpm = [...historyAsc.map((h) => h.pcpm), currentPcpm];
    final spots = allPcpm
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Progresión del alumno',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_loadingContext) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (historyAsc.isEmpty)
            Text(
              'Primera evaluación registrada — PCPM: ${currentPcpm.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            )
          else
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primary,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, idx) {
                          final isCurrent = idx == spots.length - 1;
                          return FlDotCirclePainter(
                            radius: isCurrent ? 6 : 4,
                            color: isCurrent
                                ? AppTheme.secondary
                                : AppTheme.primary,
                            strokeWidth: 0,
                            strokeColor: Colors.transparent,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  extraLinesData: _courseStats != null
                      ? ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: _courseStats!.promedioPcpm,
                              color: Colors.orange.withValues(alpha: 0.6),
                              strokeWidth: 1,
                              dashArray: [4, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                ),
                                labelResolver: (line) =>
                                    'Prom. ${line.y.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        )
                      : ExtraLinesData(),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    if (_selectedStudent == null) return const SizedBox.shrink();

    final segundos = _elapsed.inSeconds.toDouble();
    final pcpm = AssessmentCalculator.calcularPcpm(
      _palabrasLeidas,
      _errores,
      segundos,
    );
    final nivelLogro = AssessmentCalculator.clasificarNivelLogro(
      pcpm,
      _selectedStudent!.curso,
    );

    final suggestions = <String>[];
    if (nivelLogro == 'Muy Bajo lo Esperado') {
      suggestions.add(
        'Practicar lectura oral diaria con textos de nivel inferior al del curso.',
      );
      suggestions.add(
        'Usar la técnica de lectura repetida del mismo texto hasta alcanzar fluidez básica.',
      );
    } else if (nivelLogro == 'Bajo lo Esperado') {
      suggestions.add(
        'Incrementar tiempo de lectura oral con textos adecuados al nivel del curso.',
      );
    }
    if (_calidad == 'silabeando' || _calidad == 'unidades_cortas') {
      suggestions.add(
        'Trabajar reconocimiento de palabras completas para reducir la silabación.',
      );
    }
    if (_prosodia == 'inadecuada' || _prosodia == 'básica') {
      suggestions.add(
        'Modelar lectura expresiva con textos que tengan diálogos o poemas.',
      );
    }
    if (suggestions.isEmpty) {
      suggestions.add(
        'Mantener la práctica lectora para consolidar el nivel alcanzado.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sugerencias',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.take(4).map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(bool isCompact) {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F9FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCEDEF)),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: _togglePlayback,
                icon: Icon(
                  playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: isCompact ? 28 : 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceStrong,
                  foregroundColor: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escuchar grabación',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<Duration>(
                      stream: _audioPlayer.positionStream,
                      builder: (ctx, snap) {
                        final pos = snap.data ?? Duration.zero;
                        return Text(
                          '${_formatTime(pos)} / ${_formatTime(_elapsed)}',
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.muted,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 14,
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      playing ? 'Reproduciendo' : 'Pausado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadingCard(
    BuildContext context,
    ReadingText text,
    bool isCompact, {
    bool isPhoneLandscape = false,
  }) {
    final cardPadding = isPhoneLandscape
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.fromLTRB(18, 18, 18, 16);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFCEC7F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x207C3AED),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _state == EvalState.idle
              ? () {
                  setState(() => _selectedTexto = text);
                  _scrollToTimer();
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: _buildCoverImage(text, isCompact, isPhoneLandscape: isPhoneLandscape),
              ),
              Expanded(
                child: Padding(
                  padding: cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isPhoneLandscape) ...[
                        const SizedBox(height: 8),
                        Text(
                          _readingExcerpt(text),
                          maxLines: isCompact ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_stories_rounded,
                                  size: 15,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${text.totalPalabras} palabras',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Abrir',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.secondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingGallery(BuildContext context, bool isCompact, {bool isPhoneLandscape = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final spacing = isPhoneLandscape ? 8.0 : (isCompact ? 12.0 : 16.0);
        final columns = width >= 980
            ? 3
            : width >= 520
            ? 2
            : 1;
        final cardWidth = (width - (spacing * (columns - 1))) / columns;
        final cardHeight = isPhoneLandscape ? 200.0 : (isCompact ? 322.0 : 352.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              title: 'Lecturas disponibles',
              subtitle:
                  'Selecciona una lectura para ${_selectedStudent!.nombreCompleto}. Cada tarjeta incluye una portada visual del texto.',
              icon: Icons.menu_book_rounded,
              backgroundColor: AppTheme.surface,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFCEC7F0)),
                    ),
                    child: Text(
                      '${_textos.length} lecturas',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isPhoneLandscape)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFCEC7F0)),
                      ),
                      child: Text(
                        'Toca una tarjeta para abrir la lectura',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _textos
                      .map(
                        (text) => SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _buildReadingCard(context, text, isCompact, isPhoneLandscape: isPhoneLandscape),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isPhoneLandscape = screenHeight < 450;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isPhoneLandscape ? 52.0 : 86.0,
        titleSpacing: isPhoneLandscape ? 12 : 18,
        flexibleSpace: Container(color: AppTheme.headerBackground),
        title: GestureDetector(
          onTap: _onTitleTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(
                size: isPhoneLandscape ? 30.0 : 42.0,
                heroTag: 'prosodia-logo',
                showShadow: false,
              ),
              SizedBox(width: isPhoneLandscape ? 8 : 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ProsodIA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!isPhoneLandscape)
                    Text(
                      'Evaluación de fluidez lectora',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: isPhoneLandscape ? 8 : 12,
                vertical: isPhoneLandscape ? 6 : 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_stateIcon(), size: 14, color: _stateAccentColor()),
                  const SizedBox(width: 6),
                  Text(
                    _stateLabel(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isPhoneLandscape)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: AppVersionText(
                    prefix: '',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          if (_checkingUpdate)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            _buildHeaderActionButton(
              icon: Icons.system_update_outlined,
              tooltip: 'Buscar actualización',
              onPressed: _state == EvalState.idle ? _checkForUpdate : null,
            ),
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            _buildHeaderActionButton(
              icon: Icons.sync,
              tooltip: 'Sincronizar estudiantes',
              onPressed: _state == EvalState.idle ? _syncAndLoad : null,
            ),
          _buildHeaderActionButton(
            icon: Icons.logout,
            tooltip: 'Cerrar sesión',
            onPressed: _state == EvalState.idle ? _logout : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ColoredBox(
        color: AppTheme.appBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final isCompact = w < 700;
            final isPhoneLandscape = h < 450;
            final leftPanelWidth = isPhoneLandscape ? 260.0 : (isCompact ? w * 0.38 : 352.0);
            final leftPanelPadding = isPhoneLandscape ? 10.0 : (isCompact ? 14.0 : 18.0);
            final textFontSize = isPhoneLandscape ? 16.0 : (isCompact ? 18.0 : 25.0);
            final textPanelPadding = isPhoneLandscape ? 10.0 : (isCompact ? 16.0 : 26.0);
            final mediumGap = isPhoneLandscape ? 6.0 : (isCompact ? 10.0 : 16.0);
            final largeGap = isPhoneLandscape ? 8.0 : (isCompact ? 14.0 : 22.0);
            final timerStyle = isPhoneLandscape
                ? theme.textTheme.titleLarge
                : isCompact
                ? theme.textTheme.headlineMedium
                : theme.textTheme.displaySmall;
            final recordButtonHeight = isPhoneLandscape ? 40.0 : (isCompact ? 48.0 : 56.0);
            final recordButtonTextSize = isPhoneLandscape ? 13.0 : (isCompact ? 14.0 : 16.0);
            final recordButtonIconSize = isPhoneLandscape ? 18.0 : (isCompact ? 22.0 : 26.0);

            final leftPanelContent = SingleChildScrollView(
              controller: _leftPanelScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(isPhoneLandscape ? 12.0 : 18.0),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFCEC7F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: isPhoneLandscape ? 32.0 : 40.0,
                              height: isPhoneLandscape ? 32.0 : 40.0,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDDD6FE),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.track_changes_rounded,
                                size: isPhoneLandscape ? 18.0 : 24.0,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Flujo de evaluación',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  if (!isPhoneLandscape) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Mantén el orden recomendado para una sesión rápida y consistente.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isPhoneLandscape ? 8.0 : 16.0),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildWorkflowChip(
                              label: '1. Curso',
                              active: _selectedCurso != null,
                            ),
                            _buildWorkflowChip(
                              label: '2. Estudiante',
                              active: _selectedStudent != null,
                            ),
                            _buildWorkflowChip(
                              label: '3. Lectura',
                              active: _selectedTexto != null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mediumGap),
                  _buildSectionCard(
                    title: 'Preparación',
                    subtitle:
                        'Selecciona curso y estudiante antes de elegir la lectura.',
                    icon: Icons.how_to_reg_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Curso', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedCurso,
                          decoration: const InputDecoration(
                            hintText: 'Seleccionar curso',
                          ),
                          items: _cursos
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: _state == EvalState.idle
                              ? _onCursoChanged
                              : null,
                        ),
                        SizedBox(height: mediumGap),
                        Text('Estudiante', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Student>(
                          value: _selectedStudent,
                          decoration: const InputDecoration(
                            hintText: 'Seleccionar estudiante',
                          ),
                          items: _studentsInCurso
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.nombreCompleto,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged:
                              _state == EvalState.idle && _selectedCurso != null
                              ? _onStudentChanged
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (_selectedTexto != null) ...[
                    SizedBox(height: mediumGap),
                    _buildSectionCard(
                      title: 'Lectura seleccionada',
                      subtitle:
                          'Este texto queda activo para la evaluación actual.',
                      icon: Icons.menu_book_rounded,
                      backgroundColor: AppTheme.surface,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFCEC7F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedTexto!.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceAlt,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${_selectedTexto!.totalPalabras} palabras',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Curso ${_selectedCurso ?? ''}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: largeGap),
                  SizedBox(
                    key: _timerSectionKey,
                    child: _buildSectionCard(
                      title: 'Cronómetro',
                      subtitle: 'Controla la duración total de la lectura.',
                      icon: _state == EvalState.recording
                          ? Icons.fiber_manual_record_rounded
                          : Icons.timer_outlined,
                      backgroundColor: _state == EvalState.recording
                          ? const Color(0xFFFFF4F3)
                          : AppTheme.surface,
                      child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _state == EvalState.recording
                              ? const Color(0xFFFFD5D0)
                              : const Color(0xFFCEC7F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _state == EvalState.recording
                                  ? const Color(0xFFFFE1DD)
                                  : AppTheme.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _state == EvalState.recording
                                  ? Icons.fiber_manual_record_rounded
                                  : Icons.timer_outlined,
                              color: _state == EvalState.recording
                                  ? const Color(0xFFEF4444)
                                  : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatTime(_elapsed),
                            style: timerStyle?.copyWith(
                              color: _state == EvalState.recording
                                  ? const Color(0xFFEF4444)
                                  : AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                  SizedBox(height: mediumGap),
                  if (_state == EvalState.analyzing)
                    _buildSectionCard(
                      title: 'Procesando audio',
                      subtitle:
                          'Espera unos segundos mientras se completa el análisis.',
                      icon: Icons.auto_awesome_rounded,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Analizando lectura...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_state != EvalState.reviewing)
                    SizedBox(
                      height: recordButtonHeight,
                      child: _state == EvalState.idle
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.tertiary,
                              ),
                              icon: Icon(
                                Icons.mic_rounded,
                                size: recordButtonIconSize,
                              ),
                              label: Text(
                                'Iniciar evaluación',
                                style: TextStyle(
                                  fontSize: recordButtonTextSize,
                                ),
                              ),
                              onPressed:
                                  _selectedStudent == null ||
                                      _selectedTexto == null
                                  ? null
                                  : _startRecording,
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                              icon: Icon(
                                Icons.stop_rounded,
                                size: recordButtonIconSize,
                              ),
                              label: Text(
                                'Detener lectura',
                                style: TextStyle(
                                  fontSize: recordButtonTextSize,
                                ),
                              ),
                              onPressed: _stopRecording,
                            ),
                    ),
                  if (_state == EvalState.reviewing) ...[
                    SizedBox(height: largeGap),
                    _buildSectionCard(
                      title: 'Revisión manual',
                      subtitle:
                          'Ajusta los datos y guarda la evaluación final.',
                      icon: Icons.fact_check_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAudioPlayer(isCompact),
                          SizedBox(height: mediumGap),
                          // IA source badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _whisperAnalyzed
                                  ? const Color(0xFFEDE9FE)
                                  : const Color(0xFFFFF5E8),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _whisperAnalyzed
                                    ? const Color(0xFFCEC7F0)
                                    : const Color(0xFFFBD0A8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _whisperAnalyzed
                                      ? Icons.auto_awesome_rounded
                                      : Icons.edit_note_rounded,
                                  size: 14,
                                  color: _whisperAnalyzed
                                      ? AppTheme.primary
                                      : const Color(0xFFB54708),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _whisperAnalyzed
                                      ? 'Valores detectados por la IA — puedes corregirlos'
                                      : 'Sin análisis IA — ingresa los valores manualmente',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _whisperAnalyzed
                                        ? AppTheme.primary
                                        : const Color(0xFF93370D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: mediumGap),
                          Row(
                            children: [
                              Text(
                                'Palabras leídas',
                                style: theme.textTheme.titleSmall,
                              ),
                              if (_selectedTexto != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'de ${_selectedTexto!.totalPalabras} totales',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          _counterRow(
                            value: _palabrasLeidas,
                            onDec: () => setState(() {
                              if (_palabrasLeidas > 0) _palabrasLeidas--;
                            }),
                            onInc: () => setState(() => _palabrasLeidas++),
                          ),
                          const SizedBox(height: 14),
                          Text('Errores', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          _counterRow(
                            value: _errores,
                            onDec: () => setState(() {
                              if (_errores > 0) _errores--;
                            }),
                            onInc: () => setState(() => _errores++),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.surfaceStrong),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PCPM calculado',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  AssessmentCalculator.calcularPcpm(
                                    _palabrasLeidas,
                                    _errores,
                                    _elapsed.inSeconds.toDouble(),
                                  ).toStringAsFixed(1),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: mediumGap),
                          Text(
                            'Calidad de lectura',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _chipSelector(
                            options: const [
                              'silábica',
                              'palabra_a_palabra',
                              'unidades_cortas',
                              'fluida',
                            ],
                            selected: _calidad,
                            onSelected: (v) => setState(() => _calidad = v),
                          ),
                          const SizedBox(height: 14),
                          Text('Prosodia', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 8),
                          _chipSelector(
                            options: const [
                              'inadecuada',
                              'básica',
                              'adecuada',
                              'expresiva',
                            ],
                            selected: _prosodia,
                            onSelected: (v) => setState(() => _prosodia = v),
                          ),
                          SizedBox(height: mediumGap),
                          FilledButton.icon(
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar evaluación'),
                            onPressed: _saveEvaluation,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Cancelar y regrabar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFFFCDD2)),
                            ),
                            onPressed: () {
                              _audioPlayer.stop();
                              setState(() {
                                _state = EvalState.idle;
                                _errores = 0;
                                _palabrasLeidas = 0;
                                _elapsed = Duration.zero;
                                _audioPath = null;
                                _transcript = null;
                                _erroresDetalle = [];
                                _whisperFailed = false;
                                _whisperAnalyzed = false;
                                _courseStats = null;
                                _studentHistory = [];
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );

            return Padding(
              padding: EdgeInsets.all(isPhoneLandscape ? 8.0 : 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftPanelWidth,
                    child: _buildSurfacePanel(
                      padding: EdgeInsets.all(leftPanelPadding),
                      child: leftPanelContent,
                    ),
                  ),
                  SizedBox(width: isPhoneLandscape ? 8.0 : 12.0),
                  Expanded(
                    child: _buildSurfacePanel(
                      padding: EdgeInsets.all(textPanelPadding),
                      child: _state == EvalState.analyzing
                          ? _buildAnalyzingPanel()
                          : _state == EvalState.reviewing
                          ? _buildReviewPanel(isCompact, textFontSize)
                          : _selectedTexto != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isPhoneLandscape ? 12.0 : 18.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F8FC),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: const Color(0xFFE1EAF2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedTexto!.titulo,
                                              style: (isPhoneLandscape
                                                      ? theme.textTheme.titleLarge
                                                      : theme.textTheme.headlineSmall)
                                                  ?.copyWith(
                                                    color: AppTheme.primary,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${_selectedTexto!.totalPalabras} palabras',
                                                    style: theme
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color:
                                                              AppTheme.primary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                                if (_selectedStudent != null)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      _selectedStudent!
                                                          .nombreCompleto,
                                                      style: theme
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                AppTheme.muted,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      OutlinedButton.icon(
                                        onPressed: _state == EvalState.idle
                                            ? () => setState(
                                                () => _selectedTexto = null,
                                              )
                                            : null,
                                        icon: const Icon(
                                          Icons.grid_view_rounded,
                                        ),
                                        label: const Text('Cambiar lectura'),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isPhoneLandscape ? 8.0 : 18.0),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      isPhoneLandscape ? 14 : (isCompact ? 18 : 28),
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: AppTheme.surfaceStrong,
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        _selectedTexto!.contenido,
                                        style: AppTheme.readingTextStyle(
                                          theme.textTheme,
                                          fontSize: textFontSize,
                                          height: isCompact ? 1.8 : 2.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _selectedStudent != null && _textos.isNotEmpty
                          ? _buildReadingGallery(context, isCompact, isPhoneLandscape: isPhoneLandscape)
                          : _buildEmptyState(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _counterRow({
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onDec,
          icon: const Icon(Icons.remove_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFCE7F3),
            foregroundColor: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCEC7F0)),
            ),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: onInc,
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceAlt,
            foregroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _chipSelector({
    required List<String> options,
    required String selected,
    required void Function(String) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => ChoiceChip(
              label: Text(
                _formatChoiceLabel(o),
                style: const TextStyle(fontSize: 11),
              ),
              selected: selected == o,
              onSelected: (_) => onSelected(o),
            ),
          )
          .toList(),
    );
  }
}
