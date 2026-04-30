import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../features/students/data/student_repository.dart';
import '../logic/assessment_calculator.dart';

// Providers (se conectan desde main con ProviderScope overrides)
final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

enum EvalState { idle, recording, finished }

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  List<Student> _students = [];
  Student? _selectedStudent;
  EvalState _state = EvalState.idle;
  bool _syncing = false;

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
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _syncAndLoad();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _syncAndLoad() async {
    final db = ref.read(dbProvider);

    // Cargar desde DB local primero (instantáneo)
    final local = await db.getAllStudents();
    if (mounted) setState(() => _students = local);

    // Sincronizar desde el servidor en background
    setState(() => _syncing = true);
    try {
      final repo = StudentRepository(db, ApiClient());
      await repo.syncFromServer();
      final updated = await db.getAllStudents();
      if (mounted) setState(() => _students = updated);
    } catch (e) {
      if (mounted && _students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sin conexión — trabajando sin internet. Error: $e'),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/eval_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _audioPath = path;
      _state = EvalState.recording;
      _elapsed = Duration.zero;
      _errores = 0;
      _palabrasLeidas = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _state = EvalState.finished);
  }

  Future<void> _saveEvaluation() async {
    if (_selectedStudent == null) return;
    final db = ref.read(dbProvider);
    final segundos = _elapsed.inSeconds.toDouble();
    final pcpm = AssessmentCalculator.calcularPcpm(_palabrasLeidas, _errores, segundos);
    final nivelLogro = AssessmentCalculator.clasificarNivelLogro(pcpm, _selectedStudent!.curso);
    final velocidad = AssessmentCalculator.clasificarVelocidad(pcpm, _selectedStudent!.curso);

    await db.insertAssessment(AssessmentSessionsCompanion.insert(
      studentId: _selectedStudent!.id,
      fecha: DateTime.now(),
      pcpm: pcpm,
      velocidad: velocidad,
      nivelLogro: nivelLogro,
      calidad: _calidad,
      nivelLogroCalidad: nivelLogro,
      prosodia: _prosodia,
      audioPath: Value(_audioPath),
      synced: const Value(false),
    ));

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
              setState(() {
                _state = EvalState.idle;
                _selectedStudent = null;
                _errores = 0;
                _palabrasLeidas = 0;
                _elapsed = Duration.zero;
                _audioPath = null;
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
    child: Row(children: [
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(value),
    ]),
  );

  String _formatTime(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('ProsodIA — Evaluación lectora'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sincronizar estudiantes',
              onPressed: _state == EvalState.idle ? _syncAndLoad : null,
            ),
        ],
      ),
      body: Row(
        children: [
          // Panel izquierdo: selección y controles
          SizedBox(
            width: 320,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Estudiante', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Student>(
                      value: _selectedStudent,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      hint: const Text('Seleccionar alumno'),
                      items: _students.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text('${s.nombreCompleto} (${s.curso})',
                          overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: _state == EvalState.idle
                          ? (s) => setState(() => _selectedStudent = s)
                          : null,
                    ),
                    const SizedBox(height: 24),
                    // Temporizador
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _state == EvalState.recording
                            ? Colors.red[50]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Icon(
                          _state == EvalState.recording
                              ? Icons.fiber_manual_record
                              : Icons.timer_outlined,
                          color: _state == EvalState.recording ? Colors.red : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(_elapsed),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _state == EvalState.recording ? Colors.red : Colors.black87,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Botón grabar
                    if (_state != EvalState.finished)
                      SizedBox(
                        height: 56,
                        child: _state == EvalState.idle
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                ),
                                icon: const Icon(Icons.mic, size: 28),
                                label: const Text('INICIAR EVALUACIÓN',
                                  style: TextStyle(fontSize: 16)),
                                onPressed: _selectedStudent == null ? null : _startRecording,
                              )
                            : FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                ),
                                icon: const Icon(Icons.stop, size: 28),
                                label: const Text('DETENER',
                                  style: TextStyle(fontSize: 16)),
                                onPressed: _stopRecording,
                              ),
                      ),
                    const SizedBox(height: 24),
                    // Contadores de errores y palabras
                    if (_state != EvalState.idle) ...[
                      Text('Palabras leídas', style: Theme.of(context).textTheme.titleSmall),
                      _counterRow(
                        value: _palabrasLeidas,
                        onDec: () => setState(() {
                          if (_palabrasLeidas > 0) _palabrasLeidas--;
                        }),
                        onInc: () => setState(() => _palabrasLeidas++),
                      ),
                      const SizedBox(height: 12),
                      Text('Errores', style: Theme.of(context).textTheme.titleSmall),
                      _counterRow(
                        value: _errores,
                        onDec: () => setState(() {
                          if (_errores > 0) _errores--;
                        }),
                        onInc: () => setState(() => _errores++),
                      ),
                    ],
                    const Spacer(),
                    // Calidad y prosodia
                    if (_state == EvalState.finished) ...[
                      const Divider(),
                      Text('Calidad de lectura',
                        style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      _chipSelector(
                        options: const [
                          'silábica', 'palabra_a_palabra', 'unidades_cortas', 'fluida'
                        ],
                        selected: _calidad,
                        onSelected: (v) => setState(() => _calidad = v),
                      ),
                      const SizedBox(height: 12),
                      Text('Prosodia', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      _chipSelector(
                        options: const [
                          'inadecuada', 'básica', 'adecuada', 'expresiva'
                        ],
                        selected: _prosodia,
                        onSelected: (v) => setState(() => _prosodia = v),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar evaluación'),
                        onPressed: _saveEvaluation,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Panel derecho: texto de lectura (placeholder)
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _state == EvalState.idle
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded,
                              size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Selecciona un estudiante\ny presiona INICIAR EVALUACIÓN',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          // Texto de lectura — en producción se carga desde ReadingTexts
                          _textoEjemplo,
                          style: const TextStyle(
                            fontSize: 28,
                            height: 2.0,
                            letterSpacing: 0.5,
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

  Widget _counterRow({
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: onDec,
          icon: const Icon(Icons.remove),
          style: IconButton.styleFrom(backgroundColor: Colors.red[100]),
        ),
        Expanded(
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.filled(
          onPressed: onInc,
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(backgroundColor: Colors.green[100]),
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
      spacing: 6,
      children: options.map((o) => ChoiceChip(
        label: Text(o, style: const TextStyle(fontSize: 11)),
        selected: selected == o,
        onSelected: (_) => onSelected(o),
      )).toList(),
    );
  }

  static const String _textoEjemplo =
      'El sol salió temprano aquella mañana de primavera. '
      'Los niños corrían por el patio lleno de flores amarillas y rojas. '
      'La profesora los llamó con una palmada suave. '
      'Era hora de comenzar la clase de lectura.\n\n'
      'En el salón, cada uno tomó su libro. '
      'Las páginas olían a papel nuevo. '
      'Comenzaron a leer en silencio, con calma, disfrutando cada palabra.';
}
