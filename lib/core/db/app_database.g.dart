// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String? value;
  const Setting({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  Setting copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => Setting(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RiveElementsTable extends RiveElements
    with TableInfo<$RiveElementsTable, RiveElement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RiveElementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMachineMeta = const VerificationMeta(
    'stateMachine',
  );
  @override
  late final GeneratedColumn<String> stateMachine = GeneratedColumn<String>(
    'state_machine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('FaceSm'),
  );
  static const VerificationMeta _artboardMeta = const VerificationMeta(
    'artboard',
  );
  @override
  late final GeneratedColumn<String> artboard = GeneratedColumn<String>(
    'artboard',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fallbackAssetMeta = const VerificationMeta(
    'fallbackAsset',
  );
  @override
  late final GeneratedColumn<String> fallbackAsset = GeneratedColumn<String>(
    'fallback_asset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expressionConfigMeta = const VerificationMeta(
    'expressionConfig',
  );
  @override
  late final GeneratedColumn<String> expressionConfig = GeneratedColumn<String>(
    'expression_config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localRivPathMeta = const VerificationMeta(
    'localRivPath',
  );
  @override
  late final GeneratedColumn<String> localRivPath = GeneratedColumn<String>(
    'local_riv_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    name,
    category,
    stateMachine,
    artboard,
    fallbackAsset,
    expressionConfig,
    tags,
    displayOrder,
    isActive,
    contentHash,
    localRivPath,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rive_elements';
  @override
  VerificationContext validateIntegrity(
    Insertable<RiveElement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('state_machine')) {
      context.handle(
        _stateMachineMeta,
        stateMachine.isAcceptableOrUnknown(
          data['state_machine']!,
          _stateMachineMeta,
        ),
      );
    }
    if (data.containsKey('artboard')) {
      context.handle(
        _artboardMeta,
        artboard.isAcceptableOrUnknown(data['artboard']!, _artboardMeta),
      );
    }
    if (data.containsKey('fallback_asset')) {
      context.handle(
        _fallbackAssetMeta,
        fallbackAsset.isAcceptableOrUnknown(
          data['fallback_asset']!,
          _fallbackAssetMeta,
        ),
      );
    }
    if (data.containsKey('expression_config')) {
      context.handle(
        _expressionConfigMeta,
        expressionConfig.isAcceptableOrUnknown(
          data['expression_config']!,
          _expressionConfigMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('local_riv_path')) {
      context.handle(
        _localRivPathMeta,
        localRivPath.isAcceptableOrUnknown(
          data['local_riv_path']!,
          _localRivPathMeta,
        ),
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
  RiveElement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RiveElement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      stateMachine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_machine'],
      )!,
      artboard: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artboard'],
      ),
      fallbackAsset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fallback_asset'],
      ),
      expressionConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression_config'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      localRivPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_riv_path'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $RiveElementsTable createAlias(String alias) {
    return $RiveElementsTable(attachedDatabase, alias);
  }
}

class RiveElement extends DataClass implements Insertable<RiveElement> {
  final String id;
  final String name;
  final String category;
  final String stateMachine;
  final String? artboard;
  final String? fallbackAsset;
  final String expressionConfig;
  final String tags;
  final int displayOrder;
  final bool isActive;
  final String? contentHash;
  final String? localRivPath;
  final DateTime? syncedAt;
  const RiveElement({
    required this.id,
    required this.name,
    required this.category,
    required this.stateMachine,
    this.artboard,
    this.fallbackAsset,
    required this.expressionConfig,
    required this.tags,
    required this.displayOrder,
    required this.isActive,
    this.contentHash,
    this.localRivPath,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['state_machine'] = Variable<String>(stateMachine);
    if (!nullToAbsent || artboard != null) {
      map['artboard'] = Variable<String>(artboard);
    }
    if (!nullToAbsent || fallbackAsset != null) {
      map['fallback_asset'] = Variable<String>(fallbackAsset);
    }
    map['expression_config'] = Variable<String>(expressionConfig);
    map['tags'] = Variable<String>(tags);
    map['display_order'] = Variable<int>(displayOrder);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || localRivPath != null) {
      map['local_riv_path'] = Variable<String>(localRivPath);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  RiveElementsCompanion toCompanion(bool nullToAbsent) {
    return RiveElementsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      stateMachine: Value(stateMachine),
      artboard: artboard == null && nullToAbsent
          ? const Value.absent()
          : Value(artboard),
      fallbackAsset: fallbackAsset == null && nullToAbsent
          ? const Value.absent()
          : Value(fallbackAsset),
      expressionConfig: Value(expressionConfig),
      tags: Value(tags),
      displayOrder: Value(displayOrder),
      isActive: Value(isActive),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      localRivPath: localRivPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localRivPath),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory RiveElement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RiveElement(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      stateMachine: serializer.fromJson<String>(json['stateMachine']),
      artboard: serializer.fromJson<String?>(json['artboard']),
      fallbackAsset: serializer.fromJson<String?>(json['fallbackAsset']),
      expressionConfig: serializer.fromJson<String>(json['expressionConfig']),
      tags: serializer.fromJson<String>(json['tags']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      localRivPath: serializer.fromJson<String?>(json['localRivPath']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'stateMachine': serializer.toJson<String>(stateMachine),
      'artboard': serializer.toJson<String?>(artboard),
      'fallbackAsset': serializer.toJson<String?>(fallbackAsset),
      'expressionConfig': serializer.toJson<String>(expressionConfig),
      'tags': serializer.toJson<String>(tags),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'contentHash': serializer.toJson<String?>(contentHash),
      'localRivPath': serializer.toJson<String?>(localRivPath),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  RiveElement copyWith({
    String? id,
    String? name,
    String? category,
    String? stateMachine,
    Value<String?> artboard = const Value.absent(),
    Value<String?> fallbackAsset = const Value.absent(),
    String? expressionConfig,
    String? tags,
    int? displayOrder,
    bool? isActive,
    Value<String?> contentHash = const Value.absent(),
    Value<String?> localRivPath = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => RiveElement(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    stateMachine: stateMachine ?? this.stateMachine,
    artboard: artboard.present ? artboard.value : this.artboard,
    fallbackAsset: fallbackAsset.present
        ? fallbackAsset.value
        : this.fallbackAsset,
    expressionConfig: expressionConfig ?? this.expressionConfig,
    tags: tags ?? this.tags,
    displayOrder: displayOrder ?? this.displayOrder,
    isActive: isActive ?? this.isActive,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    localRivPath: localRivPath.present ? localRivPath.value : this.localRivPath,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  RiveElement copyWithCompanion(RiveElementsCompanion data) {
    return RiveElement(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      stateMachine: data.stateMachine.present
          ? data.stateMachine.value
          : this.stateMachine,
      artboard: data.artboard.present ? data.artboard.value : this.artboard,
      fallbackAsset: data.fallbackAsset.present
          ? data.fallbackAsset.value
          : this.fallbackAsset,
      expressionConfig: data.expressionConfig.present
          ? data.expressionConfig.value
          : this.expressionConfig,
      tags: data.tags.present ? data.tags.value : this.tags,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      localRivPath: data.localRivPath.present
          ? data.localRivPath.value
          : this.localRivPath,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RiveElement(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('stateMachine: $stateMachine, ')
          ..write('artboard: $artboard, ')
          ..write('fallbackAsset: $fallbackAsset, ')
          ..write('expressionConfig: $expressionConfig, ')
          ..write('tags: $tags, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('isActive: $isActive, ')
          ..write('contentHash: $contentHash, ')
          ..write('localRivPath: $localRivPath, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    stateMachine,
    artboard,
    fallbackAsset,
    expressionConfig,
    tags,
    displayOrder,
    isActive,
    contentHash,
    localRivPath,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RiveElement &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.stateMachine == this.stateMachine &&
          other.artboard == this.artboard &&
          other.fallbackAsset == this.fallbackAsset &&
          other.expressionConfig == this.expressionConfig &&
          other.tags == this.tags &&
          other.displayOrder == this.displayOrder &&
          other.isActive == this.isActive &&
          other.contentHash == this.contentHash &&
          other.localRivPath == this.localRivPath &&
          other.syncedAt == this.syncedAt);
}

class RiveElementsCompanion extends UpdateCompanion<RiveElement> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String> stateMachine;
  final Value<String?> artboard;
  final Value<String?> fallbackAsset;
  final Value<String> expressionConfig;
  final Value<String> tags;
  final Value<int> displayOrder;
  final Value<bool> isActive;
  final Value<String?> contentHash;
  final Value<String?> localRivPath;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const RiveElementsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.stateMachine = const Value.absent(),
    this.artboard = const Value.absent(),
    this.fallbackAsset = const Value.absent(),
    this.expressionConfig = const Value.absent(),
    this.tags = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.localRivPath = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RiveElementsCompanion.insert({
    required String id,
    required String name,
    required String category,
    this.stateMachine = const Value.absent(),
    this.artboard = const Value.absent(),
    this.fallbackAsset = const Value.absent(),
    this.expressionConfig = const Value.absent(),
    this.tags = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.localRivPath = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       category = Value(category);
  static Insertable<RiveElement> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? stateMachine,
    Expression<String>? artboard,
    Expression<String>? fallbackAsset,
    Expression<String>? expressionConfig,
    Expression<String>? tags,
    Expression<int>? displayOrder,
    Expression<bool>? isActive,
    Expression<String>? contentHash,
    Expression<String>? localRivPath,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (stateMachine != null) 'state_machine': stateMachine,
      if (artboard != null) 'artboard': artboard,
      if (fallbackAsset != null) 'fallback_asset': fallbackAsset,
      if (expressionConfig != null) 'expression_config': expressionConfig,
      if (tags != null) 'tags': tags,
      if (displayOrder != null) 'display_order': displayOrder,
      if (isActive != null) 'is_active': isActive,
      if (contentHash != null) 'content_hash': contentHash,
      if (localRivPath != null) 'local_riv_path': localRivPath,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RiveElementsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String>? stateMachine,
    Value<String?>? artboard,
    Value<String?>? fallbackAsset,
    Value<String>? expressionConfig,
    Value<String>? tags,
    Value<int>? displayOrder,
    Value<bool>? isActive,
    Value<String?>? contentHash,
    Value<String?>? localRivPath,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return RiveElementsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      stateMachine: stateMachine ?? this.stateMachine,
      artboard: artboard ?? this.artboard,
      fallbackAsset: fallbackAsset ?? this.fallbackAsset,
      expressionConfig: expressionConfig ?? this.expressionConfig,
      tags: tags ?? this.tags,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      contentHash: contentHash ?? this.contentHash,
      localRivPath: localRivPath ?? this.localRivPath,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (stateMachine.present) {
      map['state_machine'] = Variable<String>(stateMachine.value);
    }
    if (artboard.present) {
      map['artboard'] = Variable<String>(artboard.value);
    }
    if (fallbackAsset.present) {
      map['fallback_asset'] = Variable<String>(fallbackAsset.value);
    }
    if (expressionConfig.present) {
      map['expression_config'] = Variable<String>(expressionConfig.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (localRivPath.present) {
      map['local_riv_path'] = Variable<String>(localRivPath.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RiveElementsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('stateMachine: $stateMachine, ')
          ..write('artboard: $artboard, ')
          ..write('fallbackAsset: $fallbackAsset, ')
          ..write('expressionConfig: $expressionConfig, ')
          ..write('tags: $tags, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('isActive: $isActive, ')
          ..write('contentHash: $contentHash, ')
          ..write('localRivPath: $localRivPath, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $RiveElementsTable riveElements = $RiveElementsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [settings, riveElements];
}

typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$RiveElementsTableCreateCompanionBuilder =
    RiveElementsCompanion Function({
      required String id,
      required String name,
      required String category,
      Value<String> stateMachine,
      Value<String?> artboard,
      Value<String?> fallbackAsset,
      Value<String> expressionConfig,
      Value<String> tags,
      Value<int> displayOrder,
      Value<bool> isActive,
      Value<String?> contentHash,
      Value<String?> localRivPath,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$RiveElementsTableUpdateCompanionBuilder =
    RiveElementsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> category,
      Value<String> stateMachine,
      Value<String?> artboard,
      Value<String?> fallbackAsset,
      Value<String> expressionConfig,
      Value<String> tags,
      Value<int> displayOrder,
      Value<bool> isActive,
      Value<String?> contentHash,
      Value<String?> localRivPath,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$RiveElementsTableFilterComposer
    extends Composer<_$AppDatabase, $RiveElementsTable> {
  $$RiveElementsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateMachine => $composableBuilder(
    column: $table.stateMachine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artboard => $composableBuilder(
    column: $table.artboard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fallbackAsset => $composableBuilder(
    column: $table.fallbackAsset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expressionConfig => $composableBuilder(
    column: $table.expressionConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localRivPath => $composableBuilder(
    column: $table.localRivPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RiveElementsTableOrderingComposer
    extends Composer<_$AppDatabase, $RiveElementsTable> {
  $$RiveElementsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateMachine => $composableBuilder(
    column: $table.stateMachine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artboard => $composableBuilder(
    column: $table.artboard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fallbackAsset => $composableBuilder(
    column: $table.fallbackAsset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expressionConfig => $composableBuilder(
    column: $table.expressionConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localRivPath => $composableBuilder(
    column: $table.localRivPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RiveElementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RiveElementsTable> {
  $$RiveElementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get stateMachine => $composableBuilder(
    column: $table.stateMachine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artboard =>
      $composableBuilder(column: $table.artboard, builder: (column) => column);

  GeneratedColumn<String> get fallbackAsset => $composableBuilder(
    column: $table.fallbackAsset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expressionConfig => $composableBuilder(
    column: $table.expressionConfig,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localRivPath => $composableBuilder(
    column: $table.localRivPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$RiveElementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RiveElementsTable,
          RiveElement,
          $$RiveElementsTableFilterComposer,
          $$RiveElementsTableOrderingComposer,
          $$RiveElementsTableAnnotationComposer,
          $$RiveElementsTableCreateCompanionBuilder,
          $$RiveElementsTableUpdateCompanionBuilder,
          (
            RiveElement,
            BaseReferences<_$AppDatabase, $RiveElementsTable, RiveElement>,
          ),
          RiveElement,
          PrefetchHooks Function()
        > {
  $$RiveElementsTableTableManager(_$AppDatabase db, $RiveElementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RiveElementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RiveElementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RiveElementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> stateMachine = const Value.absent(),
                Value<String?> artboard = const Value.absent(),
                Value<String?> fallbackAsset = const Value.absent(),
                Value<String> expressionConfig = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String?> localRivPath = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RiveElementsCompanion(
                id: id,
                name: name,
                category: category,
                stateMachine: stateMachine,
                artboard: artboard,
                fallbackAsset: fallbackAsset,
                expressionConfig: expressionConfig,
                tags: tags,
                displayOrder: displayOrder,
                isActive: isActive,
                contentHash: contentHash,
                localRivPath: localRivPath,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String category,
                Value<String> stateMachine = const Value.absent(),
                Value<String?> artboard = const Value.absent(),
                Value<String?> fallbackAsset = const Value.absent(),
                Value<String> expressionConfig = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<String?> localRivPath = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RiveElementsCompanion.insert(
                id: id,
                name: name,
                category: category,
                stateMachine: stateMachine,
                artboard: artboard,
                fallbackAsset: fallbackAsset,
                expressionConfig: expressionConfig,
                tags: tags,
                displayOrder: displayOrder,
                isActive: isActive,
                contentHash: contentHash,
                localRivPath: localRivPath,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RiveElementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RiveElementsTable,
      RiveElement,
      $$RiveElementsTableFilterComposer,
      $$RiveElementsTableOrderingComposer,
      $$RiveElementsTableAnnotationComposer,
      $$RiveElementsTableCreateCompanionBuilder,
      $$RiveElementsTableUpdateCompanionBuilder,
      (
        RiveElement,
        BaseReferences<_$AppDatabase, $RiveElementsTable, RiveElement>,
      ),
      RiveElement,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$RiveElementsTableTableManager get riveElements =>
      $$RiveElementsTableTableManager(_db, _db.riveElements);
}
