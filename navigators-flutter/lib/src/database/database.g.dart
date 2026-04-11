// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VotersTable extends Voters with TableInfo<$VotersTable, Voter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VotersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turfIdMeta = const VerificationMeta('turfId');
  @override
  late final GeneratedColumn<String> turfId = GeneratedColumn<String>(
    'turf_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _middleNameMeta = const VerificationMeta(
    'middleName',
  );
  @override
  late final GeneratedColumn<String> middleName = GeneratedColumn<String>(
    'middle_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
    'suffix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yearOfBirthMeta = const VerificationMeta(
    'yearOfBirth',
  );
  @override
  late final GeneratedColumn<int> yearOfBirth = GeneratedColumn<int>(
    'year_of_birth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resStreetAddressMeta = const VerificationMeta(
    'resStreetAddress',
  );
  @override
  late final GeneratedColumn<String> resStreetAddress = GeneratedColumn<String>(
    'res_street_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _resCityMeta = const VerificationMeta(
    'resCity',
  );
  @override
  late final GeneratedColumn<String> resCity = GeneratedColumn<String>(
    'res_city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _resStateMeta = const VerificationMeta(
    'resState',
  );
  @override
  late final GeneratedColumn<String> resState = GeneratedColumn<String>(
    'res_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _resZipMeta = const VerificationMeta('resZip');
  @override
  late final GeneratedColumn<String> resZip = GeneratedColumn<String>(
    'res_zip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _partyMeta = const VerificationMeta('party');
  @override
  late final GeneratedColumn<String> party = GeneratedColumn<String>(
    'party',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _votingHistoryMeta = const VerificationMeta(
    'votingHistory',
  );
  @override
  late final GeneratedColumn<String> votingHistory = GeneratedColumn<String>(
    'voting_history',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _walkSequenceMeta = const VerificationMeta(
    'walkSequence',
  );
  @override
  late final GeneratedColumn<int> walkSequence = GeneratedColumn<int>(
    'walk_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _localUpdatedAtMeta = const VerificationMeta(
    'localUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> localUpdatedAt =
      GeneratedColumn<DateTime>(
        'local_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    turfId,
    firstName,
    lastName,
    middleName,
    suffix,
    yearOfBirth,
    resStreetAddress,
    resCity,
    resState,
    resZip,
    party,
    status,
    latitude,
    longitude,
    votingHistory,
    phone,
    email,
    walkSequence,
    serverUpdatedAt,
    localUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Voter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('turf_id')) {
      context.handle(
        _turfIdMeta,
        turfId.isAcceptableOrUnknown(data['turf_id']!, _turfIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turfIdMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('middle_name')) {
      context.handle(
        _middleNameMeta,
        middleName.isAcceptableOrUnknown(data['middle_name']!, _middleNameMeta),
      );
    }
    if (data.containsKey('suffix')) {
      context.handle(
        _suffixMeta,
        suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta),
      );
    }
    if (data.containsKey('year_of_birth')) {
      context.handle(
        _yearOfBirthMeta,
        yearOfBirth.isAcceptableOrUnknown(
          data['year_of_birth']!,
          _yearOfBirthMeta,
        ),
      );
    }
    if (data.containsKey('res_street_address')) {
      context.handle(
        _resStreetAddressMeta,
        resStreetAddress.isAcceptableOrUnknown(
          data['res_street_address']!,
          _resStreetAddressMeta,
        ),
      );
    }
    if (data.containsKey('res_city')) {
      context.handle(
        _resCityMeta,
        resCity.isAcceptableOrUnknown(data['res_city']!, _resCityMeta),
      );
    }
    if (data.containsKey('res_state')) {
      context.handle(
        _resStateMeta,
        resState.isAcceptableOrUnknown(data['res_state']!, _resStateMeta),
      );
    }
    if (data.containsKey('res_zip')) {
      context.handle(
        _resZipMeta,
        resZip.isAcceptableOrUnknown(data['res_zip']!, _resZipMeta),
      );
    }
    if (data.containsKey('party')) {
      context.handle(
        _partyMeta,
        party.isAcceptableOrUnknown(data['party']!, _partyMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('voting_history')) {
      context.handle(
        _votingHistoryMeta,
        votingHistory.isAcceptableOrUnknown(
          data['voting_history']!,
          _votingHistoryMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('walk_sequence')) {
      context.handle(
        _walkSequenceMeta,
        walkSequence.isAcceptableOrUnknown(
          data['walk_sequence']!,
          _walkSequenceMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverUpdatedAtMeta);
    }
    if (data.containsKey('local_updated_at')) {
      context.handle(
        _localUpdatedAtMeta,
        localUpdatedAt.isAcceptableOrUnknown(
          data['local_updated_at']!,
          _localUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localUpdatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Voter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Voter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      turfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turf_id'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      middleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}middle_name'],
      )!,
      suffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suffix'],
      )!,
      yearOfBirth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year_of_birth'],
      ),
      resStreetAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}res_street_address'],
      )!,
      resCity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}res_city'],
      )!,
      resState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}res_state'],
      )!,
      resZip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}res_zip'],
      )!,
      party: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      votingHistory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voting_history'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      walkSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}walk_sequence'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      )!,
      localUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}local_updated_at'],
      )!,
    );
  }

  @override
  $VotersTable createAlias(String alias) {
    return $VotersTable(attachedDatabase, alias);
  }
}

