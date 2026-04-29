// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StudentsTable extends Students with TableInfo<$StudentsTable, Student> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rutMeta = const VerificationMeta('rut');
  @override
  late final GeneratedColumn<String> rut = GeneratedColumn<String>(
    'rut',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreCompletoMeta = const VerificationMeta(
    'nombreCompleto',
  );
  @override
  late final GeneratedColumn<String> nombreCompleto = GeneratedColumn<String>(
    'nombre_completo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursoMeta = const VerificationMeta('curso');
  @override
  late final GeneratedColumn<String> curso = GeneratedColumn<String>(
    'curso',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activoMeta = const VerificationMeta('activo');
  @override
  late final GeneratedColumn<bool> activo = GeneratedColumn<bool>(
    'activo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("activo" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rut,
    nombreCompleto,
    curso,
    activo,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'students';
  @override
  VerificationContext validateIntegrity(
    Insertable<Student> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rut')) {
      context.handle(
        _rutMeta,
        rut.isAcceptableOrUnknown(data['rut']!, _rutMeta),
      );
    } else if (isInserting) {
      context.missing(_rutMeta);
    }
    if (data.containsKey('nombre_completo')) {
      context.handle(
        _nombreCompletoMeta,
        nombreCompleto.isAcceptableOrUnknown(
          data['nombre_completo']!,
          _nombreCompletoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nombreCompletoMeta);
    }
    if (data.containsKey('curso')) {
      context.handle(
        _cursoMeta,
        curso.isAcceptableOrUnknown(data['curso']!, _cursoMeta),
      );
    } else if (isInserting) {
      context.missing(_cursoMeta);
    }
    if (data.containsKey('activo')) {
      context.handle(
        _activoMeta,
        activo.isAcceptableOrUnknown(data['activo']!, _activoMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Student map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Student(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rut'],
      )!,
      nombreCompleto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre_completo'],
      )!,
      curso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curso'],
      )!,
      activo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}activo'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $StudentsTable createAlias(String alias) {
    return $StudentsTable(attachedDatabase, alias);
  }
}

class Student extends DataClass implements Insertable<Student> {
  final int id;
  final String rut;
  final String nombreCompleto;
  final String curso;
  final bool activo;
  final DateTime syncedAt;
  const Student({
    required this.id,
    required this.rut,
    required this.nombreCompleto,
    required this.curso,
    required this.activo,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['rut'] = Variable<String>(rut);
    map['nombre_completo'] = Variable<String>(nombreCompleto);
    map['curso'] = Variable<String>(curso);
    map['activo'] = Variable<bool>(activo);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  StudentsCompanion toCompanion(bool nullToAbsent) {
    return StudentsCompanion(
      id: Value(id),
      rut: Value(rut),
      nombreCompleto: Value(nombreCompleto),
      curso: Value(curso),
      activo: Value(activo),
      syncedAt: Value(syncedAt),
    );
  }

  factory Student.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Student(
      id: serializer.fromJson<int>(json['id']),
      rut: serializer.fromJson<String>(json['rut']),
      nombreCompleto: serializer.fromJson<String>(json['nombreCompleto']),
      curso: serializer.fromJson<String>(json['curso']),
      activo: serializer.fromJson<bool>(json['activo']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rut': serializer.toJson<String>(rut),
      'nombreCompleto': serializer.toJson<String>(nombreCompleto),
      'curso': serializer.toJson<String>(curso),
      'activo': serializer.toJson<bool>(activo),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  Student copyWith({
    int? id,
    String? rut,
    String? nombreCompleto,
    String? curso,
    bool? activo,
    DateTime? syncedAt,
  }) => Student(
    id: id ?? this.id,
    rut: rut ?? this.rut,
    nombreCompleto: nombreCompleto ?? this.nombreCompleto,
    curso: curso ?? this.curso,
    activo: activo ?? this.activo,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  Student copyWithCompanion(StudentsCompanion data) {
    return Student(
      id: data.id.present ? data.id.value : this.id,
      rut: data.rut.present ? data.rut.value : this.rut,
      nombreCompleto: data.nombreCompleto.present
          ? data.nombreCompleto.value
          : this.nombreCompleto,
      curso: data.curso.present ? data.curso.value : this.curso,
      activo: data.activo.present ? data.activo.value : this.activo,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Student(')
          ..write('id: $id, ')
          ..write('rut: $rut, ')
          ..write('nombreCompleto: $nombreCompleto, ')
          ..write('curso: $curso, ')
          ..write('activo: $activo, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, rut, nombreCompleto, curso, activo, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Student &&
          other.id == this.id &&
          other.rut == this.rut &&
          other.nombreCompleto == this.nombreCompleto &&
          other.curso == this.curso &&
          other.activo == this.activo &&
          other.syncedAt == this.syncedAt);
}

class StudentsCompanion extends UpdateCompanion<Student> {
  final Value<int> id;
  final Value<String> rut;
  final Value<String> nombreCompleto;
  final Value<String> curso;
  final Value<bool> activo;
  final Value<DateTime> syncedAt;
  const StudentsCompanion({
    this.id = const Value.absent(),
    this.rut = const Value.absent(),
    this.nombreCompleto = const Value.absent(),
    this.curso = const Value.absent(),
    this.activo = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  StudentsCompanion.insert({
    this.id = const Value.absent(),
    required String rut,
    required String nombreCompleto,
    required String curso,
    this.activo = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : rut = Value(rut),
       nombreCompleto = Value(nombreCompleto),
       curso = Value(curso);
  static Insertable<Student> custom({
    Expression<int>? id,
    Expression<String>? rut,
    Expression<String>? nombreCompleto,
    Expression<String>? curso,
    Expression<bool>? activo,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rut != null) 'rut': rut,
      if (nombreCompleto != null) 'nombre_completo': nombreCompleto,
      if (curso != null) 'curso': curso,
      if (activo != null) 'activo': activo,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  StudentsCompanion copyWith({
    Value<int>? id,
    Value<String>? rut,
    Value<String>? nombreCompleto,
    Value<String>? curso,
    Value<bool>? activo,
    Value<DateTime>? syncedAt,
  }) {
    return StudentsCompanion(
      id: id ?? this.id,
      rut: rut ?? this.rut,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      curso: curso ?? this.curso,
      activo: activo ?? this.activo,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rut.present) {
      map['rut'] = Variable<String>(rut.value);
    }
    if (nombreCompleto.present) {
      map['nombre_completo'] = Variable<String>(nombreCompleto.value);
    }
    if (curso.present) {
      map['curso'] = Variable<String>(curso.value);
    }
    if (activo.present) {
      map['activo'] = Variable<bool>(activo.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentsCompanion(')
          ..write('id: $id, ')
          ..write('rut: $rut, ')
          ..write('nombreCompleto: $nombreCompleto, ')
          ..write('curso: $curso, ')
          ..write('activo: $activo, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $AssessmentSessionsTable extends AssessmentSessions
    with TableInfo<$AssessmentSessionsTable, AssessmentSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssessmentSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<int> studentId = GeneratedColumn<int>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id)',
    ),
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<DateTime> fecha = GeneratedColumn<DateTime>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pcpmMeta = const VerificationMeta('pcpm');
  @override
  late final GeneratedColumn<double> pcpm = GeneratedColumn<double>(
    'pcpm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _velocidadMeta = const VerificationMeta(
    'velocidad',
  );
  @override
  late final GeneratedColumn<String> velocidad = GeneratedColumn<String>(
    'velocidad',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nivelLogroMeta = const VerificationMeta(
    'nivelLogro',
  );
  @override
  late final GeneratedColumn<String> nivelLogro = GeneratedColumn<String>(
    'nivel_logro',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calidadMeta = const VerificationMeta(
    'calidad',
  );
  @override
  late final GeneratedColumn<String> calidad = GeneratedColumn<String>(
    'calidad',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nivelLogroCalidadMeta = const VerificationMeta(
    'nivelLogroCalidad',
  );
  @override
  late final GeneratedColumn<String> nivelLogroCalidad =
      GeneratedColumn<String>(
        'nivel_logro_calidad',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _prosodiaMeta = const VerificationMeta(
    'prosodia',
  );
  @override
  late final GeneratedColumn<String> prosodia = GeneratedColumn<String>(
    'prosodia',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studentId,
    fecha,
    pcpm,
    velocidad,
    nivelLogro,
    calidad,
    nivelLogroCalidad,
    prosodia,
    audioPath,
    synced,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assessment_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssessmentSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('pcpm')) {
      context.handle(
        _pcpmMeta,
        pcpm.isAcceptableOrUnknown(data['pcpm']!, _pcpmMeta),
      );
    } else if (isInserting) {
      context.missing(_pcpmMeta);
    }
    if (data.containsKey('velocidad')) {
      context.handle(
        _velocidadMeta,
        velocidad.isAcceptableOrUnknown(data['velocidad']!, _velocidadMeta),
      );
    } else if (isInserting) {
      context.missing(_velocidadMeta);
    }
    if (data.containsKey('nivel_logro')) {
      context.handle(
        _nivelLogroMeta,
        nivelLogro.isAcceptableOrUnknown(data['nivel_logro']!, _nivelLogroMeta),
      );
    } else if (isInserting) {
      context.missing(_nivelLogroMeta);
    }
    if (data.containsKey('calidad')) {
      context.handle(
        _calidadMeta,
        calidad.isAcceptableOrUnknown(data['calidad']!, _calidadMeta),
      );
    } else if (isInserting) {
      context.missing(_calidadMeta);
    }
    if (data.containsKey('nivel_logro_calidad')) {
      context.handle(
        _nivelLogroCalidadMeta,
        nivelLogroCalidad.isAcceptableOrUnknown(
          data['nivel_logro_calidad']!,
          _nivelLogroCalidadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nivelLogroCalidadMeta);
    }
    if (data.containsKey('prosodia')) {
      context.handle(
        _prosodiaMeta,
        prosodia.isAcceptableOrUnknown(data['prosodia']!, _prosodiaMeta),
      );
    } else if (isInserting) {
      context.missing(_prosodiaMeta);
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssessmentSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssessmentSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}student_id'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha'],
      )!,
      pcpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pcpm'],
      )!,
      velocidad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}velocidad'],
      )!,
      nivelLogro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nivel_logro'],
      )!,
      calidad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calidad'],
      )!,
      nivelLogroCalidad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nivel_logro_calidad'],
      )!,
      prosodia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prosodia'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $AssessmentSessionsTable createAlias(String alias) {
    return $AssessmentSessionsTable(attachedDatabase, alias);
  }
}

class AssessmentSession extends DataClass
    implements Insertable<AssessmentSession> {
  final int id;
  final int studentId;
  final DateTime fecha;
  final double pcpm;
  final String velocidad;
  final String nivelLogro;
  final String calidad;
  final String nivelLogroCalidad;
  final String prosodia;
  final String? audioPath;
  final bool synced;
  final DateTime? syncedAt;
  const AssessmentSession({
    required this.id,
    required this.studentId,
    required this.fecha,
    required this.pcpm,
    required this.velocidad,
    required this.nivelLogro,
    required this.calidad,
    required this.nivelLogroCalidad,
    required this.prosodia,
    this.audioPath,
    required this.synced,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['student_id'] = Variable<int>(studentId);
    map['fecha'] = Variable<DateTime>(fecha);
    map['pcpm'] = Variable<double>(pcpm);
    map['velocidad'] = Variable<String>(velocidad);
    map['nivel_logro'] = Variable<String>(nivelLogro);
    map['calidad'] = Variable<String>(calidad);
    map['nivel_logro_calidad'] = Variable<String>(nivelLogroCalidad);
    map['prosodia'] = Variable<String>(prosodia);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  AssessmentSessionsCompanion toCompanion(bool nullToAbsent) {
    return AssessmentSessionsCompanion(
      id: Value(id),
      studentId: Value(studentId),
      fecha: Value(fecha),
      pcpm: Value(pcpm),
      velocidad: Value(velocidad),
      nivelLogro: Value(nivelLogro),
      calidad: Value(calidad),
      nivelLogroCalidad: Value(nivelLogroCalidad),
      prosodia: Value(prosodia),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      synced: Value(synced),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory AssessmentSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssessmentSession(
      id: serializer.fromJson<int>(json['id']),
      studentId: serializer.fromJson<int>(json['studentId']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
      pcpm: serializer.fromJson<double>(json['pcpm']),
      velocidad: serializer.fromJson<String>(json['velocidad']),
      nivelLogro: serializer.fromJson<String>(json['nivelLogro']),
      calidad: serializer.fromJson<String>(json['calidad']),
      nivelLogroCalidad: serializer.fromJson<String>(json['nivelLogroCalidad']),
      prosodia: serializer.fromJson<String>(json['prosodia']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      synced: serializer.fromJson<bool>(json['synced']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'studentId': serializer.toJson<int>(studentId),
      'fecha': serializer.toJson<DateTime>(fecha),
      'pcpm': serializer.toJson<double>(pcpm),
      'velocidad': serializer.toJson<String>(velocidad),
      'nivelLogro': serializer.toJson<String>(nivelLogro),
      'calidad': serializer.toJson<String>(calidad),
      'nivelLogroCalidad': serializer.toJson<String>(nivelLogroCalidad),
      'prosodia': serializer.toJson<String>(prosodia),
      'audioPath': serializer.toJson<String?>(audioPath),
      'synced': serializer.toJson<bool>(synced),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  AssessmentSession copyWith({
    int? id,
    int? studentId,
    DateTime? fecha,
    double? pcpm,
    String? velocidad,
    String? nivelLogro,
    String? calidad,
    String? nivelLogroCalidad,
    String? prosodia,
    Value<String?> audioPath = const Value.absent(),
    bool? synced,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => AssessmentSession(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    fecha: fecha ?? this.fecha,
    pcpm: pcpm ?? this.pcpm,
    velocidad: velocidad ?? this.velocidad,
    nivelLogro: nivelLogro ?? this.nivelLogro,
    calidad: calidad ?? this.calidad,
    nivelLogroCalidad: nivelLogroCalidad ?? this.nivelLogroCalidad,
    prosodia: prosodia ?? this.prosodia,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    synced: synced ?? this.synced,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  AssessmentSession copyWithCompanion(AssessmentSessionsCompanion data) {
    return AssessmentSession(
      id: data.id.present ? data.id.value : this.id,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      pcpm: data.pcpm.present ? data.pcpm.value : this.pcpm,
      velocidad: data.velocidad.present ? data.velocidad.value : this.velocidad,
      nivelLogro: data.nivelLogro.present
          ? data.nivelLogro.value
          : this.nivelLogro,
      calidad: data.calidad.present ? data.calidad.value : this.calidad,
      nivelLogroCalidad: data.nivelLogroCalidad.present
          ? data.nivelLogroCalidad.value
          : this.nivelLogroCalidad,
      prosodia: data.prosodia.present ? data.prosodia.value : this.prosodia,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      synced: data.synced.present ? data.synced.value : this.synced,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentSession(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('fecha: $fecha, ')
          ..write('pcpm: $pcpm, ')
          ..write('velocidad: $velocidad, ')
          ..write('nivelLogro: $nivelLogro, ')
          ..write('calidad: $calidad, ')
          ..write('nivelLogroCalidad: $nivelLogroCalidad, ')
          ..write('prosodia: $prosodia, ')
          ..write('audioPath: $audioPath, ')
          ..write('synced: $synced, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studentId,
    fecha,
    pcpm,
    velocidad,
    nivelLogro,
    calidad,
    nivelLogroCalidad,
    prosodia,
    audioPath,
    synced,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssessmentSession &&
          other.id == this.id &&
          other.studentId == this.studentId &&
          other.fecha == this.fecha &&
          other.pcpm == this.pcpm &&
          other.velocidad == this.velocidad &&
          other.nivelLogro == this.nivelLogro &&
          other.calidad == this.calidad &&
          other.nivelLogroCalidad == this.nivelLogroCalidad &&
          other.prosodia == this.prosodia &&
          other.audioPath == this.audioPath &&
          other.synced == this.synced &&
          other.syncedAt == this.syncedAt);
}

class AssessmentSessionsCompanion extends UpdateCompanion<AssessmentSession> {
  final Value<int> id;
  final Value<int> studentId;
  final Value<DateTime> fecha;
  final Value<double> pcpm;
  final Value<String> velocidad;
  final Value<String> nivelLogro;
  final Value<String> calidad;
  final Value<String> nivelLogroCalidad;
  final Value<String> prosodia;
  final Value<String?> audioPath;
  final Value<bool> synced;
  final Value<DateTime?> syncedAt;
  const AssessmentSessionsCompanion({
    this.id = const Value.absent(),
    this.studentId = const Value.absent(),
    this.fecha = const Value.absent(),
    this.pcpm = const Value.absent(),
    this.velocidad = const Value.absent(),
    this.nivelLogro = const Value.absent(),
    this.calidad = const Value.absent(),
    this.nivelLogroCalidad = const Value.absent(),
    this.prosodia = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.synced = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  AssessmentSessionsCompanion.insert({
    this.id = const Value.absent(),
    required int studentId,
    required DateTime fecha,
    required double pcpm,
    required String velocidad,
    required String nivelLogro,
    required String calidad,
    required String nivelLogroCalidad,
    required String prosodia,
    this.audioPath = const Value.absent(),
    this.synced = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : studentId = Value(studentId),
       fecha = Value(fecha),
       pcpm = Value(pcpm),
       velocidad = Value(velocidad),
       nivelLogro = Value(nivelLogro),
       calidad = Value(calidad),
       nivelLogroCalidad = Value(nivelLogroCalidad),
       prosodia = Value(prosodia);
  static Insertable<AssessmentSession> custom({
    Expression<int>? id,
    Expression<int>? studentId,
    Expression<DateTime>? fecha,
    Expression<double>? pcpm,
    Expression<String>? velocidad,
    Expression<String>? nivelLogro,
    Expression<String>? calidad,
    Expression<String>? nivelLogroCalidad,
    Expression<String>? prosodia,
    Expression<String>? audioPath,
    Expression<bool>? synced,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studentId != null) 'student_id': studentId,
      if (fecha != null) 'fecha': fecha,
      if (pcpm != null) 'pcpm': pcpm,
      if (velocidad != null) 'velocidad': velocidad,
      if (nivelLogro != null) 'nivel_logro': nivelLogro,
      if (calidad != null) 'calidad': calidad,
      if (nivelLogroCalidad != null) 'nivel_logro_calidad': nivelLogroCalidad,
      if (prosodia != null) 'prosodia': prosodia,
      if (audioPath != null) 'audio_path': audioPath,
      if (synced != null) 'synced': synced,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  AssessmentSessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? studentId,
    Value<DateTime>? fecha,
    Value<double>? pcpm,
    Value<String>? velocidad,
    Value<String>? nivelLogro,
    Value<String>? calidad,
    Value<String>? nivelLogroCalidad,
    Value<String>? prosodia,
    Value<String?>? audioPath,
    Value<bool>? synced,
    Value<DateTime?>? syncedAt,
  }) {
    return AssessmentSessionsCompanion(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      fecha: fecha ?? this.fecha,
      pcpm: pcpm ?? this.pcpm,
      velocidad: velocidad ?? this.velocidad,
      nivelLogro: nivelLogro ?? this.nivelLogro,
      calidad: calidad ?? this.calidad,
      nivelLogroCalidad: nivelLogroCalidad ?? this.nivelLogroCalidad,
      prosodia: prosodia ?? this.prosodia,
      audioPath: audioPath ?? this.audioPath,
      synced: synced ?? this.synced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<int>(studentId.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<DateTime>(fecha.value);
    }
    if (pcpm.present) {
      map['pcpm'] = Variable<double>(pcpm.value);
    }
    if (velocidad.present) {
      map['velocidad'] = Variable<String>(velocidad.value);
    }
    if (nivelLogro.present) {
      map['nivel_logro'] = Variable<String>(nivelLogro.value);
    }
    if (calidad.present) {
      map['calidad'] = Variable<String>(calidad.value);
    }
    if (nivelLogroCalidad.present) {
      map['nivel_logro_calidad'] = Variable<String>(nivelLogroCalidad.value);
    }
    if (prosodia.present) {
      map['prosodia'] = Variable<String>(prosodia.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentSessionsCompanion(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('fecha: $fecha, ')
          ..write('pcpm: $pcpm, ')
          ..write('velocidad: $velocidad, ')
          ..write('nivelLogro: $nivelLogro, ')
          ..write('calidad: $calidad, ')
          ..write('nivelLogroCalidad: $nivelLogroCalidad, ')
          ..write('prosodia: $prosodia, ')
          ..write('audioPath: $audioPath, ')
          ..write('synced: $synced, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingTextsTable extends ReadingTexts
    with TableInfo<$ReadingTextsTable, ReadingText> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingTextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contenidoMeta = const VerificationMeta(
    'contenido',
  );
  @override
  late final GeneratedColumn<String> contenido = GeneratedColumn<String>(
    'contenido',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nivelMeta = const VerificationMeta('nivel');
  @override
  late final GeneratedColumn<String> nivel = GeneratedColumn<String>(
    'nivel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPalabrasMeta = const VerificationMeta(
    'totalPalabras',
  );
  @override
  late final GeneratedColumn<int> totalPalabras = GeneratedColumn<int>(
    'total_palabras',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titulo,
    contenido,
    nivel,
    totalPalabras,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_texts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingText> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('contenido')) {
      context.handle(
        _contenidoMeta,
        contenido.isAcceptableOrUnknown(data['contenido']!, _contenidoMeta),
      );
    } else if (isInserting) {
      context.missing(_contenidoMeta);
    }
    if (data.containsKey('nivel')) {
      context.handle(
        _nivelMeta,
        nivel.isAcceptableOrUnknown(data['nivel']!, _nivelMeta),
      );
    } else if (isInserting) {
      context.missing(_nivelMeta);
    }
    if (data.containsKey('total_palabras')) {
      context.handle(
        _totalPalabrasMeta,
        totalPalabras.isAcceptableOrUnknown(
          data['total_palabras']!,
          _totalPalabrasMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPalabrasMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingText map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingText(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      contenido: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contenido'],
      )!,
      nivel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nivel'],
      )!,
      totalPalabras: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_palabras'],
      )!,
    );
  }

  @override
  $ReadingTextsTable createAlias(String alias) {
    return $ReadingTextsTable(attachedDatabase, alias);
  }
}

class ReadingText extends DataClass implements Insertable<ReadingText> {
  final int id;
  final String titulo;
  final String contenido;
  final String nivel;
  final int totalPalabras;
  const ReadingText({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.nivel,
    required this.totalPalabras,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['titulo'] = Variable<String>(titulo);
    map['contenido'] = Variable<String>(contenido);
    map['nivel'] = Variable<String>(nivel);
    map['total_palabras'] = Variable<int>(totalPalabras);
    return map;
  }

  ReadingTextsCompanion toCompanion(bool nullToAbsent) {
    return ReadingTextsCompanion(
      id: Value(id),
      titulo: Value(titulo),
      contenido: Value(contenido),
      nivel: Value(nivel),
      totalPalabras: Value(totalPalabras),
    );
  }

  factory ReadingText.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingText(
      id: serializer.fromJson<int>(json['id']),
      titulo: serializer.fromJson<String>(json['titulo']),
      contenido: serializer.fromJson<String>(json['contenido']),
      nivel: serializer.fromJson<String>(json['nivel']),
      totalPalabras: serializer.fromJson<int>(json['totalPalabras']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'titulo': serializer.toJson<String>(titulo),
      'contenido': serializer.toJson<String>(contenido),
      'nivel': serializer.toJson<String>(nivel),
      'totalPalabras': serializer.toJson<int>(totalPalabras),
    };
  }

  ReadingText copyWith({
    int? id,
    String? titulo,
    String? contenido,
    String? nivel,
    int? totalPalabras,
  }) => ReadingText(
    id: id ?? this.id,
    titulo: titulo ?? this.titulo,
    contenido: contenido ?? this.contenido,
    nivel: nivel ?? this.nivel,
    totalPalabras: totalPalabras ?? this.totalPalabras,
  );
  ReadingText copyWithCompanion(ReadingTextsCompanion data) {
    return ReadingText(
      id: data.id.present ? data.id.value : this.id,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      contenido: data.contenido.present ? data.contenido.value : this.contenido,
      nivel: data.nivel.present ? data.nivel.value : this.nivel,
      totalPalabras: data.totalPalabras.present
          ? data.totalPalabras.value
          : this.totalPalabras,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingText(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('contenido: $contenido, ')
          ..write('nivel: $nivel, ')
          ..write('totalPalabras: $totalPalabras')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, titulo, contenido, nivel, totalPalabras);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingText &&
          other.id == this.id &&
          other.titulo == this.titulo &&
          other.contenido == this.contenido &&
          other.nivel == this.nivel &&
          other.totalPalabras == this.totalPalabras);
}

class ReadingTextsCompanion extends UpdateCompanion<ReadingText> {
  final Value<int> id;
  final Value<String> titulo;
  final Value<String> contenido;
  final Value<String> nivel;
  final Value<int> totalPalabras;
  const ReadingTextsCompanion({
    this.id = const Value.absent(),
    this.titulo = const Value.absent(),
    this.contenido = const Value.absent(),
    this.nivel = const Value.absent(),
    this.totalPalabras = const Value.absent(),
  });
  ReadingTextsCompanion.insert({
    this.id = const Value.absent(),
    required String titulo,
    required String contenido,
    required String nivel,
    required int totalPalabras,
  }) : titulo = Value(titulo),
       contenido = Value(contenido),
       nivel = Value(nivel),
       totalPalabras = Value(totalPalabras);
  static Insertable<ReadingText> custom({
    Expression<int>? id,
    Expression<String>? titulo,
    Expression<String>? contenido,
    Expression<String>? nivel,
    Expression<int>? totalPalabras,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titulo != null) 'titulo': titulo,
      if (contenido != null) 'contenido': contenido,
      if (nivel != null) 'nivel': nivel,
      if (totalPalabras != null) 'total_palabras': totalPalabras,
    });
  }

  ReadingTextsCompanion copyWith({
    Value<int>? id,
    Value<String>? titulo,
    Value<String>? contenido,
    Value<String>? nivel,
    Value<int>? totalPalabras,
  }) {
    return ReadingTextsCompanion(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      contenido: contenido ?? this.contenido,
      nivel: nivel ?? this.nivel,
      totalPalabras: totalPalabras ?? this.totalPalabras,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (contenido.present) {
      map['contenido'] = Variable<String>(contenido.value);
    }
    if (nivel.present) {
      map['nivel'] = Variable<String>(nivel.value);
    }
    if (totalPalabras.present) {
      map['total_palabras'] = Variable<int>(totalPalabras.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingTextsCompanion(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('contenido: $contenido, ')
          ..write('nivel: $nivel, ')
          ..write('totalPalabras: $totalPalabras')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StudentsTable students = $StudentsTable(this);
  late final $AssessmentSessionsTable assessmentSessions =
      $AssessmentSessionsTable(this);
  late final $ReadingTextsTable readingTexts = $ReadingTextsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    students,
    assessmentSessions,
    readingTexts,
  ];
}

typedef $$StudentsTableCreateCompanionBuilder =
    StudentsCompanion Function({
      Value<int> id,
      required String rut,
      required String nombreCompleto,
      required String curso,
      Value<bool> activo,
      Value<DateTime> syncedAt,
    });
typedef $$StudentsTableUpdateCompanionBuilder =
    StudentsCompanion Function({
      Value<int> id,
      Value<String> rut,
      Value<String> nombreCompleto,
      Value<String> curso,
      Value<bool> activo,
      Value<DateTime> syncedAt,
    });

final class $$StudentsTableReferences
    extends BaseReferences<_$AppDatabase, $StudentsTable, Student> {
  $$StudentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AssessmentSessionsTable, List<AssessmentSession>>
  _assessmentSessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assessmentSessions,
        aliasName: $_aliasNameGenerator(
          db.students.id,
          db.assessmentSessions.studentId,
        ),
      );

  $$AssessmentSessionsTableProcessedTableManager get assessmentSessionsRefs {
    final manager = $$AssessmentSessionsTableTableManager(
      $_db,
      $_db.assessmentSessions,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assessmentSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StudentsTableFilterComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rut => $composableBuilder(
    column: $table.rut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombreCompleto => $composableBuilder(
    column: $table.nombreCompleto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curso => $composableBuilder(
    column: $table.curso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get activo => $composableBuilder(
    column: $table.activo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> assessmentSessionsRefs(
    Expression<bool> Function($$AssessmentSessionsTableFilterComposer f) f,
  ) {
    final $$AssessmentSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assessmentSessions,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssessmentSessionsTableFilterComposer(
            $db: $db,
            $table: $db.assessmentSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudentsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rut => $composableBuilder(
    column: $table.rut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombreCompleto => $composableBuilder(
    column: $table.nombreCompleto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curso => $composableBuilder(
    column: $table.curso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get activo => $composableBuilder(
    column: $table.activo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rut =>
      $composableBuilder(column: $table.rut, builder: (column) => column);

  GeneratedColumn<String> get nombreCompleto => $composableBuilder(
    column: $table.nombreCompleto,
    builder: (column) => column,
  );

  GeneratedColumn<String> get curso =>
      $composableBuilder(column: $table.curso, builder: (column) => column);

  GeneratedColumn<bool> get activo =>
      $composableBuilder(column: $table.activo, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  Expression<T> assessmentSessionsRefs<T extends Object>(
    Expression<T> Function($$AssessmentSessionsTableAnnotationComposer a) f,
  ) {
    final $$AssessmentSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assessmentSessions,
          getReferencedColumn: (t) => t.studentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssessmentSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.assessmentSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$StudentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentsTable,
          Student,
          $$StudentsTableFilterComposer,
          $$StudentsTableOrderingComposer,
          $$StudentsTableAnnotationComposer,
          $$StudentsTableCreateCompanionBuilder,
          $$StudentsTableUpdateCompanionBuilder,
          (Student, $$StudentsTableReferences),
          Student,
          PrefetchHooks Function({bool assessmentSessionsRefs})
        > {
  $$StudentsTableTableManager(_$AppDatabase db, $StudentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> rut = const Value.absent(),
                Value<String> nombreCompleto = const Value.absent(),
                Value<String> curso = const Value.absent(),
                Value<bool> activo = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
              }) => StudentsCompanion(
                id: id,
                rut: rut,
                nombreCompleto: nombreCompleto,
                curso: curso,
                activo: activo,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String rut,
                required String nombreCompleto,
                required String curso,
                Value<bool> activo = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
              }) => StudentsCompanion.insert(
                id: id,
                rut: rut,
                nombreCompleto: nombreCompleto,
                curso: curso,
                activo: activo,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assessmentSessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (assessmentSessionsRefs) db.assessmentSessions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (assessmentSessionsRefs)
                    await $_getPrefetchedData<
                      Student,
                      $StudentsTable,
                      AssessmentSession
                    >(
                      currentTable: table,
                      referencedTable: $$StudentsTableReferences
                          ._assessmentSessionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$StudentsTableReferences(
                        db,
                        table,
                        p0,
                      ).assessmentSessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.studentId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$StudentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentsTable,
      Student,
      $$StudentsTableFilterComposer,
      $$StudentsTableOrderingComposer,
      $$StudentsTableAnnotationComposer,
      $$StudentsTableCreateCompanionBuilder,
      $$StudentsTableUpdateCompanionBuilder,
      (Student, $$StudentsTableReferences),
      Student,
      PrefetchHooks Function({bool assessmentSessionsRefs})
    >;
typedef $$AssessmentSessionsTableCreateCompanionBuilder =
    AssessmentSessionsCompanion Function({
      Value<int> id,
      required int studentId,
      required DateTime fecha,
      required double pcpm,
      required String velocidad,
      required String nivelLogro,
      required String calidad,
      required String nivelLogroCalidad,
      required String prosodia,
      Value<String?> audioPath,
      Value<bool> synced,
      Value<DateTime?> syncedAt,
    });
typedef $$AssessmentSessionsTableUpdateCompanionBuilder =
    AssessmentSessionsCompanion Function({
      Value<int> id,
      Value<int> studentId,
      Value<DateTime> fecha,
      Value<double> pcpm,
      Value<String> velocidad,
      Value<String> nivelLogro,
      Value<String> calidad,
      Value<String> nivelLogroCalidad,
      Value<String> prosodia,
      Value<String?> audioPath,
      Value<bool> synced,
      Value<DateTime?> syncedAt,
    });

final class $$AssessmentSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AssessmentSessionsTable,
          AssessmentSession
        > {
  $$AssessmentSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias(
        $_aliasNameGenerator(db.assessmentSessions.studentId, db.students.id),
      );

  $$StudentsTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<int>('student_id')!;

    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssessmentSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $AssessmentSessionsTable> {
  $$AssessmentSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pcpm => $composableBuilder(
    column: $table.pcpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get velocidad => $composableBuilder(
    column: $table.velocidad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nivelLogro => $composableBuilder(
    column: $table.nivelLogro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calidad => $composableBuilder(
    column: $table.calidad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nivelLogroCalidad => $composableBuilder(
    column: $table.nivelLogroCalidad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prosodia => $composableBuilder(
    column: $table.prosodia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StudentsTableFilterComposer get studentId {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssessmentSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssessmentSessionsTable> {
  $$AssessmentSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pcpm => $composableBuilder(
    column: $table.pcpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get velocidad => $composableBuilder(
    column: $table.velocidad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nivelLogro => $composableBuilder(
    column: $table.nivelLogro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calidad => $composableBuilder(
    column: $table.calidad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nivelLogroCalidad => $composableBuilder(
    column: $table.nivelLogroCalidad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prosodia => $composableBuilder(
    column: $table.prosodia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StudentsTableOrderingComposer get studentId {
    final $$StudentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableOrderingComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssessmentSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssessmentSessionsTable> {
  $$AssessmentSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<double> get pcpm =>
      $composableBuilder(column: $table.pcpm, builder: (column) => column);

  GeneratedColumn<String> get velocidad =>
      $composableBuilder(column: $table.velocidad, builder: (column) => column);

  GeneratedColumn<String> get nivelLogro => $composableBuilder(
    column: $table.nivelLogro,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calidad =>
      $composableBuilder(column: $table.calidad, builder: (column) => column);

  GeneratedColumn<String> get nivelLogroCalidad => $composableBuilder(
    column: $table.nivelLogroCalidad,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prosodia =>
      $composableBuilder(column: $table.prosodia, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  $$StudentsTableAnnotationComposer get studentId {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssessmentSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssessmentSessionsTable,
          AssessmentSession,
          $$AssessmentSessionsTableFilterComposer,
          $$AssessmentSessionsTableOrderingComposer,
          $$AssessmentSessionsTableAnnotationComposer,
          $$AssessmentSessionsTableCreateCompanionBuilder,
          $$AssessmentSessionsTableUpdateCompanionBuilder,
          (AssessmentSession, $$AssessmentSessionsTableReferences),
          AssessmentSession,
          PrefetchHooks Function({bool studentId})
        > {
  $$AssessmentSessionsTableTableManager(
    _$AppDatabase db,
    $AssessmentSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssessmentSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssessmentSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssessmentSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> studentId = const Value.absent(),
                Value<DateTime> fecha = const Value.absent(),
                Value<double> pcpm = const Value.absent(),
                Value<String> velocidad = const Value.absent(),
                Value<String> nivelLogro = const Value.absent(),
                Value<String> calidad = const Value.absent(),
                Value<String> nivelLogroCalidad = const Value.absent(),
                Value<String> prosodia = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => AssessmentSessionsCompanion(
                id: id,
                studentId: studentId,
                fecha: fecha,
                pcpm: pcpm,
                velocidad: velocidad,
                nivelLogro: nivelLogro,
                calidad: calidad,
                nivelLogroCalidad: nivelLogroCalidad,
                prosodia: prosodia,
                audioPath: audioPath,
                synced: synced,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int studentId,
                required DateTime fecha,
                required double pcpm,
                required String velocidad,
                required String nivelLogro,
                required String calidad,
                required String nivelLogroCalidad,
                required String prosodia,
                Value<String?> audioPath = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => AssessmentSessionsCompanion.insert(
                id: id,
                studentId: studentId,
                fecha: fecha,
                pcpm: pcpm,
                velocidad: velocidad,
                nivelLogro: nivelLogro,
                calidad: calidad,
                nivelLogroCalidad: nivelLogroCalidad,
                prosodia: prosodia,
                audioPath: audioPath,
                synced: synced,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssessmentSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (studentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.studentId,
                                referencedTable:
                                    $$AssessmentSessionsTableReferences
                                        ._studentIdTable(db),
                                referencedColumn:
                                    $$AssessmentSessionsTableReferences
                                        ._studentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssessmentSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssessmentSessionsTable,
      AssessmentSession,
      $$AssessmentSessionsTableFilterComposer,
      $$AssessmentSessionsTableOrderingComposer,
      $$AssessmentSessionsTableAnnotationComposer,
      $$AssessmentSessionsTableCreateCompanionBuilder,
      $$AssessmentSessionsTableUpdateCompanionBuilder,
      (AssessmentSession, $$AssessmentSessionsTableReferences),
      AssessmentSession,
      PrefetchHooks Function({bool studentId})
    >;
typedef $$ReadingTextsTableCreateCompanionBuilder =
    ReadingTextsCompanion Function({
      Value<int> id,
      required String titulo,
      required String contenido,
      required String nivel,
      required int totalPalabras,
    });
typedef $$ReadingTextsTableUpdateCompanionBuilder =
    ReadingTextsCompanion Function({
      Value<int> id,
      Value<String> titulo,
      Value<String> contenido,
      Value<String> nivel,
      Value<int> totalPalabras,
    });

class $$ReadingTextsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingTextsTable> {
  $$ReadingTextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contenido => $composableBuilder(
    column: $table.contenido,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nivel => $composableBuilder(
    column: $table.nivel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPalabras => $composableBuilder(
    column: $table.totalPalabras,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingTextsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingTextsTable> {
  $$ReadingTextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contenido => $composableBuilder(
    column: $table.contenido,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nivel => $composableBuilder(
    column: $table.nivel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPalabras => $composableBuilder(
    column: $table.totalPalabras,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingTextsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingTextsTable> {
  $$ReadingTextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get contenido =>
      $composableBuilder(column: $table.contenido, builder: (column) => column);

  GeneratedColumn<String> get nivel =>
      $composableBuilder(column: $table.nivel, builder: (column) => column);

  GeneratedColumn<int> get totalPalabras => $composableBuilder(
    column: $table.totalPalabras,
    builder: (column) => column,
  );
}

class $$ReadingTextsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingTextsTable,
          ReadingText,
          $$ReadingTextsTableFilterComposer,
          $$ReadingTextsTableOrderingComposer,
          $$ReadingTextsTableAnnotationComposer,
          $$ReadingTextsTableCreateCompanionBuilder,
          $$ReadingTextsTableUpdateCompanionBuilder,
          (
            ReadingText,
            BaseReferences<_$AppDatabase, $ReadingTextsTable, ReadingText>,
          ),
          ReadingText,
          PrefetchHooks Function()
        > {
  $$ReadingTextsTableTableManager(_$AppDatabase db, $ReadingTextsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingTextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingTextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingTextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<String> contenido = const Value.absent(),
                Value<String> nivel = const Value.absent(),
                Value<int> totalPalabras = const Value.absent(),
              }) => ReadingTextsCompanion(
                id: id,
                titulo: titulo,
                contenido: contenido,
                nivel: nivel,
                totalPalabras: totalPalabras,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String titulo,
                required String contenido,
                required String nivel,
                required int totalPalabras,
              }) => ReadingTextsCompanion.insert(
                id: id,
                titulo: titulo,
                contenido: contenido,
                nivel: nivel,
                totalPalabras: totalPalabras,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingTextsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingTextsTable,
      ReadingText,
      $$ReadingTextsTableFilterComposer,
      $$ReadingTextsTableOrderingComposer,
      $$ReadingTextsTableAnnotationComposer,
      $$ReadingTextsTableCreateCompanionBuilder,
      $$ReadingTextsTableUpdateCompanionBuilder,
      (
        ReadingText,
        BaseReferences<_$AppDatabase, $ReadingTextsTable, ReadingText>,
      ),
      ReadingText,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db, _db.students);
  $$AssessmentSessionsTableTableManager get assessmentSessions =>
      $$AssessmentSessionsTableTableManager(_db, _db.assessmentSessions);
  $$ReadingTextsTableTableManager get readingTexts =>
      $$ReadingTextsTableTableManager(_db, _db.readingTexts);
}
