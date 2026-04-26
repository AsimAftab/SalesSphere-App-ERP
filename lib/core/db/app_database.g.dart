// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, UserRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    fullName,
    phone,
    organizationId,
    roleId,
    avatarUrl,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserRow extends DataClass implements Insertable<UserRow> {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? organizationId;
  final String? roleId;
  final String? avatarUrl;
  final DateTime updatedAt;
  const UserRow({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.organizationId,
    this.roleId,
    this.avatarUrl,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['full_name'] = Variable<String>(fullName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    if (!nullToAbsent || roleId != null) {
      map['role_id'] = Variable<String>(roleId);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      email: Value(email),
      fullName: Value(fullName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      roleId: roleId == null && nullToAbsent
          ? const Value.absent()
          : Value(roleId),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRow(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      fullName: serializer.fromJson<String>(json['fullName']),
      phone: serializer.fromJson<String?>(json['phone']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      roleId: serializer.fromJson<String?>(json['roleId']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'fullName': serializer.toJson<String>(fullName),
      'phone': serializer.toJson<String?>(phone),
      'organizationId': serializer.toJson<String?>(organizationId),
      'roleId': serializer.toJson<String?>(roleId),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserRow copyWith({
    String? id,
    String? email,
    String? fullName,
    Value<String?> phone = const Value.absent(),
    Value<String?> organizationId = const Value.absent(),
    Value<String?> roleId = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    DateTime? updatedAt,
  }) => UserRow(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    phone: phone.present ? phone.value : this.phone,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    roleId: roleId.present ? roleId.value : this.roleId,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserRow copyWithCompanion(UsersCompanion data) {
    return UserRow(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      phone: data.phone.present ? data.phone.value : this.phone,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRow(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('organizationId: $organizationId, ')
          ..write('roleId: $roleId, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    fullName,
    phone,
    organizationId,
    roleId,
    avatarUrl,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRow &&
          other.id == this.id &&
          other.email == this.email &&
          other.fullName == this.fullName &&
          other.phone == this.phone &&
          other.organizationId == this.organizationId &&
          other.roleId == this.roleId &&
          other.avatarUrl == this.avatarUrl &&
          other.updatedAt == this.updatedAt);
}

class UsersCompanion extends UpdateCompanion<UserRow> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> fullName;
  final Value<String?> phone;
  final Value<String?> organizationId;
  final Value<String?> roleId;
  final Value<String?> avatarUrl;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.fullName = const Value.absent(),
    this.phone = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.roleId = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String email,
    required String fullName,
    this.phone = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.roleId = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       email = Value(email),
       fullName = Value(fullName),
       updatedAt = Value(updatedAt);
  static Insertable<UserRow> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? fullName,
    Expression<String>? phone,
    Expression<String>? organizationId,
    Expression<String>? roleId,
    Expression<String>? avatarUrl,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (organizationId != null) 'organization_id': organizationId,
      if (roleId != null) 'role_id': roleId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? email,
    Value<String>? fullName,
    Value<String?>? phone,
    Value<String?>? organizationId,
    Value<String?>? roleId,
    Value<String?>? avatarUrl,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      organizationId: organizationId ?? this.organizationId,
      roleId: roleId ?? this.roleId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('organizationId: $organizationId, ')
          ..write('roleId: $roleId, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MutationOutboxTable extends MutationOutbox
    with TableInfo<$MutationOutboxTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MutationOutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localEntityIdMeta = const VerificationMeta(
    'localEntityId',
  );
  @override
  late final GeneratedColumn<String> localEntityId = GeneratedColumn<String>(
    'local_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(OutboxStatus.pending.name),
      ).withConverter<OutboxStatus>($MutationOutboxTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<ConflictPolicy, String>
  conflictPolicy =
      GeneratedColumn<String>(
        'conflict_policy',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(ConflictPolicy.lastWriteWins.name),
      ).withConverter<ConflictPolicy>(
        $MutationOutboxTable.$converterconflictPolicy,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operation,
    method,
    endpoint,
    payloadJson,
    localEntityId,
    idempotencyKey,
    attempts,
    status,
    conflictPolicy,
    lastError,
    createdAt,
    nextAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mutation_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('local_entity_id')) {
      context.handle(
        _localEntityIdMeta,
        localEntityId.isAcceptableOrUnknown(
          data['local_entity_id']!,
          _localEntityIdMeta,
        ),
      );
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      localEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_entity_id'],
      ),
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      status: $MutationOutboxTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      conflictPolicy: $MutationOutboxTable.$converterconflictPolicy.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}conflict_policy'],
        )!,
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
    );
  }

  @override
  $MutationOutboxTable createAlias(String alias) {
    return $MutationOutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxStatus, String, String> $converterstatus =
      const EnumNameConverter<OutboxStatus>(OutboxStatus.values);
  static JsonTypeConverter2<ConflictPolicy, String, String>
  $converterconflictPolicy = const EnumNameConverter<ConflictPolicy>(
    ConflictPolicy.values,
  );
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;

  /// Logical operation key — used by feature handlers to know how to apply
  /// the result back to local drift tables. e.g. `attendance.checkIn`.
  final String operation;

  /// HTTP verb, plain string (`POST`, `PATCH`, etc.).
  final String method;

  /// Endpoint path (relative to API base URL). e.g. `/attendance/check-in`.
  final String endpoint;

  /// Request body as JSON. Empty string for body-less requests.
  final String payloadJson;

  /// Optional ID of the local drift row this mutation is updating, so the
  /// repository can reconcile success/failure back to the right record.
  final String? localEntityId;

  /// Idempotency key sent to backend to dedupe retries. Auto-filled at enqueue
  /// time as a v4 UUID.
  final String idempotencyKey;
  final int attempts;
  final OutboxStatus status;
  final ConflictPolicy conflictPolicy;
  final String? lastError;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  const OutboxEntry({
    required this.id,
    required this.operation,
    required this.method,
    required this.endpoint,
    required this.payloadJson,
    this.localEntityId,
    required this.idempotencyKey,
    required this.attempts,
    required this.status,
    required this.conflictPolicy,
    this.lastError,
    required this.createdAt,
    required this.nextAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation'] = Variable<String>(operation);
    map['method'] = Variable<String>(method);
    map['endpoint'] = Variable<String>(endpoint);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || localEntityId != null) {
      map['local_entity_id'] = Variable<String>(localEntityId);
    }
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['attempts'] = Variable<int>(attempts);
    {
      map['status'] = Variable<String>(
        $MutationOutboxTable.$converterstatus.toSql(status),
      );
    }
    {
      map['conflict_policy'] = Variable<String>(
        $MutationOutboxTable.$converterconflictPolicy.toSql(conflictPolicy),
      );
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    return map;
  }

  MutationOutboxCompanion toCompanion(bool nullToAbsent) {
    return MutationOutboxCompanion(
      id: Value(id),
      operation: Value(operation),
      method: Value(method),
      endpoint: Value(endpoint),
      payloadJson: Value(payloadJson),
      localEntityId: localEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(localEntityId),
      idempotencyKey: Value(idempotencyKey),
      attempts: Value(attempts),
      status: Value(status),
      conflictPolicy: Value(conflictPolicy),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      nextAttemptAt: Value(nextAttemptAt),
    );
  }

  factory OutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      method: serializer.fromJson<String>(json['method']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      localEntityId: serializer.fromJson<String?>(json['localEntityId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      attempts: serializer.fromJson<int>(json['attempts']),
      status: $MutationOutboxTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      conflictPolicy: $MutationOutboxTable.$converterconflictPolicy.fromJson(
        serializer.fromJson<String>(json['conflictPolicy']),
      ),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation': serializer.toJson<String>(operation),
      'method': serializer.toJson<String>(method),
      'endpoint': serializer.toJson<String>(endpoint),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'localEntityId': serializer.toJson<String?>(localEntityId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'attempts': serializer.toJson<int>(attempts),
      'status': serializer.toJson<String>(
        $MutationOutboxTable.$converterstatus.toJson(status),
      ),
      'conflictPolicy': serializer.toJson<String>(
        $MutationOutboxTable.$converterconflictPolicy.toJson(conflictPolicy),
      ),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
    };
  }

  OutboxEntry copyWith({
    int? id,
    String? operation,
    String? method,
    String? endpoint,
    String? payloadJson,
    Value<String?> localEntityId = const Value.absent(),
    String? idempotencyKey,
    int? attempts,
    OutboxStatus? status,
    ConflictPolicy? conflictPolicy,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? nextAttemptAt,
  }) => OutboxEntry(
    id: id ?? this.id,
    operation: operation ?? this.operation,
    method: method ?? this.method,
    endpoint: endpoint ?? this.endpoint,
    payloadJson: payloadJson ?? this.payloadJson,
    localEntityId: localEntityId.present
        ? localEntityId.value
        : this.localEntityId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    attempts: attempts ?? this.attempts,
    status: status ?? this.status,
    conflictPolicy: conflictPolicy ?? this.conflictPolicy,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
  );
  OutboxEntry copyWithCompanion(MutationOutboxCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      method: data.method.present ? data.method.value : this.method,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      localEntityId: data.localEntityId.present
          ? data.localEntityId.value
          : this.localEntityId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      status: data.status.present ? data.status.value : this.status,
      conflictPolicy: data.conflictPolicy.present
          ? data.conflictPolicy.value
          : this.conflictPolicy,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('method: $method, ')
          ..write('endpoint: $endpoint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('localEntityId: $localEntityId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('attempts: $attempts, ')
          ..write('status: $status, ')
          ..write('conflictPolicy: $conflictPolicy, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operation,
    method,
    endpoint,
    payloadJson,
    localEntityId,
    idempotencyKey,
    attempts,
    status,
    conflictPolicy,
    lastError,
    createdAt,
    nextAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.method == this.method &&
          other.endpoint == this.endpoint &&
          other.payloadJson == this.payloadJson &&
          other.localEntityId == this.localEntityId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.attempts == this.attempts &&
          other.status == this.status &&
          other.conflictPolicy == this.conflictPolicy &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt);
}

class MutationOutboxCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> operation;
  final Value<String> method;
  final Value<String> endpoint;
  final Value<String> payloadJson;
  final Value<String?> localEntityId;
  final Value<String> idempotencyKey;
  final Value<int> attempts;
  final Value<OutboxStatus> status;
  final Value<ConflictPolicy> conflictPolicy;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> nextAttemptAt;
  const MutationOutboxCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.method = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.localEntityId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.attempts = const Value.absent(),
    this.status = const Value.absent(),
    this.conflictPolicy = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  });
  MutationOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String operation,
    required String method,
    required String endpoint,
    this.payloadJson = const Value.absent(),
    this.localEntityId = const Value.absent(),
    required String idempotencyKey,
    this.attempts = const Value.absent(),
    this.status = const Value.absent(),
    this.conflictPolicy = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  }) : operation = Value(operation),
       method = Value(method),
       endpoint = Value(endpoint),
       idempotencyKey = Value(idempotencyKey);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? operation,
    Expression<String>? method,
    Expression<String>? endpoint,
    Expression<String>? payloadJson,
    Expression<String>? localEntityId,
    Expression<String>? idempotencyKey,
    Expression<int>? attempts,
    Expression<String>? status,
    Expression<String>? conflictPolicy,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (method != null) 'method': method,
      if (endpoint != null) 'endpoint': endpoint,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (localEntityId != null) 'local_entity_id': localEntityId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (attempts != null) 'attempts': attempts,
      if (status != null) 'status': status,
      if (conflictPolicy != null) 'conflict_policy': conflictPolicy,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
    });
  }

  MutationOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? operation,
    Value<String>? method,
    Value<String>? endpoint,
    Value<String>? payloadJson,
    Value<String?>? localEntityId,
    Value<String>? idempotencyKey,
    Value<int>? attempts,
    Value<OutboxStatus>? status,
    Value<ConflictPolicy>? conflictPolicy,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? nextAttemptAt,
  }) {
    return MutationOutboxCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      method: method ?? this.method,
      endpoint: endpoint ?? this.endpoint,
      payloadJson: payloadJson ?? this.payloadJson,
      localEntityId: localEntityId ?? this.localEntityId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      conflictPolicy: conflictPolicy ?? this.conflictPolicy,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (localEntityId.present) {
      map['local_entity_id'] = Variable<String>(localEntityId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MutationOutboxTable.$converterstatus.toSql(status.value),
      );
    }
    if (conflictPolicy.present) {
      map['conflict_policy'] = Variable<String>(
        $MutationOutboxTable.$converterconflictPolicy.toSql(
          conflictPolicy.value,
        ),
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MutationOutboxCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('method: $method, ')
          ..write('endpoint: $endpoint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('localEntityId: $localEntityId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('attempts: $attempts, ')
          ..write('status: $status, ')
          ..write('conflictPolicy: $conflictPolicy, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _resourceMeta = const VerificationMeta(
    'resource',
  );
  @override
  late final GeneratedColumn<String> resource = GeneratedColumn<String>(
    'resource',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [resource, cursor, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('resource')) {
      context.handle(
        _resourceMeta,
        resource.isAcceptableOrUnknown(data['resource']!, _resourceMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {resource};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      resource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String resource;
  final String? cursor;
  final DateTime? lastSyncedAt;
  const SyncStateRow({required this.resource, this.cursor, this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['resource'] = Variable<String>(resource);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      resource: Value(resource),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      resource: serializer.fromJson<String>(json['resource']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'resource': serializer.toJson<String>(resource),
      'cursor': serializer.toJson<String?>(cursor),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  SyncStateRow copyWith({
    String? resource,
    Value<String?> cursor = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => SyncStateRow(
    resource: resource ?? this.resource,
    cursor: cursor.present ? cursor.value : this.cursor,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      resource: data.resource.present ? data.resource.value : this.resource,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('resource: $resource, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(resource, cursor, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.resource == this.resource &&
          other.cursor == this.cursor &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> resource;
  final Value<String?> cursor;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.resource = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String resource,
    this.cursor = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : resource = Value(resource);
  static Insertable<SyncStateRow> custom({
    Expression<String>? resource,
    Expression<String>? cursor,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (resource != null) 'resource': resource,
      if (cursor != null) 'cursor': cursor,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? resource,
    Value<String?>? cursor,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      resource: resource ?? this.resource,
      cursor: cursor ?? this.cursor,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (resource.present) {
      map['resource'] = Variable<String>(resource.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('resource: $resource, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $MutationOutboxTable mutationOutbox = $MutationOutboxTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final UsersDao usersDao = UsersDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final SyncStateDao syncStateDao = SyncStateDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    mutationOutbox,
    syncState,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required String id,
      required String email,
      required String fullName,
      Value<String?> phone,
      Value<String?> organizationId,
      Value<String?> roleId,
      Value<String?> avatarUrl,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<String> email,
      Value<String> fullName,
      Value<String?> phone,
      Value<String?> organizationId,
      Value<String?> roleId,
      Value<String?> avatarUrl,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleId => $composableBuilder(
    column: $table.roleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleId => $composableBuilder(
    column: $table.roleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roleId =>
      $composableBuilder(column: $table.roleId, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          UserRow,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (UserRow, BaseReferences<_$AppDatabase, $UsersTable, UserRow>),
          UserRow,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<String?> roleId = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                email: email,
                fullName: fullName,
                phone: phone,
                organizationId: organizationId,
                roleId: roleId,
                avatarUrl: avatarUrl,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String email,
                required String fullName,
                Value<String?> phone = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<String?> roleId = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                email: email,
                fullName: fullName,
                phone: phone,
                organizationId: organizationId,
                roleId: roleId,
                avatarUrl: avatarUrl,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      UserRow,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (UserRow, BaseReferences<_$AppDatabase, $UsersTable, UserRow>),
      UserRow,
      PrefetchHooks Function()
    >;
typedef $$MutationOutboxTableCreateCompanionBuilder =
    MutationOutboxCompanion Function({
      Value<int> id,
      required String operation,
      required String method,
      required String endpoint,
      Value<String> payloadJson,
      Value<String?> localEntityId,
      required String idempotencyKey,
      Value<int> attempts,
      Value<OutboxStatus> status,
      Value<ConflictPolicy> conflictPolicy,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> nextAttemptAt,
    });
typedef $$MutationOutboxTableUpdateCompanionBuilder =
    MutationOutboxCompanion Function({
      Value<int> id,
      Value<String> operation,
      Value<String> method,
      Value<String> endpoint,
      Value<String> payloadJson,
      Value<String?> localEntityId,
      Value<String> idempotencyKey,
      Value<int> attempts,
      Value<OutboxStatus> status,
      Value<ConflictPolicy> conflictPolicy,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> nextAttemptAt,
    });

class $$MutationOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $MutationOutboxTable> {
  $$MutationOutboxTableFilterComposer({
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

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxStatus, OutboxStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ConflictPolicy, ConflictPolicy, String>
  get conflictPolicy => $composableBuilder(
    column: $table.conflictPolicy,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MutationOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $MutationOutboxTable> {
  $$MutationOutboxTableOrderingComposer({
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

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictPolicy => $composableBuilder(
    column: $table.conflictPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MutationOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $MutationOutboxTable> {
  $$MutationOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ConflictPolicy, String> get conflictPolicy =>
      $composableBuilder(
        column: $table.conflictPolicy,
        builder: (column) => column,
      );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );
}

class $$MutationOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MutationOutboxTable,
          OutboxEntry,
          $$MutationOutboxTableFilterComposer,
          $$MutationOutboxTableOrderingComposer,
          $$MutationOutboxTableAnnotationComposer,
          $$MutationOutboxTableCreateCompanionBuilder,
          $$MutationOutboxTableUpdateCompanionBuilder,
          (
            OutboxEntry,
            BaseReferences<_$AppDatabase, $MutationOutboxTable, OutboxEntry>,
          ),
          OutboxEntry,
          PrefetchHooks Function()
        > {
  $$MutationOutboxTableTableManager(
    _$AppDatabase db,
    $MutationOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MutationOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MutationOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MutationOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> localEntityId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<OutboxStatus> status = const Value.absent(),
                Value<ConflictPolicy> conflictPolicy = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
              }) => MutationOutboxCompanion(
                id: id,
                operation: operation,
                method: method,
                endpoint: endpoint,
                payloadJson: payloadJson,
                localEntityId: localEntityId,
                idempotencyKey: idempotencyKey,
                attempts: attempts,
                status: status,
                conflictPolicy: conflictPolicy,
                lastError: lastError,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operation,
                required String method,
                required String endpoint,
                Value<String> payloadJson = const Value.absent(),
                Value<String?> localEntityId = const Value.absent(),
                required String idempotencyKey,
                Value<int> attempts = const Value.absent(),
                Value<OutboxStatus> status = const Value.absent(),
                Value<ConflictPolicy> conflictPolicy = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
              }) => MutationOutboxCompanion.insert(
                id: id,
                operation: operation,
                method: method,
                endpoint: endpoint,
                payloadJson: payloadJson,
                localEntityId: localEntityId,
                idempotencyKey: idempotencyKey,
                attempts: attempts,
                status: status,
                conflictPolicy: conflictPolicy,
                lastError: lastError,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MutationOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MutationOutboxTable,
      OutboxEntry,
      $$MutationOutboxTableFilterComposer,
      $$MutationOutboxTableOrderingComposer,
      $$MutationOutboxTableAnnotationComposer,
      $$MutationOutboxTableCreateCompanionBuilder,
      $$MutationOutboxTableUpdateCompanionBuilder,
      (
        OutboxEntry,
        BaseReferences<_$AppDatabase, $MutationOutboxTable, OutboxEntry>,
      ),
      OutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String resource,
      Value<String?> cursor,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> resource,
      Value<String?> cursor,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get resource => $composableBuilder(
    column: $table.resource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get resource => $composableBuilder(
    column: $table.resource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get resource =>
      $composableBuilder(column: $table.resource, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> resource = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                resource: resource,
                cursor: cursor,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String resource,
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                resource: resource,
                cursor: cursor,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$MutationOutboxTableTableManager get mutationOutbox =>
      $$MutationOutboxTableTableManager(_db, _db.mutationOutbox);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