class Voter extends DataClass implements Insertable<Voter> {
  final String id;
  final String turfId;
  final String firstName;
  final String lastName;
  final String middleName;
  final String suffix;
  final int? yearOfBirth;
  final String resStreetAddress;
  final String resCity;
  final String resState;
  final String resZip;
  final String party;
  final String status;
  final double latitude;
  final double longitude;
  final String votingHistory;
  final String phone;
  final String email;
  final int walkSequence;
  final DateTime serverUpdatedAt;
  final DateTime localUpdatedAt;
  const Voter({
    required this.id,
    required this.turfId,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.suffix,
    this.yearOfBirth,
    required this.resStreetAddress,
    required this.resCity,
    required this.resState,
    required this.resZip,
    required this.party,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.votingHistory,
    required this.phone,
    required this.email,
    required this.walkSequence,
    required this.serverUpdatedAt,
    required this.localUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['turf_id'] = Variable<String>(turfId);
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    map['middle_name'] = Variable<String>(middleName);
    map['suffix'] = Variable<String>(suffix);
    if (!nullToAbsent || yearOfBirth != null) {
      map['year_of_birth'] = Variable<int>(yearOfBirth);
    }
    map['res_street_address'] = Variable<String>(resStreetAddress);
    map['res_city'] = Variable<String>(resCity);
    map['res_state'] = Variable<String>(resState);
    map['res_zip'] = Variable<String>(resZip);
    map['party'] = Variable<String>(party);
    map['status'] = Variable<String>(status);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['voting_history'] = Variable<String>(votingHistory);
    map['phone'] = Variable<String>(phone);
    map['email'] = Variable<String>(email);
    map['walk_sequence'] = Variable<int>(walkSequence);
    map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    map['local_updated_at'] = Variable<DateTime>(localUpdatedAt);
    return map;
  }

  VotersCompanion toCompanion(bool nullToAbsent) {
    return VotersCompanion(
      id: Value(id),
      turfId: Value(turfId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      middleName: Value(middleName),
      suffix: Value(suffix),
      yearOfBirth: yearOfBirth == null && nullToAbsent
          ? const Value.absent()
          : Value(yearOfBirth),
      resStreetAddress: Value(resStreetAddress),
      resCity: Value(resCity),
      resState: Value(resState),
      resZip: Value(resZip),
      party: Value(party),
      status: Value(status),
      latitude: Value(latitude),
      longitude: Value(longitude),
      votingHistory: Value(votingHistory),
      phone: Value(phone),
      email: Value(email),
      walkSequence: Value(walkSequence),
      serverUpdatedAt: Value(serverUpdatedAt),
      localUpdatedAt: Value(localUpdatedAt),
    );
  }

  factory Voter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Voter(
      id: serializer.fromJson<String>(json['id']),
      turfId: serializer.fromJson<String>(json['turfId']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      middleName: serializer.fromJson<String>(json['middleName']),
      suffix: serializer.fromJson<String>(json['suffix']),
      yearOfBirth: serializer.fromJson<int?>(json['yearOfBirth']),
      resStreetAddress: serializer.fromJson<String>(json['resStreetAddress']),
      resCity: serializer.fromJson<String>(json['resCity']),
      resState: serializer.fromJson<String>(json['resState']),
      resZip: serializer.fromJson<String>(json['resZip']),
      party: serializer.fromJson<String>(json['party']),
      status: serializer.fromJson<String>(json['status']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      votingHistory: serializer.fromJson<String>(json['votingHistory']),
      phone: serializer.fromJson<String>(json['phone']),
      email: serializer.fromJson<String>(json['email']),
      walkSequence: serializer.fromJson<int>(json['walkSequence']),
      serverUpdatedAt: serializer.fromJson<DateTime>(json['serverUpdatedAt']),
      localUpdatedAt: serializer.fromJson<DateTime>(json['localUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'turfId': serializer.toJson<String>(turfId),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'middleName': serializer.toJson<String>(middleName),
      'suffix': serializer.toJson<String>(suffix),
      'yearOfBirth': serializer.toJson<int?>(yearOfBirth),
      'resStreetAddress': serializer.toJson<String>(resStreetAddress),
      'resCity': serializer.toJson<String>(resCity),
      'resState': serializer.toJson<String>(resState),
      'resZip': serializer.toJson<String>(resZip),
      'party': serializer.toJson<String>(party),
      'status': serializer.toJson<String>(status),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'votingHistory': serializer.toJson<String>(votingHistory),
      'phone': serializer.toJson<String>(phone),
      'email': serializer.toJson<String>(email),
      'walkSequence': serializer.toJson<int>(walkSequence),
      'serverUpdatedAt': serializer.toJson<DateTime>(serverUpdatedAt),
      'localUpdatedAt': serializer.toJson<DateTime>(localUpdatedAt),
    };
  }

  Voter copyWith({
    String? id,
    String? turfId,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    Value<int?> yearOfBirth = const Value.absent(),
    String? resStreetAddress,
    String? resCity,
    String? resState,
    String? resZip,
    String? party,
    String? status,
    double? latitude,
    double? longitude,
    String? votingHistory,
    String? phone,
    String? email,
    int? walkSequence,
    DateTime? serverUpdatedAt,
    DateTime? localUpdatedAt,
  }) => Voter(
    id: id ?? this.id,
    turfId: turfId ?? this.turfId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    middleName: middleName ?? this.middleName,
    suffix: suffix ?? this.suffix,
    yearOfBirth: yearOfBirth.present ? yearOfBirth.value : this.yearOfBirth,
    resStreetAddress: resStreetAddress ?? this.resStreetAddress,
    resCity: resCity ?? this.resCity,
    resState: resState ?? this.resState,
    resZip: resZip ?? this.resZip,
    party: party ?? this.party,
    status: status ?? this.status,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    votingHistory: votingHistory ?? this.votingHistory,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    walkSequence: walkSequence ?? this.walkSequence,
    serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
  );
  Voter copyWithCompanion(VotersCompanion data) {
    return Voter(
      id: data.id.present ? data.id.value : this.id,
      turfId: data.turfId.present ? data.turfId.value : this.turfId,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      middleName: data.middleName.present
          ? data.middleName.value
          : this.middleName,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      yearOfBirth: data.yearOfBirth.present
          ? data.yearOfBirth.value
          : this.yearOfBirth,
      resStreetAddress: data.resStreetAddress.present
          ? data.resStreetAddress.value
          : this.resStreetAddress,
      resCity: data.resCity.present ? data.resCity.value : this.resCity,
      resState: data.resState.present ? data.resState.value : this.resState,
      resZip: data.resZip.present ? data.resZip.value : this.resZip,
      party: data.party.present ? data.party.value : this.party,
      status: data.status.present ? data.status.value : this.status,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      votingHistory: data.votingHistory.present
          ? data.votingHistory.value
          : this.votingHistory,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      walkSequence: data.walkSequence.present
          ? data.walkSequence.value
          : this.walkSequence,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      localUpdatedAt: data.localUpdatedAt.present
          ? data.localUpdatedAt.value
          : this.localUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Voter(')
          ..write('id: $id, ')
          ..write('turfId: $turfId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('middleName: $middleName, ')
          ..write('suffix: $suffix, ')
          ..write('yearOfBirth: $yearOfBirth, ')
          ..write('resStreetAddress: $resStreetAddress, ')
          ..write('resCity: $resCity, ')
          ..write('resState: $resState, ')
          ..write('resZip: $resZip, ')
          ..write('party: $party, ')
          ..write('status: $status, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('votingHistory: $votingHistory, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('walkSequence: $walkSequence, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('localUpdatedAt: $localUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    turfId,
    firstName,
    lastName,
    middleName,
    suffix,
    yearOfBirth,
    resStreetAddress,
    resCity,
    resState,
    resZip,
    party,
    status,
    latitude,
    longitude,
    votingHistory,
    phone,
    email,
    walkSequence,
    serverUpdatedAt,
    localUpdatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Voter &&
          other.id == this.id &&
          other.turfId == this.turfId &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.middleName == this.middleName &&
          other.suffix == this.suffix &&
          other.yearOfBirth == this.yearOfBirth &&
          other.resStreetAddress == this.resStreetAddress &&
          other.resCity == this.resCity &&
          other.resState == this.resState &&
          other.resZip == this.resZip &&
          other.party == this.party &&
          other.status == this.status &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.votingHistory == this.votingHistory &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.walkSequence == this.walkSequence &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.localUpdatedAt == this.localUpdatedAt);
}

class VotersCompanion extends UpdateCompanion<Voter> {
  final Value<String> id;
  final Value<String> turfId;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String> middleName;
  final Value<String> suffix;
  final Value<int?> yearOfBirth;
  final Value<String> resStreetAddress;
  final Value<String> resCity;
  final Value<String> resState;
  final Value<String> resZip;
  final Value<String> party;
  final Value<String> status;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> votingHistory;
  final Value<String> phone;
  final Value<String> email;
  final Value<int> walkSequence;
  final Value<DateTime> serverUpdatedAt;
  final Value<DateTime> localUpdatedAt;
  final Value<int> rowid;
  const VotersCompanion({
    this.id = const Value.absent(),
    this.turfId = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.middleName = const Value.absent(),
    this.suffix = const Value.absent(),
    this.yearOfBirth = const Value.absent(),
    this.resStreetAddress = const Value.absent(),
    this.resCity = const Value.absent(),
    this.resState = const Value.absent(),
    this.resZip = const Value.absent(),
    this.party = const Value.absent(),
    this.status = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.votingHistory = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.walkSequence = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.localUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VotersCompanion.insert({
    required String id,
    required String turfId,
    required String firstName,
    required String lastName,
    this.middleName = const Value.absent(),
    this.suffix = const Value.absent(),
    this.yearOfBirth = const Value.absent(),
    this.resStreetAddress = const Value.absent(),
    this.resCity = const Value.absent(),
    this.resState = const Value.absent(),
    this.resZip = const Value.absent(),
    this.party = const Value.absent(),
    this.status = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.votingHistory = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.walkSequence = const Value.absent(),
    required DateTime serverUpdatedAt,
    required DateTime localUpdatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       turfId = Value(turfId),
       firstName = Value(firstName),
       lastName = Value(lastName),
       serverUpdatedAt = Value(serverUpdatedAt),
       localUpdatedAt = Value(localUpdatedAt);
  static Insertable<Voter> custom({
    Expression<String>? id,
    Expression<String>? turfId,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? middleName,
    Expression<String>? suffix,
    Expression<int>? yearOfBirth,
    Expression<String>? resStreetAddress,
    Expression<String>? resCity,
    Expression<String>? resState,
    Expression<String>? resZip,
    Expression<String>? party,
    Expression<String>? status,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? votingHistory,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<int>? walkSequence,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? localUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (turfId != null) 'turf_id': turfId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (middleName != null) 'middle_name': middleName,
      if (suffix != null) 'suffix': suffix,
      if (yearOfBirth != null) 'year_of_birth': yearOfBirth,
      if (resStreetAddress != null) 'res_street_address': resStreetAddress,
      if (resCity != null) 'res_city': resCity,
      if (resState != null) 'res_state': resState,
      if (resZip != null) 'res_zip': resZip,
      if (party != null) 'party': party,
      if (status != null) 'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (votingHistory != null) 'voting_history': votingHistory,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (walkSequence != null) 'walk_sequence': walkSequence,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VotersCompanion copyWith({
    Value<String>? id,
    Value<String>? turfId,
    Value<String>? firstName,
    Value<String>? lastName,
    Value<String>? middleName,
    Value<String>? suffix,
    Value<int?>? yearOfBirth,
    Value<String>? resStreetAddress,
    Value<String>? resCity,
    Value<String>? resState,
    Value<String>? resZip,
    Value<String>? party,
    Value<String>? status,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? votingHistory,
    Value<String>? phone,
    Value<String>? email,
    Value<int>? walkSequence,
    Value<DateTime>? serverUpdatedAt,
    Value<DateTime>? localUpdatedAt,
    Value<int>? rowid,
  }) {
    return VotersCompanion(
      id: id ?? this.id,
      turfId: turfId ?? this.turfId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      suffix: suffix ?? this.suffix,
      yearOfBirth: yearOfBirth ?? this.yearOfBirth,
      resStreetAddress: resStreetAddress ?? this.resStreetAddress,
      resCity: resCity ?? this.resCity,
      resState: resState ?? this.resState,
      resZip: resZip ?? this.resZip,
      party: party ?? this.party,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      votingHistory: votingHistory ?? this.votingHistory,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      walkSequence: walkSequence ?? this.walkSequence,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (turfId.present) {
      map['turf_id'] = Variable<String>(turfId.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (middleName.present) {
      map['middle_name'] = Variable<String>(middleName.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (yearOfBirth.present) {
      map['year_of_birth'] = Variable<int>(yearOfBirth.value);
    }
    if (resStreetAddress.present) {
      map['res_street_address'] = Variable<String>(resStreetAddress.value);
    }
    if (resCity.present) {
      map['res_city'] = Variable<String>(resCity.value);
    }
    if (resState.present) {
      map['res_state'] = Variable<String>(resState.value);
    }
    if (resZip.present) {
      map['res_zip'] = Variable<String>(resZip.value);
    }
    if (party.present) {
      map['party'] = Variable<String>(party.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (votingHistory.present) {
      map['voting_history'] = Variable<String>(votingHistory.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (walkSequence.present) {
      map['walk_sequence'] = Variable<int>(walkSequence.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (localUpdatedAt.present) {
      map['local_updated_at'] = Variable<DateTime>(localUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VotersCompanion(')
          ..write('id: $id, ')
          ..write('turfId: $turfId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('middleName: $middleName, ')
          ..write('suffix: $suffix, ')
          ..write('yearOfBirth: $yearOfBirth, ')
          ..write('resStreetAddress: $resStreetAddress, ')
          ..write('resCity: $resCity, ')
          ..write('resState: $resState, ')
          ..write('resZip: $resZip, ')
          ..write('party: $party, ')
          ..write('status: $status, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('votingHistory: $votingHistory, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('walkSequence: $walkSequence, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('localUpdatedAt: $localUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactLogsTable extends ContactLogs
    with TableInfo<$ContactLogsTable, ContactLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voterIdMeta = const VerificationMeta(
    'voterId',
  );
  @override
  late final GeneratedColumn<String> voterId = GeneratedColumn<String>(
    'voter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turfIdMeta = const VerificationMeta('turfId');
  @override
  late final GeneratedColumn<String> turfId = GeneratedColumn<String>(
    'turf_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactTypeMeta = const VerificationMeta(
    'contactType',
  );
  @override
  late final GeneratedColumn<String> contactType = GeneratedColumn<String>(
    'contact_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _doorStatusMeta = const VerificationMeta(
    'doorStatus',
  );
  @override
  late final GeneratedColumn<String> doorStatus = GeneratedColumn<String>(
    'door_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sentimentMeta = const VerificationMeta(
    'sentiment',
  );
  @override
  late final GeneratedColumn<int> sentiment = GeneratedColumn<int>(
    'sentiment',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
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
    voterId,
    turfId,
    userId,
    contactType,
    outcome,
    notes,
    doorStatus,
    sentiment,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voter_id')) {
      context.handle(
        _voterIdMeta,
        voterId.isAcceptableOrUnknown(data['voter_id']!, _voterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_voterIdMeta);
    }
    if (data.containsKey('turf_id')) {
      context.handle(
        _turfIdMeta,
        turfId.isAcceptableOrUnknown(data['turf_id']!, _turfIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turfIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('contact_type')) {
      context.handle(
        _contactTypeMeta,
        contactType.isAcceptableOrUnknown(
          data['contact_type']!,
          _contactTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contactTypeMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('door_status')) {
      context.handle(
        _doorStatusMeta,
        doorStatus.isAcceptableOrUnknown(data['door_status']!, _doorStatusMeta),
      );
    }
    if (data.containsKey('sentiment')) {
      context.handle(
        _sentimentMeta,
        sentiment.isAcceptableOrUnknown(data['sentiment']!, _sentimentMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  ContactLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voter_id'],
      )!,
      turfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turf_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      contactType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_type'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      doorStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}door_status'],
      )!,
      sentiment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentiment'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $ContactLogsTable createAlias(String alias) {
    return $ContactLogsTable(attachedDatabase, alias);
  }
}

class ContactLog extends DataClass implements Insertable<ContactLog> {
  final String id;
  final String voterId;
  final String turfId;
  final String userId;
  final String contactType;
  final String outcome;
  final String notes;
  final String doorStatus;
  final int? sentiment;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const ContactLog({
    required this.id,
    required this.voterId,
    required this.turfId,
    required this.userId,
    required this.contactType,
    required this.outcome,
    required this.notes,
    required this.doorStatus,
    this.sentiment,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voter_id'] = Variable<String>(voterId);
    map['turf_id'] = Variable<String>(turfId);
    map['user_id'] = Variable<String>(userId);
    map['contact_type'] = Variable<String>(contactType);
    map['outcome'] = Variable<String>(outcome);
    map['notes'] = Variable<String>(notes);
    map['door_status'] = Variable<String>(doorStatus);
    if (!nullToAbsent || sentiment != null) {
      map['sentiment'] = Variable<int>(sentiment);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  ContactLogsCompanion toCompanion(bool nullToAbsent) {
    return ContactLogsCompanion(
      id: Value(id),
      voterId: Value(voterId),
      turfId: Value(turfId),
      userId: Value(userId),
      contactType: Value(contactType),
      outcome: Value(outcome),
      notes: Value(notes),
      doorStatus: Value(doorStatus),
      sentiment: sentiment == null && nullToAbsent
          ? const Value.absent()
          : Value(sentiment),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory ContactLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactLog(
      id: serializer.fromJson<String>(json['id']),
      voterId: serializer.fromJson<String>(json['voterId']),
      turfId: serializer.fromJson<String>(json['turfId']),
      userId: serializer.fromJson<String>(json['userId']),
      contactType: serializer.fromJson<String>(json['contactType']),
      outcome: serializer.fromJson<String>(json['outcome']),
      notes: serializer.fromJson<String>(json['notes']),
      doorStatus: serializer.fromJson<String>(json['doorStatus']),
      sentiment: serializer.fromJson<int?>(json['sentiment']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voterId': serializer.toJson<String>(voterId),
      'turfId': serializer.toJson<String>(turfId),
      'userId': serializer.toJson<String>(userId),
      'contactType': serializer.toJson<String>(contactType),
      'outcome': serializer.toJson<String>(outcome),
      'notes': serializer.toJson<String>(notes),
      'doorStatus': serializer.toJson<String>(doorStatus),
      'sentiment': serializer.toJson<int?>(sentiment),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  ContactLog copyWith({
    String? id,
    String? voterId,
    String? turfId,
    String? userId,
    String? contactType,
    String? outcome,
    String? notes,
    String? doorStatus,
    Value<int?> sentiment = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => ContactLog(
    id: id ?? this.id,
    voterId: voterId ?? this.voterId,
    turfId: turfId ?? this.turfId,
    userId: userId ?? this.userId,
    contactType: contactType ?? this.contactType,
    outcome: outcome ?? this.outcome,
    notes: notes ?? this.notes,
    doorStatus: doorStatus ?? this.doorStatus,
    sentiment: sentiment.present ? sentiment.value : this.sentiment,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  ContactLog copyWithCompanion(ContactLogsCompanion data) {
    return ContactLog(
      id: data.id.present ? data.id.value : this.id,
      voterId: data.voterId.present ? data.voterId.value : this.voterId,
      turfId: data.turfId.present ? data.turfId.value : this.turfId,
      userId: data.userId.present ? data.userId.value : this.userId,
      contactType: data.contactType.present
          ? data.contactType.value
          : this.contactType,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      notes: data.notes.present ? data.notes.value : this.notes,
      doorStatus: data.doorStatus.present
          ? data.doorStatus.value
          : this.doorStatus,
      sentiment: data.sentiment.present ? data.sentiment.value : this.sentiment,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactLog(')
          ..write('id: $id, ')
          ..write('voterId: $voterId, ')
          ..write('turfId: $turfId, ')
          ..write('userId: $userId, ')
          ..write('contactType: $contactType, ')
          ..write('outcome: $outcome, ')
          ..write('notes: $notes, ')
          ..write('doorStatus: $doorStatus, ')
          ..write('sentiment: $sentiment, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    voterId,
    turfId,
    userId,
    contactType,
    outcome,
    notes,
    doorStatus,
    sentiment,
    createdAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactLog &&
          other.id == this.id &&
          other.voterId == this.voterId &&
          other.turfId == this.turfId &&
          other.userId == this.userId &&
          other.contactType == this.contactType &&
          other.outcome == this.outcome &&
          other.notes == this.notes &&
          other.doorStatus == this.doorStatus &&
          other.sentiment == this.sentiment &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class ContactLogsCompanion extends UpdateCompanion<ContactLog> {
  final Value<String> id;
  final Value<String> voterId;
  final Value<String> turfId;
  final Value<String> userId;
  final Value<String> contactType;
  final Value<String> outcome;
  final Value<String> notes;
  final Value<String> doorStatus;
  final Value<int?> sentiment;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const ContactLogsCompanion({
    this.id = const Value.absent(),
    this.voterId = const Value.absent(),
    this.turfId = const Value.absent(),
    this.userId = const Value.absent(),
    this.contactType = const Value.absent(),
    this.outcome = const Value.absent(),
    this.notes = const Value.absent(),
    this.doorStatus = const Value.absent(),
    this.sentiment = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactLogsCompanion.insert({
    required String id,
    required String voterId,
    required String turfId,
    required String userId,
    required String contactType,
    required String outcome,
    this.notes = const Value.absent(),
    this.doorStatus = const Value.absent(),
    this.sentiment = const Value.absent(),
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voterId = Value(voterId),
       turfId = Value(turfId),
       userId = Value(userId),
       contactType = Value(contactType),
       outcome = Value(outcome),
       createdAt = Value(createdAt);
  static Insertable<ContactLog> custom({
    Expression<String>? id,
    Expression<String>? voterId,
    Expression<String>? turfId,
    Expression<String>? userId,
    Expression<String>? contactType,
    Expression<String>? outcome,
    Expression<String>? notes,
    Expression<String>? doorStatus,
    Expression<int>? sentiment,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voterId != null) 'voter_id': voterId,
      if (turfId != null) 'turf_id': turfId,
      if (userId != null) 'user_id': userId,
      if (contactType != null) 'contact_type': contactType,
      if (outcome != null) 'outcome': outcome,
      if (notes != null) 'notes': notes,
      if (doorStatus != null) 'door_status': doorStatus,
      if (sentiment != null) 'sentiment': sentiment,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? voterId,
    Value<String>? turfId,
    Value<String>? userId,
    Value<String>? contactType,
    Value<String>? outcome,
    Value<String>? notes,
    Value<String>? doorStatus,
    Value<int?>? sentiment,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return ContactLogsCompanion(
      id: id ?? this.id,
      voterId: voterId ?? this.voterId,
      turfId: turfId ?? this.turfId,
      userId: userId ?? this.userId,
      contactType: contactType ?? this.contactType,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
      doorStatus: doorStatus ?? this.doorStatus,
      sentiment: sentiment ?? this.sentiment,
      createdAt: createdAt ?? this.createdAt,
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
    if (voterId.present) {
      map['voter_id'] = Variable<String>(voterId.value);
    }
    if (turfId.present) {
      map['turf_id'] = Variable<String>(turfId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (contactType.present) {
      map['contact_type'] = Variable<String>(contactType.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (doorStatus.present) {
      map['door_status'] = Variable<String>(doorStatus.value);
    }
    if (sentiment.present) {
      map['sentiment'] = Variable<int>(sentiment.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('ContactLogsCompanion(')
          ..write('id: $id, ')
          ..write('voterId: $voterId, ')
          ..write('turfId: $turfId, ')
          ..write('userId: $userId, ')
          ..write('contactType: $contactType, ')
          ..write('outcome: $outcome, ')
          ..write('notes: $notes, ')
          ..write('doorStatus: $doorStatus, ')
          ..write('sentiment: $sentiment, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOperationsTable extends SyncOperations
    with TableInfo<$SyncOperationsTable, SyncOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOperationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
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
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operationType,
    payload,
    createdAt,
    retryCount,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOperation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SyncOperationsTable createAlias(String alias) {
    return $SyncOperationsTable(attachedDatabase, alias);
  }
}

class SyncOperation extends DataClass implements Insertable<SyncOperation> {
  final int id;
  final String entityType;
  final String entityId;
  final String operationType;
  final Uint8List payload;
  final DateTime createdAt;
  final int retryCount;
  final String status;
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation_type'] = Variable<String>(operationType);
    map['payload'] = Variable<Uint8List>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    map['status'] = Variable<String>(status);
    return map;
  }

  SyncOperationsCompanion toCompanion(bool nullToAbsent) {
    return SyncOperationsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operationType: Value(operationType),
      payload: Value(payload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      status: Value(status),
    );
  }

  factory SyncOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOperation(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operationType': serializer.toJson<String>(operationType),
      'payload': serializer.toJson<Uint8List>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'status': serializer.toJson<String>(status),
    };
  }

  SyncOperation copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? operationType,
    Uint8List? payload,
    DateTime? createdAt,
    int? retryCount,
    String? status,
  }) => SyncOperation(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operationType: operationType ?? this.operationType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
  );
  SyncOperation copyWithCompanion(SyncOperationsCompanion data) {
    return SyncOperation(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperation(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operationType: $operationType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operationType,
    $driftBlobEquality.hash(payload),
    createdAt,
    retryCount,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOperation &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operationType == this.operationType &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.status == this.status);
}

class SyncOperationsCompanion extends UpdateCompanion<SyncOperation> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operationType;
  final Value<Uint8List> payload;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<String> status;
  const SyncOperationsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
  });
  SyncOperationsCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    required String operationType,
    required Uint8List payload,
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       operationType = Value(operationType),
       payload = Value(payload);
  static Insertable<SyncOperation> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operationType,
    Expression<Uint8List>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operationType != null) 'operation_type': operationType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (status != null) 'status': status,
    });
  }

  SyncOperationsCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operationType,
    Value<Uint8List>? payload,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<String>? status,
  }) {
    return SyncOperationsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperationsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operationType: $operationType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entityType, cursor, lastSyncAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String entityType;
  final String cursor;
  final DateTime lastSyncAt;
  const SyncCursor({
    required this.entityType,
    required this.cursor,
    required this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    map['cursor'] = Variable<String>(cursor);
    map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      entityType: Value(entityType),
      cursor: Value(cursor),
      lastSyncAt: Value(lastSyncAt),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      entityType: serializer.fromJson<String>(json['entityType']),
      cursor: serializer.fromJson<String>(json['cursor']),
      lastSyncAt: serializer.fromJson<DateTime>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'cursor': serializer.toJson<String>(cursor),
      'lastSyncAt': serializer.toJson<DateTime>(lastSyncAt),
    };
  }

  SyncCursor copyWith({
    String? entityType,
    String? cursor,
    DateTime? lastSyncAt,
  }) => SyncCursor(
    entityType: entityType ?? this.entityType,
    cursor: cursor ?? this.cursor,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('entityType: $entityType, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityType, cursor, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.entityType == this.entityType &&
          other.cursor == this.cursor &&
          other.lastSyncAt == this.lastSyncAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> entityType;
  final Value<String> cursor;
  final Value<DateTime> lastSyncAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.entityType = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String entityType,
    required String cursor,
    required DateTime lastSyncAt,
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType),
       cursor = Value(cursor),
       lastSyncAt = Value(lastSyncAt);
  static Insertable<SyncCursor> custom({
    Expression<String>? entityType,
    Expression<String>? cursor,
    Expression<DateTime>? lastSyncAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (cursor != null) 'cursor': cursor,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? entityType,
    Value<String>? cursor,
    Value<DateTime>? lastSyncAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      entityType: entityType ?? this.entityType,
      cursor: cursor ?? this.cursor,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('entityType: $entityType, ')
          ..write('cursor: $cursor, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TurfAssignmentsTable extends TurfAssignments
    with TableInfo<$TurfAssignmentsTable, TurfAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TurfAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _turfIdMeta = const VerificationMeta('turfId');
  @override
  late final GeneratedColumn<String> turfId = GeneratedColumn<String>(
    'turf_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turfNameMeta = const VerificationMeta(
    'turfName',
  );
  @override
  late final GeneratedColumn<String> turfName = GeneratedColumn<String>(
    'turf_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assignedAtMeta = const VerificationMeta(
    'assignedAt',
  );
  @override
  late final GeneratedColumn<DateTime> assignedAt = GeneratedColumn<DateTime>(
    'assigned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boundaryGeojsonMeta = const VerificationMeta(
    'boundaryGeojson',
  );
  @override
  late final GeneratedColumn<String> boundaryGeojson = GeneratedColumn<String>(
    'boundary_geojson',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    turfId,
    turfName,
    assignedAt,
    boundaryGeojson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'turf_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TurfAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('turf_id')) {
      context.handle(
        _turfIdMeta,
        turfId.isAcceptableOrUnknown(data['turf_id']!, _turfIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turfIdMeta);
    }
    if (data.containsKey('turf_name')) {
      context.handle(
        _turfNameMeta,
        turfName.isAcceptableOrUnknown(data['turf_name']!, _turfNameMeta),
      );
    } else if (isInserting) {
      context.missing(_turfNameMeta);
    }
    if (data.containsKey('assigned_at')) {
      context.handle(
        _assignedAtMeta,
        assignedAt.isAcceptableOrUnknown(data['assigned_at']!, _assignedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_assignedAtMeta);
    }
    if (data.containsKey('boundary_geojson')) {
      context.handle(
        _boundaryGeojsonMeta,
        boundaryGeojson.isAcceptableOrUnknown(
          data['boundary_geojson']!,
          _boundaryGeojsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_boundaryGeojsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {turfId};
  @override
  TurfAssignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TurfAssignment(
      turfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turf_id'],
      )!,
      turfName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turf_name'],
      )!,
      assignedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}assigned_at'],
      )!,
      boundaryGeojson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}boundary_geojson'],
      )!,
    );
  }

  @override
  $TurfAssignmentsTable createAlias(String alias) {
    return $TurfAssignmentsTable(attachedDatabase, alias);
  }
}

class TurfAssignment extends DataClass implements Insertable<TurfAssignment> {
  final String turfId;
  final String turfName;
  final DateTime assignedAt;
  final String boundaryGeojson;
  const TurfAssignment({
    required this.turfId,
    required this.turfName,
    required this.assignedAt,
    required this.boundaryGeojson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['turf_id'] = Variable<String>(turfId);
    map['turf_name'] = Variable<String>(turfName);
    map['assigned_at'] = Variable<DateTime>(assignedAt);
    map['boundary_geojson'] = Variable<String>(boundaryGeojson);
    return map;
  }

  TurfAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return TurfAssignmentsCompanion(
      turfId: Value(turfId),
      turfName: Value(turfName),
      assignedAt: Value(assignedAt),
      boundaryGeojson: Value(boundaryGeojson),
    );
  }

  factory TurfAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TurfAssignment(
      turfId: serializer.fromJson<String>(json['turfId']),
      turfName: serializer.fromJson<String>(json['turfName']),
      assignedAt: serializer.fromJson<DateTime>(json['assignedAt']),
      boundaryGeojson: serializer.fromJson<String>(json['boundaryGeojson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'turfId': serializer.toJson<String>(turfId),
      'turfName': serializer.toJson<String>(turfName),
      'assignedAt': serializer.toJson<DateTime>(assignedAt),
      'boundaryGeojson': serializer.toJson<String>(boundaryGeojson),
    };
  }

  TurfAssignment copyWith({
    String? turfId,
    String? turfName,
    DateTime? assignedAt,
    String? boundaryGeojson,
  }) => TurfAssignment(
    turfId: turfId ?? this.turfId,
    turfName: turfName ?? this.turfName,
    assignedAt: assignedAt ?? this.assignedAt,
    boundaryGeojson: boundaryGeojson ?? this.boundaryGeojson,
  );
  TurfAssignment copyWithCompanion(TurfAssignmentsCompanion data) {
    return TurfAssignment(
      turfId: data.turfId.present ? data.turfId.value : this.turfId,
      turfName: data.turfName.present ? data.turfName.value : this.turfName,
      assignedAt: data.assignedAt.present
          ? data.assignedAt.value
          : this.assignedAt,
      boundaryGeojson: data.boundaryGeojson.present
          ? data.boundaryGeojson.value
          : this.boundaryGeojson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TurfAssignment(')
          ..write('turfId: $turfId, ')
          ..write('turfName: $turfName, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('boundaryGeojson: $boundaryGeojson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(turfId, turfName, assignedAt, boundaryGeojson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TurfAssignment &&
          other.turfId == this.turfId &&
          other.turfName == this.turfName &&
          other.assignedAt == this.assignedAt &&
          other.boundaryGeojson == this.boundaryGeojson);
}

class TurfAssignmentsCompanion extends UpdateCompanion<TurfAssignment> {
  final Value<String> turfId;
  final Value<String> turfName;
  final Value<DateTime> assignedAt;
  final Value<String> boundaryGeojson;
  final Value<int> rowid;
  const TurfAssignmentsCompanion({
    this.turfId = const Value.absent(),
    this.turfName = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.boundaryGeojson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TurfAssignmentsCompanion.insert({
    required String turfId,
    required String turfName,
    required DateTime assignedAt,
    required String boundaryGeojson,
    this.rowid = const Value.absent(),
  }) : turfId = Value(turfId),
       turfName = Value(turfName),
       assignedAt = Value(assignedAt),
       boundaryGeojson = Value(boundaryGeojson);
  static Insertable<TurfAssignment> custom({
    Expression<String>? turfId,
    Expression<String>? turfName,
    Expression<DateTime>? assignedAt,
    Expression<String>? boundaryGeojson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (turfId != null) 'turf_id': turfId,
      if (turfName != null) 'turf_name': turfName,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (boundaryGeojson != null) 'boundary_geojson': boundaryGeojson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TurfAssignmentsCompanion copyWith({
    Value<String>? turfId,
    Value<String>? turfName,
    Value<DateTime>? assignedAt,
    Value<String>? boundaryGeojson,
    Value<int>? rowid,
  }) {
    return TurfAssignmentsCompanion(
      turfId: turfId ?? this.turfId,
      turfName: turfName ?? this.turfName,
      assignedAt: assignedAt ?? this.assignedAt,
      boundaryGeojson: boundaryGeojson ?? this.boundaryGeojson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (turfId.present) {
      map['turf_id'] = Variable<String>(turfId.value);
    }
    if (turfName.present) {
      map['turf_name'] = Variable<String>(turfName.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<DateTime>(assignedAt.value);
    }
    if (boundaryGeojson.present) {
      map['boundary_geojson'] = Variable<String>(boundaryGeojson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TurfAssignmentsCompanion(')
          ..write('turfId: $turfId, ')
          ..write('turfName: $turfName, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('boundaryGeojson: $boundaryGeojson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SurveyFormsTable extends SurveyForms
    with TableInfo<$SurveyFormsTable, SurveyForm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveyFormsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _schemaMeta = const VerificationMeta('schema');
  @override
  late final GeneratedColumn<String> schema = GeneratedColumn<String>(
    'schema',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
    companyId,
    title,
    description,
    schema,
    version,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'survey_forms';
  @override
  VerificationContext validateIntegrity(
    Insertable<SurveyForm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('schema')) {
      context.handle(
        _schemaMeta,
        schema.isAcceptableOrUnknown(data['schema']!, _schemaMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  SurveyForm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurveyForm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      schema: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schema'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SurveyFormsTable createAlias(String alias) {
    return $SurveyFormsTable(attachedDatabase, alias);
  }
}

class SurveyForm extends DataClass implements Insertable<SurveyForm> {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final String schema;
  final int version;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SurveyForm({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.schema,
    required this.version,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['schema'] = Variable<String>(schema);
    map['version'] = Variable<int>(version);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SurveyFormsCompanion toCompanion(bool nullToAbsent) {
    return SurveyFormsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      title: Value(title),
      description: Value(description),
      schema: Value(schema),
      version: Value(version),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SurveyForm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurveyForm(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      schema: serializer.fromJson<String>(json['schema']),
      version: serializer.fromJson<int>(json['version']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'schema': serializer.toJson<String>(schema),
      'version': serializer.toJson<int>(version),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SurveyForm copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    String? schema,
    int? version,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SurveyForm(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    title: title ?? this.title,
    description: description ?? this.description,
    schema: schema ?? this.schema,
    version: version ?? this.version,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SurveyForm copyWithCompanion(SurveyFormsCompanion data) {
    return SurveyForm(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      schema: data.schema.present ? data.schema.value : this.schema,
      version: data.version.present ? data.version.value : this.version,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurveyForm(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('schema: $schema, ')
          ..write('version: $version, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    title,
    description,
    schema,
    version,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurveyForm &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.title == this.title &&
          other.description == this.description &&
          other.schema == this.schema &&
          other.version == this.version &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SurveyFormsCompanion extends UpdateCompanion<SurveyForm> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> title;
  final Value<String> description;
  final Value<String> schema;
  final Value<int> version;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SurveyFormsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.schema = const Value.absent(),
    this.version = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveyFormsCompanion.insert({
    required String id,
    required String companyId,
    required String title,
    this.description = const Value.absent(),
    required String schema,
    this.version = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       title = Value(title),
       schema = Value(schema),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SurveyForm> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? schema,
    Expression<int>? version,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (schema != null) 'schema': schema,
      if (version != null) 'version': version,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveyFormsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? title,
    Value<String>? description,
    Value<String>? schema,
    Value<int>? version,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SurveyFormsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      schema: schema ?? this.schema,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
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
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (schema.present) {
      map['schema'] = Variable<String>(schema.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('SurveyFormsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('schema: $schema, ')
          ..write('version: $version, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SurveyResponsesTable extends SurveyResponses
    with TableInfo<$SurveyResponsesTable, SurveyResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveyResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
    'form_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formVersionMeta = const VerificationMeta(
    'formVersion',
  );
  @override
  late final GeneratedColumn<int> formVersion = GeneratedColumn<int>(
    'form_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voterIdMeta = const VerificationMeta(
    'voterId',
  );
  @override
  late final GeneratedColumn<String> voterId = GeneratedColumn<String>(
    'voter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turfIdMeta = const VerificationMeta('turfId');
  @override
  late final GeneratedColumn<String> turfId = GeneratedColumn<String>(
    'turf_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactLogIdMeta = const VerificationMeta(
    'contactLogId',
  );
  @override
  late final GeneratedColumn<String> contactLogId = GeneratedColumn<String>(
    'contact_log_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _responsesJsonMeta = const VerificationMeta(
    'responsesJson',
  );
  @override
  late final GeneratedColumn<String> responsesJson = GeneratedColumn<String>(
    'responses_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
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
    formId,
    formVersion,
    voterId,
    userId,
    turfId,
    contactLogId,
    responsesJson,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'survey_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<SurveyResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('form_id')) {
      context.handle(
        _formIdMeta,
        formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta),
      );
    } else if (isInserting) {
      context.missing(_formIdMeta);
    }
    if (data.containsKey('form_version')) {
      context.handle(
        _formVersionMeta,
        formVersion.isAcceptableOrUnknown(
          data['form_version']!,
          _formVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formVersionMeta);
    }
    if (data.containsKey('voter_id')) {
      context.handle(
        _voterIdMeta,
        voterId.isAcceptableOrUnknown(data['voter_id']!, _voterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_voterIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('turf_id')) {
      context.handle(
        _turfIdMeta,
        turfId.isAcceptableOrUnknown(data['turf_id']!, _turfIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turfIdMeta);
    }
    if (data.containsKey('contact_log_id')) {
      context.handle(
        _contactLogIdMeta,
        contactLogId.isAcceptableOrUnknown(
          data['contact_log_id']!,
          _contactLogIdMeta,
        ),
      );
    }
    if (data.containsKey('responses_json')) {
      context.handle(
        _responsesJsonMeta,
        responsesJson.isAcceptableOrUnknown(
          data['responses_json']!,
          _responsesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responsesJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  SurveyResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurveyResponse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      formId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_id'],
      )!,
      formVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}form_version'],
      )!,
      voterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voter_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      turfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turf_id'],
      )!,
      contactLogId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_log_id'],
      ),
      responsesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}responses_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $SurveyResponsesTable createAlias(String alias) {
    return $SurveyResponsesTable(attachedDatabase, alias);
  }
}

class SurveyResponse extends DataClass implements Insertable<SurveyResponse> {
  final String id;
  final String formId;
  final int formVersion;
  final String voterId;
  final String userId;
  final String turfId;
  final String? contactLogId;
  final String responsesJson;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const SurveyResponse({
    required this.id,
    required this.formId,
    required this.formVersion,
    required this.voterId,
    required this.userId,
    required this.turfId,
    this.contactLogId,
    required this.responsesJson,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['form_id'] = Variable<String>(formId);
    map['form_version'] = Variable<int>(formVersion);
    map['voter_id'] = Variable<String>(voterId);
    map['user_id'] = Variable<String>(userId);
    map['turf_id'] = Variable<String>(turfId);
    if (!nullToAbsent || contactLogId != null) {
      map['contact_log_id'] = Variable<String>(contactLogId);
    }
    map['responses_json'] = Variable<String>(responsesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  SurveyResponsesCompanion toCompanion(bool nullToAbsent) {
    return SurveyResponsesCompanion(
      id: Value(id),
      formId: Value(formId),
      formVersion: Value(formVersion),
      voterId: Value(voterId),
      userId: Value(userId),
      turfId: Value(turfId),
      contactLogId: contactLogId == null && nullToAbsent
          ? const Value.absent()
          : Value(contactLogId),
      responsesJson: Value(responsesJson),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory SurveyResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurveyResponse(
      id: serializer.fromJson<String>(json['id']),
      formId: serializer.fromJson<String>(json['formId']),
      formVersion: serializer.fromJson<int>(json['formVersion']),
      voterId: serializer.fromJson<String>(json['voterId']),
      userId: serializer.fromJson<String>(json['userId']),
      turfId: serializer.fromJson<String>(json['turfId']),
      contactLogId: serializer.fromJson<String?>(json['contactLogId']),
      responsesJson: serializer.fromJson<String>(json['responsesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'formId': serializer.toJson<String>(formId),
      'formVersion': serializer.toJson<int>(formVersion),
      'voterId': serializer.toJson<String>(voterId),
      'userId': serializer.toJson<String>(userId),
      'turfId': serializer.toJson<String>(turfId),
      'contactLogId': serializer.toJson<String?>(contactLogId),
      'responsesJson': serializer.toJson<String>(responsesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  SurveyResponse copyWith({
    String? id,
    String? formId,
    int? formVersion,
    String? voterId,
    String? userId,
    String? turfId,
    Value<String?> contactLogId = const Value.absent(),
    String? responsesJson,
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => SurveyResponse(
    id: id ?? this.id,
    formId: formId ?? this.formId,
    formVersion: formVersion ?? this.formVersion,
    voterId: voterId ?? this.voterId,
    userId: userId ?? this.userId,
    turfId: turfId ?? this.turfId,
    contactLogId: contactLogId.present ? contactLogId.value : this.contactLogId,
    responsesJson: responsesJson ?? this.responsesJson,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  SurveyResponse copyWithCompanion(SurveyResponsesCompanion data) {
    return SurveyResponse(
      id: data.id.present ? data.id.value : this.id,
      formId: data.formId.present ? data.formId.value : this.formId,
      formVersion: data.formVersion.present
          ? data.formVersion.value
          : this.formVersion,
      voterId: data.voterId.present ? data.voterId.value : this.voterId,
      userId: data.userId.present ? data.userId.value : this.userId,
      turfId: data.turfId.present ? data.turfId.value : this.turfId,
      contactLogId: data.contactLogId.present
          ? data.contactLogId.value
          : this.contactLogId,
      responsesJson: data.responsesJson.present
          ? data.responsesJson.value
          : this.responsesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurveyResponse(')
          ..write('id: $id, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('voterId: $voterId, ')
          ..write('userId: $userId, ')
          ..write('turfId: $turfId, ')
          ..write('contactLogId: $contactLogId, ')
          ..write('responsesJson: $responsesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    formId,
    formVersion,
    voterId,
    userId,
    turfId,
    contactLogId,
    responsesJson,
    createdAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurveyResponse &&
          other.id == this.id &&
          other.formId == this.formId &&
          other.formVersion == this.formVersion &&
          other.voterId == this.voterId &&
          other.userId == this.userId &&
          other.turfId == this.turfId &&
          other.contactLogId == this.contactLogId &&
          other.responsesJson == this.responsesJson &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class SurveyResponsesCompanion extends UpdateCompanion<SurveyResponse> {
  final Value<String> id;
  final Value<String> formId;
  final Value<int> formVersion;
  final Value<String> voterId;
  final Value<String> userId;
  final Value<String> turfId;
  final Value<String?> contactLogId;
  final Value<String> responsesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const SurveyResponsesCompanion({
    this.id = const Value.absent(),
    this.formId = const Value.absent(),
    this.formVersion = const Value.absent(),
    this.voterId = const Value.absent(),
    this.userId = const Value.absent(),
    this.turfId = const Value.absent(),
    this.contactLogId = const Value.absent(),
    this.responsesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveyResponsesCompanion.insert({
    required String id,
    required String formId,
    required int formVersion,
    required String voterId,
    required String userId,
    required String turfId,
    this.contactLogId = const Value.absent(),
    required String responsesJson,
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       formId = Value(formId),
       formVersion = Value(formVersion),
       voterId = Value(voterId),
       userId = Value(userId),
       turfId = Value(turfId),
       responsesJson = Value(responsesJson),
       createdAt = Value(createdAt);
  static Insertable<SurveyResponse> custom({
    Expression<String>? id,
    Expression<String>? formId,
    Expression<int>? formVersion,
    Expression<String>? voterId,
    Expression<String>? userId,
    Expression<String>? turfId,
    Expression<String>? contactLogId,
    Expression<String>? responsesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (formId != null) 'form_id': formId,
      if (formVersion != null) 'form_version': formVersion,
      if (voterId != null) 'voter_id': voterId,
      if (userId != null) 'user_id': userId,
      if (turfId != null) 'turf_id': turfId,
      if (contactLogId != null) 'contact_log_id': contactLogId,
      if (responsesJson != null) 'responses_json': responsesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveyResponsesCompanion copyWith({
    Value<String>? id,
    Value<String>? formId,
    Value<int>? formVersion,
    Value<String>? voterId,
    Value<String>? userId,
    Value<String>? turfId,
    Value<String?>? contactLogId,
    Value<String>? responsesJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return SurveyResponsesCompanion(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      formVersion: formVersion ?? this.formVersion,
      voterId: voterId ?? this.voterId,
      userId: userId ?? this.userId,
      turfId: turfId ?? this.turfId,
      contactLogId: contactLogId ?? this.contactLogId,
      responsesJson: responsesJson ?? this.responsesJson,
      createdAt: createdAt ?? this.createdAt,
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
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (formVersion.present) {
      map['form_version'] = Variable<int>(formVersion.value);
    }
    if (voterId.present) {
      map['voter_id'] = Variable<String>(voterId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (turfId.present) {
      map['turf_id'] = Variable<String>(turfId.value);
    }
    if (contactLogId.present) {
      map['contact_log_id'] = Variable<String>(contactLogId.value);
    }
    if (responsesJson.present) {
      map['responses_json'] = Variable<String>(responsesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('SurveyResponsesCompanion(')
          ..write('id: $id, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('voterId: $voterId, ')
          ..write('userId: $userId, ')
          ..write('turfId: $turfId, ')
          ..write('contactLogId: $contactLogId, ')
          ..write('responsesJson: $responsesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoterNotesTable extends VoterNotes
    with TableInfo<$VoterNotesTable, VoterNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoterNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voterIdMeta = const VerificationMeta(
    'voterId',
  );
  @override
  late final GeneratedColumn<String> voterId = GeneratedColumn<String>(
    'voter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turfIdMeta = const VerificationMeta('turfId');
  @override
  late final GeneratedColumn<String> turfId = GeneratedColumn<String>(
    'turf_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('team'),
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
    requiredDuringInsert: true,
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
    voterId,
    userId,
    turfId,
    content,
    visibility,
    createdAt,
    updatedAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voter_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoterNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('voter_id')) {
      context.handle(
        _voterIdMeta,
        voterId.isAcceptableOrUnknown(data['voter_id']!, _voterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_voterIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('turf_id')) {
      context.handle(
        _turfIdMeta,
        turfId.isAcceptableOrUnknown(data['turf_id']!, _turfIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turfIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
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
  VoterNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoterNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      voterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voter_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      turfId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turf_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $VoterNotesTable createAlias(String alias) {
    return $VoterNotesTable(attachedDatabase, alias);
  }
}

class VoterNote extends DataClass implements Insertable<VoterNote> {
  final String id;
  final String voterId;
  final String userId;
  final String turfId;
  final String content;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  const VoterNote({
    required this.id,
    required this.voterId,
    required this.userId,
    required this.turfId,
    required this.content,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['voter_id'] = Variable<String>(voterId);
    map['user_id'] = Variable<String>(userId);
    map['turf_id'] = Variable<String>(turfId);
    map['content'] = Variable<String>(content);
    map['visibility'] = Variable<String>(visibility);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  VoterNotesCompanion toCompanion(bool nullToAbsent) {
    return VoterNotesCompanion(
      id: Value(id),
      voterId: Value(voterId),
      userId: Value(userId),
      turfId: Value(turfId),
      content: Value(content),
      visibility: Value(visibility),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory VoterNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoterNote(
      id: serializer.fromJson<String>(json['id']),
      voterId: serializer.fromJson<String>(json['voterId']),
      userId: serializer.fromJson<String>(json['userId']),
      turfId: serializer.fromJson<String>(json['turfId']),
      content: serializer.fromJson<String>(json['content']),
      visibility: serializer.fromJson<String>(json['visibility']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'voterId': serializer.toJson<String>(voterId),
      'userId': serializer.toJson<String>(userId),
      'turfId': serializer.toJson<String>(turfId),
      'content': serializer.toJson<String>(content),
      'visibility': serializer.toJson<String>(visibility),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  VoterNote copyWith({
    String? id,
    String? voterId,
    String? userId,
    String? turfId,
    String? content,
    String? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => VoterNote(
    id: id ?? this.id,
    voterId: voterId ?? this.voterId,
    userId: userId ?? this.userId,
    turfId: turfId ?? this.turfId,
    content: content ?? this.content,
    visibility: visibility ?? this.visibility,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  VoterNote copyWithCompanion(VoterNotesCompanion data) {
    return VoterNote(
      id: data.id.present ? data.id.value : this.id,
      voterId: data.voterId.present ? data.voterId.value : this.voterId,
      userId: data.userId.present ? data.userId.value : this.userId,
      turfId: data.turfId.present ? data.turfId.value : this.turfId,
      content: data.content.present ? data.content.value : this.content,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoterNote(')
          ..write('id: $id, ')
          ..write('voterId: $voterId, ')
          ..write('userId: $userId, ')
          ..write('turfId: $turfId, ')
          ..write('content: $content, ')
          ..write('visibility: $visibility, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    voterId,
    userId,
    turfId,
    content,
    visibility,
    createdAt,
    updatedAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoterNote &&
          other.id == this.id &&
          other.voterId == this.voterId &&
          other.userId == this.userId &&
          other.turfId == this.turfId &&
          other.content == this.content &&
          other.visibility == this.visibility &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt);
}

class VoterNotesCompanion extends UpdateCompanion<VoterNote> {
  final Value<String> id;
  final Value<String> voterId;
  final Value<String> userId;
  final Value<String> turfId;
  final Value<String> content;
  final Value<String> visibility;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const VoterNotesCompanion({
    this.id = const Value.absent(),
    this.voterId = const Value.absent(),
    this.userId = const Value.absent(),
    this.turfId = const Value.absent(),
    this.content = const Value.absent(),
    this.visibility = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoterNotesCompanion.insert({
    required String id,
    required String voterId,
    required String userId,
    required String turfId,
    required String content,
    this.visibility = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       voterId = Value(voterId),
       userId = Value(userId),
       turfId = Value(turfId),
       content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<VoterNote> custom({
    Expression<String>? id,
    Expression<String>? voterId,
    Expression<String>? userId,
    Expression<String>? turfId,
    Expression<String>? content,
    Expression<String>? visibility,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (voterId != null) 'voter_id': voterId,
      if (userId != null) 'user_id': userId,
      if (turfId != null) 'turf_id': turfId,
      if (content != null) 'content': content,
      if (visibility != null) 'visibility': visibility,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoterNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? voterId,
    Value<String>? userId,
    Value<String>? turfId,
    Value<String>? content,
    Value<String>? visibility,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return VoterNotesCompanion(
      id: id ?? this.id,
      voterId: voterId ?? this.voterId,
      userId: userId ?? this.userId,
      turfId: turfId ?? this.turfId,
      content: content ?? this.content,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (voterId.present) {
      map['voter_id'] = Variable<String>(voterId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (turfId.present) {
      map['turf_id'] = Variable<String>(turfId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
    return (StringBuffer('VoterNotesCompanion(')
          ..write('id: $id, ')
          ..write('voterId: $voterId, ')
          ..write('userId: $userId, ')
          ..write('turfId: $turfId, ')
          ..write('content: $content, ')
          ..write('visibility: $visibility, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NavigatorsDatabase extends GeneratedDatabase {
  _$NavigatorsDatabase(QueryExecutor e) : super(e);
  $NavigatorsDatabaseManager get managers => $NavigatorsDatabaseManager(this);
  late final $VotersTable voters = $VotersTable(this);
  late final $ContactLogsTable contactLogs = $ContactLogsTable(this);
  late final $SyncOperationsTable syncOperations = $SyncOperationsTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $TurfAssignmentsTable turfAssignments = $TurfAssignmentsTable(
    this,
  );
  late final $SurveyFormsTable surveyForms = $SurveyFormsTable(this);
  late final $SurveyResponsesTable surveyResponses = $SurveyResponsesTable(
    this,
  );
  late final $VoterNotesTable voterNotes = $VoterNotesTable(this);
  late final VoterDao voterDao = VoterDao(this as NavigatorsDatabase);
  late final SyncDao syncDao = SyncDao(this as NavigatorsDatabase);
  late final ContactLogDao contactLogDao = ContactLogDao(
    this as NavigatorsDatabase,
  );
  late final SurveyDao surveyDao = SurveyDao(this as NavigatorsDatabase);
  late final VoterNoteDao voterNoteDao = VoterNoteDao(
    this as NavigatorsDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    voters,
    contactLogs,
    syncOperations,
    syncCursors,
    turfAssignments,
    surveyForms,
    surveyResponses,
    voterNotes,
  ];
}

typedef $$VotersTableCreateCompanionBuilder =
    VotersCompanion Function({
      required String id,
      required String turfId,
      required String firstName,
      required String lastName,
      Value<String> middleName,
      Value<String> suffix,
      Value<int?> yearOfBirth,
      Value<String> resStreetAddress,
      Value<String> resCity,
      Value<String> resState,
      Value<String> resZip,
      Value<String> party,
      Value<String> status,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> votingHistory,
      Value<String> phone,
      Value<String> email,
      Value<int> walkSequence,
      required DateTime serverUpdatedAt,
      required DateTime localUpdatedAt,
      Value<int> rowid,
    });
typedef $$VotersTableUpdateCompanionBuilder =
    VotersCompanion Function({
      Value<String> id,
      Value<String> turfId,
      Value<String> firstName,
      Value<String> lastName,
      Value<String> middleName,
      Value<String> suffix,
      Value<int?> yearOfBirth,
      Value<String> resStreetAddress,
      Value<String> resCity,
      Value<String> resState,
      Value<String> resZip,
      Value<String> party,
      Value<String> status,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> votingHistory,
      Value<String> phone,
      Value<String> email,
      Value<int> walkSequence,
      Value<DateTime> serverUpdatedAt,
      Value<DateTime> localUpdatedAt,
      Value<int> rowid,
    });

class $$VotersTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $VotersTable> {
  $$VotersTableFilterComposer({
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

  ColumnFilters<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yearOfBirth => $composableBuilder(
    column: $table.yearOfBirth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resStreetAddress => $composableBuilder(
    column: $table.resStreetAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resCity => $composableBuilder(
    column: $table.resCity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resState => $composableBuilder(
    column: $table.resState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resZip => $composableBuilder(
    column: $table.resZip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get party => $composableBuilder(
    column: $table.party,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get votingHistory => $composableBuilder(
    column: $table.votingHistory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get walkSequence => $composableBuilder(
    column: $table.walkSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VotersTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $VotersTable> {
  $$VotersTableOrderingComposer({
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

  ColumnOrderings<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yearOfBirth => $composableBuilder(
    column: $table.yearOfBirth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resStreetAddress => $composableBuilder(
    column: $table.resStreetAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resCity => $composableBuilder(
    column: $table.resCity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resState => $composableBuilder(
    column: $table.resState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resZip => $composableBuilder(
    column: $table.resZip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get party => $composableBuilder(
    column: $table.party,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get votingHistory => $composableBuilder(
    column: $table.votingHistory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get walkSequence => $composableBuilder(
    column: $table.walkSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VotersTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $VotersTable> {
  $$VotersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get turfId =>
      $composableBuilder(column: $table.turfId, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get middleName => $composableBuilder(
    column: $table.middleName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<int> get yearOfBirth => $composableBuilder(
    column: $table.yearOfBirth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resStreetAddress => $composableBuilder(
    column: $table.resStreetAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resCity =>
      $composableBuilder(column: $table.resCity, builder: (column) => column);

  GeneratedColumn<String> get resState =>
      $composableBuilder(column: $table.resState, builder: (column) => column);

  GeneratedColumn<String> get resZip =>
      $composableBuilder(column: $table.resZip, builder: (column) => column);

  GeneratedColumn<String> get party =>
      $composableBuilder(column: $table.party, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get votingHistory => $composableBuilder(
    column: $table.votingHistory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get walkSequence => $composableBuilder(
    column: $table.walkSequence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get localUpdatedAt => $composableBuilder(
    column: $table.localUpdatedAt,
    builder: (column) => column,
  );
}

class $$VotersTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $VotersTable,
          Voter,
          $$VotersTableFilterComposer,
          $$VotersTableOrderingComposer,
          $$VotersTableAnnotationComposer,
          $$VotersTableCreateCompanionBuilder,
          $$VotersTableUpdateCompanionBuilder,
          (Voter, BaseReferences<_$NavigatorsDatabase, $VotersTable, Voter>),
          Voter,
          PrefetchHooks Function()
        > {
  $$VotersTableTableManager(_$NavigatorsDatabase db, $VotersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VotersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VotersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VotersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> turfId = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> middleName = const Value.absent(),
                Value<String> suffix = const Value.absent(),
                Value<int?> yearOfBirth = const Value.absent(),
                Value<String> resStreetAddress = const Value.absent(),
                Value<String> resCity = const Value.absent(),
                Value<String> resState = const Value.absent(),
                Value<String> resZip = const Value.absent(),
                Value<String> party = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> votingHistory = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int> walkSequence = const Value.absent(),
                Value<DateTime> serverUpdatedAt = const Value.absent(),
                Value<DateTime> localUpdatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VotersCompanion(
                id: id,
                turfId: turfId,
                firstName: firstName,
                lastName: lastName,
                middleName: middleName,
                suffix: suffix,
                yearOfBirth: yearOfBirth,
                resStreetAddress: resStreetAddress,
                resCity: resCity,
                resState: resState,
                resZip: resZip,
                party: party,
                status: status,
                latitude: latitude,
                longitude: longitude,
                votingHistory: votingHistory,
                phone: phone,
                email: email,
                walkSequence: walkSequence,
                serverUpdatedAt: serverUpdatedAt,
                localUpdatedAt: localUpdatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String turfId,
                required String firstName,
                required String lastName,
                Value<String> middleName = const Value.absent(),
                Value<String> suffix = const Value.absent(),
                Value<int?> yearOfBirth = const Value.absent(),
                Value<String> resStreetAddress = const Value.absent(),
                Value<String> resCity = const Value.absent(),
                Value<String> resState = const Value.absent(),
                Value<String> resZip = const Value.absent(),
                Value<String> party = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> votingHistory = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int> walkSequence = const Value.absent(),
                required DateTime serverUpdatedAt,
                required DateTime localUpdatedAt,
                Value<int> rowid = const Value.absent(),
              }) => VotersCompanion.insert(
                id: id,
                turfId: turfId,
                firstName: firstName,
                lastName: lastName,
                middleName: middleName,
                suffix: suffix,
                yearOfBirth: yearOfBirth,
                resStreetAddress: resStreetAddress,
                resCity: resCity,
                resState: resState,
                resZip: resZip,
                party: party,
                status: status,
                latitude: latitude,
                longitude: longitude,
                votingHistory: votingHistory,
                phone: phone,
                email: email,
                walkSequence: walkSequence,
                serverUpdatedAt: serverUpdatedAt,
                localUpdatedAt: localUpdatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VotersTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $VotersTable,
      Voter,
      $$VotersTableFilterComposer,
      $$VotersTableOrderingComposer,
      $$VotersTableAnnotationComposer,
      $$VotersTableCreateCompanionBuilder,
      $$VotersTableUpdateCompanionBuilder,
      (Voter, BaseReferences<_$NavigatorsDatabase, $VotersTable, Voter>),
      Voter,
      PrefetchHooks Function()
    >;
typedef $$ContactLogsTableCreateCompanionBuilder =
    ContactLogsCompanion Function({
      required String id,
      required String voterId,
      required String turfId,
      required String userId,
      required String contactType,
      required String outcome,
      Value<String> notes,
      Value<String> doorStatus,
      Value<int?> sentiment,
      required DateTime createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$ContactLogsTableUpdateCompanionBuilder =
    ContactLogsCompanion Function({
      Value<String> id,
      Value<String> voterId,
      Value<String> turfId,
      Value<String> userId,
      Value<String> contactType,
      Value<String> outcome,
      Value<String> notes,
      Value<String> doorStatus,
      Value<int?> sentiment,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$ContactLogsTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $ContactLogsTable> {
  $$ContactLogsTableFilterComposer({
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

  ColumnFilters<String> get voterId => $composableBuilder(
    column: $table.voterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactType => $composableBuilder(
    column: $table.contactType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doorStatus => $composableBuilder(
    column: $table.doorStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentiment => $composableBuilder(
    column: $table.sentiment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactLogsTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $ContactLogsTable> {
  $$ContactLogsTableOrderingComposer({
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

  ColumnOrderings<String> get voterId => $composableBuilder(
    column: $table.voterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactType => $composableBuilder(
    column: $table.contactType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doorStatus => $composableBuilder(
    column: $table.doorStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentiment => $composableBuilder(
    column: $table.sentiment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactLogsTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $ContactLogsTable> {
  $$ContactLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voterId =>
      $composableBuilder(column: $table.voterId, builder: (column) => column);

  GeneratedColumn<String> get turfId =>
      $composableBuilder(column: $table.turfId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get contactType => $composableBuilder(
    column: $table.contactType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get doorStatus => $composableBuilder(
    column: $table.doorStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sentiment =>
      $composableBuilder(column: $table.sentiment, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$ContactLogsTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $ContactLogsTable,
          ContactLog,
          $$ContactLogsTableFilterComposer,
          $$ContactLogsTableOrderingComposer,
          $$ContactLogsTableAnnotationComposer,
          $$ContactLogsTableCreateCompanionBuilder,
          $$ContactLogsTableUpdateCompanionBuilder,
          (
            ContactLog,
            BaseReferences<_$NavigatorsDatabase, $ContactLogsTable, ContactLog>,
          ),
          ContactLog,
          PrefetchHooks Function()
        > {
  $$ContactLogsTableTableManager(
    _$NavigatorsDatabase db,
    $ContactLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voterId = const Value.absent(),
                Value<String> turfId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> contactType = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> doorStatus = const Value.absent(),
                Value<int?> sentiment = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactLogsCompanion(
                id: id,
                voterId: voterId,
                turfId: turfId,
                userId: userId,
                contactType: contactType,
                outcome: outcome,
                notes: notes,
                doorStatus: doorStatus,
                sentiment: sentiment,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voterId,
                required String turfId,
                required String userId,
                required String contactType,
                required String outcome,
                Value<String> notes = const Value.absent(),
                Value<String> doorStatus = const Value.absent(),
                Value<int?> sentiment = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactLogsCompanion.insert(
                id: id,
                voterId: voterId,
                turfId: turfId,
                userId: userId,
                contactType: contactType,
                outcome: outcome,
                notes: notes,
                doorStatus: doorStatus,
                sentiment: sentiment,
                createdAt: createdAt,
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

typedef $$ContactLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $ContactLogsTable,
      ContactLog,
      $$ContactLogsTableFilterComposer,
      $$ContactLogsTableOrderingComposer,
      $$ContactLogsTableAnnotationComposer,
      $$ContactLogsTableCreateCompanionBuilder,
      $$ContactLogsTableUpdateCompanionBuilder,
      (
        ContactLog,
        BaseReferences<_$NavigatorsDatabase, $ContactLogsTable, ContactLog>,
      ),
      ContactLog,
      PrefetchHooks Function()
    >;
typedef $$SyncOperationsTableCreateCompanionBuilder =
    SyncOperationsCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      required String operationType,
      required Uint8List payload,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String> status,
    });
typedef $$SyncOperationsTableUpdateCompanionBuilder =
    SyncOperationsCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operationType,
      Value<Uint8List> payload,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String> status,
    });

class $$SyncOperationsTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOperationsTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOperationsTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$SyncOperationsTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $SyncOperationsTable,
          SyncOperation,
          $$SyncOperationsTableFilterComposer,
          $$SyncOperationsTableOrderingComposer,
          $$SyncOperationsTableAnnotationComposer,
          $$SyncOperationsTableCreateCompanionBuilder,
          $$SyncOperationsTableUpdateCompanionBuilder,
          (
            SyncOperation,
            BaseReferences<
              _$NavigatorsDatabase,
              $SyncOperationsTable,
              SyncOperation
            >,
          ),
          SyncOperation,
          PrefetchHooks Function()
        > {
  $$SyncOperationsTableTableManager(
    _$NavigatorsDatabase db,
    $SyncOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SyncOperationsCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operationType: operationType,
                payload: payload,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                required String operationType,
                required Uint8List payload,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => SyncOperationsCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operationType: operationType,
                payload: payload,
                createdAt: createdAt,
                retryCount: retryCount,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $SyncOperationsTable,
      SyncOperation,
      $$SyncOperationsTableFilterComposer,
      $$SyncOperationsTableOrderingComposer,
      $$SyncOperationsTableAnnotationComposer,
      $$SyncOperationsTableCreateCompanionBuilder,
      $$SyncOperationsTableUpdateCompanionBuilder,
      (
        SyncOperation,
        BaseReferences<
          _$NavigatorsDatabase,
          $SyncOperationsTable,
          SyncOperation
        >,
      ),
      SyncOperation,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String entityType,
      required String cursor,
      required DateTime lastSyncAt,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> entityType,
      Value<String> cursor,
      Value<DateTime> lastSyncAt,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$NavigatorsDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(
    _$NavigatorsDatabase db,
    $SyncCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entityType = const Value.absent(),
                Value<String> cursor = const Value.absent(),
                Value<DateTime> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                entityType: entityType,
                cursor: cursor,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityType,
                required String cursor,
                required DateTime lastSyncAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                entityType: entityType,
                cursor: cursor,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$NavigatorsDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$TurfAssignmentsTableCreateCompanionBuilder =
    TurfAssignmentsCompanion Function({
      required String turfId,
      required String turfName,
      required DateTime assignedAt,
      required String boundaryGeojson,
      Value<int> rowid,
    });
typedef $$TurfAssignmentsTableUpdateCompanionBuilder =
    TurfAssignmentsCompanion Function({
      Value<String> turfId,
      Value<String> turfName,
      Value<DateTime> assignedAt,
      Value<String> boundaryGeojson,
      Value<int> rowid,
    });

class $$TurfAssignmentsTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $TurfAssignmentsTable> {
  $$TurfAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turfName => $composableBuilder(
    column: $table.turfName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get assignedAt => $composableBuilder(
    column: $table.assignedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boundaryGeojson => $composableBuilder(
    column: $table.boundaryGeojson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TurfAssignmentsTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $TurfAssignmentsTable> {
  $$TurfAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turfName => $composableBuilder(
    column: $table.turfName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get assignedAt => $composableBuilder(
    column: $table.assignedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boundaryGeojson => $composableBuilder(
    column: $table.boundaryGeojson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TurfAssignmentsTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $TurfAssignmentsTable> {
  $$TurfAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get turfId =>
      $composableBuilder(column: $table.turfId, builder: (column) => column);

  GeneratedColumn<String> get turfName =>
      $composableBuilder(column: $table.turfName, builder: (column) => column);

  GeneratedColumn<DateTime> get assignedAt => $composableBuilder(
    column: $table.assignedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get boundaryGeojson => $composableBuilder(
    column: $table.boundaryGeojson,
    builder: (column) => column,
  );
}

class $$TurfAssignmentsTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $TurfAssignmentsTable,
          TurfAssignment,
          $$TurfAssignmentsTableFilterComposer,
          $$TurfAssignmentsTableOrderingComposer,
          $$TurfAssignmentsTableAnnotationComposer,
          $$TurfAssignmentsTableCreateCompanionBuilder,
          $$TurfAssignmentsTableUpdateCompanionBuilder,
          (
            TurfAssignment,
            BaseReferences<
              _$NavigatorsDatabase,
              $TurfAssignmentsTable,
              TurfAssignment
            >,
          ),
          TurfAssignment,
          PrefetchHooks Function()
        > {
  $$TurfAssignmentsTableTableManager(
    _$NavigatorsDatabase db,
    $TurfAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TurfAssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TurfAssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TurfAssignmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> turfId = const Value.absent(),
                Value<String> turfName = const Value.absent(),
                Value<DateTime> assignedAt = const Value.absent(),
                Value<String> boundaryGeojson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TurfAssignmentsCompanion(
                turfId: turfId,
                turfName: turfName,
                assignedAt: assignedAt,
                boundaryGeojson: boundaryGeojson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String turfId,
                required String turfName,
                required DateTime assignedAt,
                required String boundaryGeojson,
                Value<int> rowid = const Value.absent(),
              }) => TurfAssignmentsCompanion.insert(
                turfId: turfId,
                turfName: turfName,
                assignedAt: assignedAt,
                boundaryGeojson: boundaryGeojson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TurfAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $TurfAssignmentsTable,
      TurfAssignment,
      $$TurfAssignmentsTableFilterComposer,
      $$TurfAssignmentsTableOrderingComposer,
      $$TurfAssignmentsTableAnnotationComposer,
      $$TurfAssignmentsTableCreateCompanionBuilder,
      $$TurfAssignmentsTableUpdateCompanionBuilder,
      (
        TurfAssignment,
        BaseReferences<
          _$NavigatorsDatabase,
          $TurfAssignmentsTable,
          TurfAssignment
        >,
      ),
      TurfAssignment,
      PrefetchHooks Function()
    >;
typedef $$SurveyFormsTableCreateCompanionBuilder =
    SurveyFormsCompanion Function({
      required String id,
      required String companyId,
      required String title,
      Value<String> description,
      required String schema,
      Value<int> version,
      Value<bool> isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SurveyFormsTableUpdateCompanionBuilder =
    SurveyFormsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> title,
      Value<String> description,
      Value<String> schema,
      Value<int> version,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SurveyFormsTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $SurveyFormsTable> {
  $$SurveyFormsTableFilterComposer({
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

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schema => $composableBuilder(
    column: $table.schema,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SurveyFormsTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $SurveyFormsTable> {
  $$SurveyFormsTableOrderingComposer({
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

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schema => $composableBuilder(
    column: $table.schema,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SurveyFormsTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $SurveyFormsTable> {
  $$SurveyFormsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schema =>
      $composableBuilder(column: $table.schema, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SurveyFormsTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $SurveyFormsTable,
          SurveyForm,
          $$SurveyFormsTableFilterComposer,
          $$SurveyFormsTableOrderingComposer,
          $$SurveyFormsTableAnnotationComposer,
          $$SurveyFormsTableCreateCompanionBuilder,
          $$SurveyFormsTableUpdateCompanionBuilder,
          (
            SurveyForm,
            BaseReferences<_$NavigatorsDatabase, $SurveyFormsTable, SurveyForm>,
          ),
          SurveyForm,
          PrefetchHooks Function()
        > {
  $$SurveyFormsTableTableManager(
    _$NavigatorsDatabase db,
    $SurveyFormsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveyFormsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveyFormsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveyFormsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> schema = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurveyFormsCompanion(
                id: id,
                companyId: companyId,
                title: title,
                description: description,
                schema: schema,
                version: version,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String title,
                Value<String> description = const Value.absent(),
                required String schema,
                Value<int> version = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SurveyFormsCompanion.insert(
                id: id,
                companyId: companyId,
                title: title,
                description: description,
                schema: schema,
                version: version,
                isActive: isActive,
                createdAt: createdAt,
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

typedef $$SurveyFormsTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $SurveyFormsTable,
      SurveyForm,
      $$SurveyFormsTableFilterComposer,
      $$SurveyFormsTableOrderingComposer,
      $$SurveyFormsTableAnnotationComposer,
      $$SurveyFormsTableCreateCompanionBuilder,
      $$SurveyFormsTableUpdateCompanionBuilder,
      (
        SurveyForm,
        BaseReferences<_$NavigatorsDatabase, $SurveyFormsTable, SurveyForm>,
      ),
      SurveyForm,
      PrefetchHooks Function()
    >;
typedef $$SurveyResponsesTableCreateCompanionBuilder =
    SurveyResponsesCompanion Function({
      required String id,
      required String formId,
      required int formVersion,
      required String voterId,
      required String userId,
      required String turfId,
      Value<String?> contactLogId,
      required String responsesJson,
      required DateTime createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$SurveyResponsesTableUpdateCompanionBuilder =
    SurveyResponsesCompanion Function({
      Value<String> id,
      Value<String> formId,
      Value<int> formVersion,
      Value<String> voterId,
      Value<String> userId,
      Value<String> turfId,
      Value<String?> contactLogId,
      Value<String> responsesJson,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$SurveyResponsesTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $SurveyResponsesTable> {
  $$SurveyResponsesTableFilterComposer({
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

  ColumnFilters<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voterId => $composableBuilder(
    column: $table.voterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactLogId => $composableBuilder(
    column: $table.contactLogId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responsesJson => $composableBuilder(
    column: $table.responsesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SurveyResponsesTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $SurveyResponsesTable> {
  $$SurveyResponsesTableOrderingComposer({
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

  ColumnOrderings<String> get formId => $composableBuilder(
    column: $table.formId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voterId => $composableBuilder(
    column: $table.voterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactLogId => $composableBuilder(
    column: $table.contactLogId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responsesJson => $composableBuilder(
    column: $table.responsesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SurveyResponsesTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $SurveyResponsesTable> {
  $$SurveyResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<int> get formVersion => $composableBuilder(
    column: $table.formVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voterId =>
      $composableBuilder(column: $table.voterId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get turfId =>
      $composableBuilder(column: $table.turfId, builder: (column) => column);

  GeneratedColumn<String> get contactLogId => $composableBuilder(
    column: $table.contactLogId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responsesJson => $composableBuilder(
    column: $table.responsesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SurveyResponsesTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $SurveyResponsesTable,
          SurveyResponse,
          $$SurveyResponsesTableFilterComposer,
          $$SurveyResponsesTableOrderingComposer,
          $$SurveyResponsesTableAnnotationComposer,
          $$SurveyResponsesTableCreateCompanionBuilder,
          $$SurveyResponsesTableUpdateCompanionBuilder,
          (
            SurveyResponse,
            BaseReferences<
              _$NavigatorsDatabase,
              $SurveyResponsesTable,
              SurveyResponse
            >,
          ),
          SurveyResponse,
          PrefetchHooks Function()
        > {
  $$SurveyResponsesTableTableManager(
    _$NavigatorsDatabase db,
    $SurveyResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveyResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveyResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveyResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> formId = const Value.absent(),
                Value<int> formVersion = const Value.absent(),
                Value<String> voterId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> turfId = const Value.absent(),
                Value<String?> contactLogId = const Value.absent(),
                Value<String> responsesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurveyResponsesCompanion(
                id: id,
                formId: formId,
                formVersion: formVersion,
                voterId: voterId,
                userId: userId,
                turfId: turfId,
                contactLogId: contactLogId,
                responsesJson: responsesJson,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String formId,
                required int formVersion,
                required String voterId,
                required String userId,
                required String turfId,
                Value<String?> contactLogId = const Value.absent(),
                required String responsesJson,
                required DateTime createdAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurveyResponsesCompanion.insert(
                id: id,
                formId: formId,
                formVersion: formVersion,
                voterId: voterId,
                userId: userId,
                turfId: turfId,
                contactLogId: contactLogId,
                responsesJson: responsesJson,
                createdAt: createdAt,
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

typedef $$SurveyResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $SurveyResponsesTable,
      SurveyResponse,
      $$SurveyResponsesTableFilterComposer,
      $$SurveyResponsesTableOrderingComposer,
      $$SurveyResponsesTableAnnotationComposer,
      $$SurveyResponsesTableCreateCompanionBuilder,
      $$SurveyResponsesTableUpdateCompanionBuilder,
      (
        SurveyResponse,
        BaseReferences<
          _$NavigatorsDatabase,
          $SurveyResponsesTable,
          SurveyResponse
        >,
      ),
      SurveyResponse,
      PrefetchHooks Function()
    >;
typedef $$VoterNotesTableCreateCompanionBuilder =
    VoterNotesCompanion Function({
      required String id,
      required String voterId,
      required String userId,
      required String turfId,
      required String content,
      Value<String> visibility,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$VoterNotesTableUpdateCompanionBuilder =
    VoterNotesCompanion Function({
      Value<String> id,
      Value<String> voterId,
      Value<String> userId,
      Value<String> turfId,
      Value<String> content,
      Value<String> visibility,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$VoterNotesTableFilterComposer
    extends Composer<_$NavigatorsDatabase, $VoterNotesTable> {
  $$VoterNotesTableFilterComposer({
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

  ColumnFilters<String> get voterId => $composableBuilder(
    column: $table.voterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VoterNotesTableOrderingComposer
    extends Composer<_$NavigatorsDatabase, $VoterNotesTable> {
  $$VoterNotesTableOrderingComposer({
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

  ColumnOrderings<String> get voterId => $composableBuilder(
    column: $table.voterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turfId => $composableBuilder(
    column: $table.turfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoterNotesTableAnnotationComposer
    extends Composer<_$NavigatorsDatabase, $VoterNotesTable> {
  $$VoterNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get voterId =>
      $composableBuilder(column: $table.voterId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get turfId =>
      $composableBuilder(column: $table.turfId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$VoterNotesTableTableManager
    extends
        RootTableManager<
          _$NavigatorsDatabase,
          $VoterNotesTable,
          VoterNote,
          $$VoterNotesTableFilterComposer,
          $$VoterNotesTableOrderingComposer,
          $$VoterNotesTableAnnotationComposer,
          $$VoterNotesTableCreateCompanionBuilder,
          $$VoterNotesTableUpdateCompanionBuilder,
          (
            VoterNote,
            BaseReferences<_$NavigatorsDatabase, $VoterNotesTable, VoterNote>,
          ),
          VoterNote,
          PrefetchHooks Function()
        > {
  $$VoterNotesTableTableManager(_$NavigatorsDatabase db, $VoterNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoterNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoterNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoterNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> voterId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> turfId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoterNotesCompanion(
                id: id,
                voterId: voterId,
                userId: userId,
                turfId: turfId,
                content: content,
                visibility: visibility,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String voterId,
                required String userId,
                required String turfId,
                required String content,
                Value<String> visibility = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoterNotesCompanion.insert(
                id: id,
                voterId: voterId,
                userId: userId,
                turfId: turfId,
                content: content,
                visibility: visibility,
                createdAt: createdAt,
                updatedAt: updatedAt,
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

typedef $$VoterNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$NavigatorsDatabase,
      $VoterNotesTable,
      VoterNote,
      $$VoterNotesTableFilterComposer,
      $$VoterNotesTableOrderingComposer,
      $$VoterNotesTableAnnotationComposer,
      $$VoterNotesTableCreateCompanionBuilder,
      $$VoterNotesTableUpdateCompanionBuilder,
      (
        VoterNote,
        BaseReferences<_$NavigatorsDatabase, $VoterNotesTable, VoterNote>,
      ),
      VoterNote,
      PrefetchHooks Function()
    >;

class $NavigatorsDatabaseManager {
  final _$NavigatorsDatabase _db;
  $NavigatorsDatabaseManager(this._db);
  $$VotersTableTableManager get voters =>
      $$VotersTableTableManager(_db, _db.voters);
  $$ContactLogsTableTableManager get contactLogs =>
      $$ContactLogsTableTableManager(_db, _db.contactLogs);
  $$SyncOperationsTableTableManager get syncOperations =>
      $$SyncOperationsTableTableManager(_db, _db.syncOperations);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$TurfAssignmentsTableTableManager get turfAssignments =>
      $$TurfAssignmentsTableTableManager(_db, _db.turfAssignments);
  $$SurveyFormsTableTableManager get surveyForms =>
      $$SurveyFormsTableTableManager(_db, _db.surveyForms);
  $$SurveyResponsesTableTableManager get surveyResponses =>
      $$SurveyResponsesTableTableManager(_db, _db.surveyResponses);
  $$VoterNotesTableTableManager get voterNotes =>
      $$VoterNotesTableTableManager(_db, _db.voterNotes);
}
