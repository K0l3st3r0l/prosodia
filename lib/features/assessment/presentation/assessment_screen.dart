import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/responsive/orientation_lock.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/students/data/student_repository.dart';
import '../../../features/debug/log_screen.dart';
import '../data/assessment_repository.dart';
import '../data/stats_repository.dart';
import '../../../features/ota_update/ota_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../logic/assessment_calculator.dart';
import 'eval_state.dart';
import 'widgets/assessment_app_bar.dart';
import 'widgets/assessment_layout.dart';
import 'widgets/assessment_placeholders.dart';
import 'widgets/context_charts.dart';
import 'widgets/control_panel.dart';
import 'widgets/manual_review_form.dart';
import 'widgets/reading_mode_bar.dart';
import 'widgets/reading_gallery.dart';
import 'widgets/reading_view.dart';
import 'widgets/review_panel.dart';

export 'eval_state.dart';

final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key, this.trial = false});

  /// Modo prueba: sin sesión iniciada, sin alumno y **sin guardar nada**.
  ///
  /// Sirve para mostrar o practicar la app sin tocar los datos reales. Los
  /// cursos salen de los niveles con lecturas sembradas y no de los alumnos
  /// sincronizados, porque acá no hay credenciales con las que sincronizar.
  ///
  /// Nada se persiste ni se sincroniza: `AssessmentSessions.studentId` es una
  /// FK obligatoria y el endpoint de anahuac rechaza un POST sin `student_id`.
  /// Guardar exigiría cambios de esquema en los dos lados, y una evaluación de
  /// práctica no tiene por qué entrar a la serie longitudinal de UTP.
  final bool trial;

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

  // Condiciones de render de la lectura, para trazabilidad de la métrica.
  // Se remide en cada rebuild de `ReadingView` (ver `onReadingCplMeasured`) y
  // se usa el último valor capturado al guardar: para entonces la pantalla ya
  // cambió a `analyzing`/`reviewing` y `ReadingView` no está montado.
  double? _readingCpl;

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
    // Salir de la evaluación devuelve la orientación a la regla por clase de
    // dispositivo; si no, un teléfono quedaría trabado en landscape.
    applyDefaultOrientations();
    _timer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _leftPanelScrollController?.dispose();
    _rightPanelScrollController?.dispose();
    super.dispose();
  }

  /// Curso con el que se clasifica el resultado.
  ///
  /// En el flujo normal es el del alumno; en modo prueba no hay alumno, pero
  /// `AssessmentCalculator` clasifica por curso, así que basta el seleccionado.
  String get _cursoParaClasificar =>
      _selectedStudent?.curso ?? _selectedCurso ?? '';

  Future<void> _syncAndLoad() async {
    final db = ref.read(dbProvider);

    if (widget.trial) {
      // Sin sesión no hay estudiantes que traer ni evaluaciones que subir. Los
      // "cursos" son los niveles que tienen lecturas sembradas localmente.
      final niveles = await db.getNivelesConLecturas();
      if (!mounted) return;
      setState(() => _cursos = niveles.map((n) => '$n° básico').toList());
      return;
    }

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
    // En modo prueba el "curso" es un nivel ("3° básico") y no hay alumnos que
    // buscar; el regex de nivel funciona igual para ambas formas.
    final students = widget.trial
        ? <Student>[]
        : await db.getStudentsByCurso(curso);
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
      _setSelectedTexto(null);
    });
  }

  void _onStudentChanged(Student? student) {
    setState(() {
      _selectedStudent = student;
      _setSelectedTexto(null);
      _courseStats = null;
      _studentHistory = [];
    });
  }

  /// Único punto de mutación de [_selectedTexto].
  ///
  /// La orientación va atada a la presencia del texto en pantalla: mientras el
  /// niño tiene la lectura al frente, la app se fuerza a landscape aunque sea
  /// un teléfono. Ver [lockLandscapeForReading] para el porqué. Centralizarlo
  /// evita que un sitio de asignación nuevo se olvide de la orientación.
  void _setSelectedTexto(ReadingText? texto) {
    final hadReading = _selectedTexto != null;
    _selectedTexto = texto;
    if ((texto != null) == hadReading) return;
    if (texto != null) {
      lockLandscapeForReading();
    } else {
      applyDefaultOrientations();
    }
  }

  void _scrollToTimer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _timerSectionKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
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

  /// Salida del modo prueba: vuelve a la pantalla de inicio.
  ///
  /// No hay sesión que cerrar ni nada que guardar, así que basta con soltar la
  /// ruta. Se confirma igual porque una evaluación a medias se pierde entera.
  Future<void> _exitTrial() async {
    final haySesionEmpezada =
        _selectedTexto != null || _state != EvalState.idle;

    if (haySesionEmpezada) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Salir de la prueba'),
          content: const Text(
            'La prueba no guarda resultados, así que lo que hiciste se pierde. '
            '¿Quieres salir igual?',
          ),
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
      if (confirm != true) return;
    }

    if (mounted) Navigator.of(context).pop();
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
      if (ctx == null) return;
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
    final db = ref.read(dbProvider);
    final segundos = _elapsed.inSeconds.toDouble();
    final pcpm = AssessmentCalculator.calcularPcpm(
      _palabrasLeidas,
      _errores,
      segundos,
    );
    final nivelLogro = AssessmentCalculator.clasificarNivelLogro(
      pcpm,
      _cursoParaClasificar,
    );
    final velocidad = AssessmentCalculator.clasificarVelocidad(
      pcpm,
      _cursoParaClasificar,
    );

    // El resultado se muestra igual —para eso es la prueba— pero no se persiste
    // ni se sincroniza. Ver `AssessmentScreen.trial`.
    if (widget.trial || _selectedStudent == null) {
      _showResult(pcpm, velocidad, nivelLogro);
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final appBuild = int.tryParse(packageInfo.buildNumber) ?? kAppBuild;

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
      appBuild: appBuild,
      readingCpl: _readingCpl,
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
        // `AlertDialog` no hace scroll de su contenido: con el texto del
        // sistema escalado, cinco filas de resultado no caben en la altura
        // máxima del diálogo en un teléfono.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResultRow(label: 'PCPM', value: pcpm.toStringAsFixed(1)),
              ResultRow(label: 'Velocidad', value: velocidad),
              ResultRow(label: 'Nivel de logro', value: nivelLogro),
              ResultRow(label: 'Calidad', value: _calidad),
              ResultRow(label: 'Prosodia', value: _prosodia),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _audioPlayer.stop();
              setState(_resetSession);
            },
            child: const Text('Nueva evaluación'),
          ),
        ],
      ),
    );
  }

  /// Deja la sesión lista para la siguiente evaluación.
  void _resetSession({bool clearStudent = true}) {
    _state = EvalState.idle;
    if (clearStudent) _selectedStudent = null;
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
    _readingCpl = null;
  }

  String _selectionPrompt() {
    if (_selectedCurso == null) return 'Selecciona un curso';
    if (!widget.trial && _selectedStudent == null) {
      return 'Selecciona un estudiante';
    }
    if (_textos.isEmpty) return 'No hay lecturas disponibles para este curso';
    return 'Selecciona una lectura\ny luego inicia la evaluación';
  }

  double get _currentPcpm => AssessmentCalculator.calcularPcpm(
    _palabrasLeidas,
    _errores,
    _elapsed.inSeconds.toDouble(),
  );

  @override
  Widget build(BuildContext context) {
    // El `AppBar` decide su altura desde `preferredSize`, un getter sin
    // contexto, así que la clase de viewport se resuelve aquí.
    final size = MediaQuery.sizeOf(context);
    final compactBar = size.height < kShortViewportHeight;

    // Modo foco: teléfono con una lectura abierta. Se decide acá y no dentro del
    // `ResponsiveScope` porque cambia cuál barra recibe el `Scaffold`, y esa
    // decisión tiene que estar tomada antes de que se lea `preferredSize`.
    final focusMode =
        AppBreakpoint.fromShortestSide(size.shortestSide).isPhone &&
        _selectedTexto != null;

    return ResponsiveScope(
      builder: (context, screen) => Scaffold(
        appBar: focusMode
            ? ReadingModeBar(
                height: compactBar
                    ? ReadingModeBar.compactHeight
                    : ReadingModeBar.regularHeight,
                elapsed: _elapsed,
                state: _state,
                onStart: _startRecording,
                onStop: _stopRecording,
                // Conserva alumno y lectura: repetir es volver a medir al mismo
                // niño con el mismo texto, no empezar de cero.
                onRepeat: () => setState(
                  () => _resetSession(clearStudent: false),
                ),
                onChangeReading: _state == EvalState.idle
                    ? () => setState(() => _setSelectedTexto(null))
                    : null,
              )
            : AssessmentAppBar(
                compact: compactBar,
                trial: widget.trial,
                state: _state,
                syncing: _syncing,
                checkingUpdate: _checkingUpdate,
                onTitleTap: _onTitleTap,
                onCheckUpdate: _checkForUpdate,
                onSync: _syncAndLoad,
                onLogout: widget.trial ? _exitTrial : _logout,
              ),
        body: ColoredBox(
          color: focusMode ? AppTheme.surface : AppTheme.appBackground,
          // En landscape —la orientación de producción— el recorte de pantalla
          // y la barra de gestos quedan en los bordes laterales, justo donde
          // vive el panel de control.
          child: SafeArea(
            top: false,
            child: ResponsiveScope(
              builder: (context, r) => focusMode
                  ? _buildFocusBody(r)
                  : AssessmentLayout(
                      workAreaFirst:
                          _selectedTexto != null || _state != EvalState.idle,
                      controlPanel: _buildControlPanel(r),
                      workArea: _buildWorkArea(r),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Cuerpo del modo foco.
  ///
  /// Mientras el niño lee, solo el texto. Al terminar aparecen abajo los
  /// resultados y la revisión manual, sin devolver la barra con logo y botones:
  /// esos controles siguen sin servir para nada en ese momento y le quitarían
  /// alto a las palabras resaltadas, que es lo que el docente está mirando.
  Widget _buildFocusBody(Responsive r) {
    if (_state == EvalState.reviewing) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(r.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWorkArea(r),
            SizedBox(height: r.spacing.xl),
            _buildManualReview(),
          ],
        ),
      );
    }

    if (_state == EvalState.analyzing) return _buildWorkArea(r);

    final texto = _selectedTexto;
    if (texto == null) return _buildWorkArea(r);

    return SingleChildScrollView(
      child: ReadingView(
        text: texto,
        cursoLabel: _selectedCurso ?? '',
        studentName: _selectedStudent?.nombreCompleto,
        onChangeReading: null,
        fillHeight: false,
        focus: true,
        onReadingCplMeasured: (v) => _readingCpl = v,
      ),
    );
  }

  Widget _buildControlPanel(Responsive r) {
    final idle = _state == EvalState.idle;

    return AssessmentControlPanel(
      trial: widget.trial,
      state: _state,
      cursos: _cursos,
      selectedCurso: _selectedCurso,
      onCursoChanged: idle ? _onCursoChanged : null,
      studentsInCurso: _studentsInCurso,
      selectedStudent: _selectedStudent,
      onStudentChanged: idle && _selectedCurso != null
          ? _onStudentChanged
          : null,
      selectedTexto: _selectedTexto,
      elapsed: _elapsed,
      timerKey: _timerSectionKey,
      onStartRecording: _startRecording,
      onStopRecording: _stopRecording,
      manualReview: _state == EvalState.reviewing ? _buildManualReview() : null,
      scrollController: _leftPanelScrollController,
      scrollable: r.paneStrategy.isDual,
    );
  }

  Widget _buildManualReview() {
    return ManualReviewForm(
      whisperAnalyzed: _whisperAnalyzed,
      palabrasLeidas: _palabrasLeidas,
      errores: _errores,
      totalPalabras: _selectedTexto?.totalPalabras,
      pcpm: _currentPcpm,
      calidad: _calidad,
      prosodia: _prosodia,
      audioPlayer: _buildAudioPlayerBar(),
      onPalabrasChanged: (v) => setState(() => _palabrasLeidas = v),
      onErroresChanged: (v) => setState(() => _errores = v),
      onCalidadChanged: (v) => setState(() => _calidad = v),
      onProsodiaChanged: (v) => setState(() => _prosodia = v),
      onSave: _saveEvaluation,
      onDiscard: () {
        _audioPlayer.stop();
        setState(() => _resetSession(clearStudent: false));
      },
    );
  }

  Widget _buildAudioPlayerBar() {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, playerSnapshot) {
        return StreamBuilder<Duration>(
          stream: _audioPlayer.positionStream,
          builder: (context, positionSnapshot) {
            return AudioPlayerBar(
              playing: playerSnapshot.data?.playing ?? false,
              position: positionSnapshot.data ?? Duration.zero,
              total: _elapsed,
              onToggle: _togglePlayback,
            );
          },
        );
      },
    );
  }

  Widget _buildWorkArea(Responsive r) {
    final fill = r.paneStrategy.isDual;

    if (_state == EvalState.analyzing) {
      return AnalyzingPanel(elapsed: _elapsed, fillHeight: fill);
    }

    if (_state == EvalState.reviewing) {
      final curso = _cursoParaClasificar;
      final pcpm = _currentPcpm;
      final velocidad = curso.isEmpty
          ? '—'
          : AssessmentCalculator.clasificarVelocidad(pcpm, curso);
      final nivelLogro = curso.isEmpty
          ? '—'
          : AssessmentCalculator.clasificarNivelLogro(pcpm, curso);

      return ReviewPanel(
        whisperFailed: _whisperFailed,
        originalText: _selectedTexto?.contenido ?? '',
        totalWords: _selectedTexto?.totalPalabras,
        transcript: _transcript,
        errorMap: buildErrorMap(_erroresDetalle),
        resultsKey: _resultsKey,
        pcpm: pcpm,
        velocidad: velocidad,
        nivelLogro: nivelLogro,
        calidad: _calidad,
        prosodia: _prosodia,
        courseStats: _courseStats,
        studentHistory: _studentHistory,
        loadingContext: _loadingContext,
        suggestions: buildSuggestions(
          nivelLogro: nivelLogro,
          calidad: _calidad,
          prosodia: _prosodia,
        ),
        scrollController: fill ? _rightPanelScrollController : null,
        fillHeight: fill,
      );
    }

    final texto = _selectedTexto;
    if (texto != null) {
      return ReadingView(
        text: texto,
        cursoLabel: _selectedCurso ?? '',
        studentName: _selectedStudent?.nombreCompleto,
        onChangeReading: _state == EvalState.idle
            ? () => setState(() => _setSelectedTexto(null))
            : null,
        fillHeight: fill,
        onReadingCplMeasured: (v) => _readingCpl = v,
      );
    }

    if (_selectedStudent != null && _textos.isNotEmpty) {
      return ReadingGallery(
        texts: _textos,
        studentName: _selectedStudent!.nombreCompleto,
        fillHeight: fill,
        onSelect: _state == EvalState.idle
            ? (text) {
                setState(() => _setSelectedTexto(text));
                _scrollToTimer();
              }
            : null,
      );
    }

    return AssessmentEmptyState(
      prompt: _selectionPrompt(),
      hasCurso: _selectedCurso != null,
      hasStudent: _selectedStudent != null,
      hasReading: _selectedTexto != null,
      fillHeight: fill,
    );
  }
}
