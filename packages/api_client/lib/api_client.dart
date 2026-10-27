//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ApiClient {
  ApiClient({this.basePath = 'http://localhost', this.authentication,});

  final String basePath;
  final Authentication? authentication;

  var _client = Client();
  final _defaultHeaderMap = <String, String>{};

  /// Returns the current HTTP [Client] instance to use in this class.
  ///
  /// The return value is guaranteed to never be null.
  Client get client => _client;

  /// Requests to use a new HTTP [Client] in this class.
  set client(Client newClient) {
    _client = newClient;
  }

  Map<String, String> get defaultHeaderMap => _defaultHeaderMap;

  void addDefaultHeader(String key, String value) {
     _defaultHeaderMap[key] = value;
  }

  // We don't use a Map<String, String> for queryParams.
  // If collectionFormat is 'multi', a key might appear multiple times.
  Future<Response> invokeAPI(
    String path,
    String method,
    List<QueryParam> queryParams,
    Object? body,
    Map<String, String> headerParams,
    Map<String, String> formParams,
    String? contentType, {
    Future<void>? abortTrigger,
  }) async {
    await authentication?.applyToParams(queryParams, headerParams);

    headerParams.addAll(_defaultHeaderMap);
    if (contentType != null) {
      headerParams['Content-Type'] = contentType;
    }

    final urlEncodedQueryParams = queryParams.map((param) => '$param');
    final queryString = urlEncodedQueryParams.isNotEmpty ? '?${urlEncodedQueryParams.join('&')}' : '';
    final uri = Uri.parse('$basePath$path$queryString');

    try {
      // Special case for uploading a single file which isn't a 'multipart/form-data'.
      if (
        body is MultipartFile && (contentType == null ||
        !contentType.toLowerCase().startsWith('multipart/form-data'))
      ) {
        final request = AbortableStreamedRequest(method, uri, abortTrigger: abortTrigger);
        request.headers.addAll(headerParams);
        request.contentLength = body.length;
        body.finalize().listen(
          request.sink.add,
          onDone: request.sink.close,
          // ignore: avoid_types_on_closure_parameters
          onError: (Object error, StackTrace trace) => request.sink.close(),
          cancelOnError: true,
        );
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      if (body is MultipartRequest) {
        final request = AbortableMultipartRequest(method, uri, abortTrigger: abortTrigger);
        request.fields.addAll(body.fields);
        request.files.addAll(body.files);
        request.headers.addAll(body.headers);
        request.headers.addAll(headerParams);
        final response = await _client.send(request);
        return Response.fromStream(response);
      }

      final msgBody = contentType == 'application/x-www-form-urlencoded'
        ? formParams
        : await serializeAsync(body);
      final nullableHeaderParams = headerParams.isEmpty ? null : headerParams;

      final request = AbortableRequest(method, uri, abortTrigger: abortTrigger);
      if (nullableHeaderParams != null) {
        request.headers.addAll(nullableHeaderParams);
      }
      if (msgBody is String && msgBody.isNotEmpty) {
        request.body = msgBody;
      } else if (msgBody is List<int> && msgBody.isNotEmpty) {
        request.bodyBytes = msgBody;
      } else if (msgBody is Map<String, String>) {
        request.bodyFields = msgBody;
      }
      final response = await _client.send(request);
      return Response.fromStream(response);
    } on SocketException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Socket operation failed: $method $path',
        error,
        trace,
      );
    } on TlsException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'TLS/SSL communication failed: $method $path',
        error,
        trace,
      );
    } on IOException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'I/O operation failed: $method $path',
        error,
        trace,
      );
    } on ClientException catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'HTTP connection failed: $method $path',
        error,
        trace,
      );
    } on Exception catch (error, trace) {
      throw ApiException.withInner(
        HttpStatus.badRequest,
        'Exception occurred: $method $path',
        error,
        trace,
      );
    }
  }

  Future<dynamic> deserializeAsync(String value, String targetType, {bool growable = false,}) async =>
    // ignore: deprecated_member_use_from_same_package
    deserialize(value, targetType, growable: growable);

  @Deprecated('Scheduled for removal in OpenAPI Generator 6.x. Use deserializeAsync() instead.')
  dynamic deserialize(String value, String targetType, {bool growable = false,}) {
    // Remove all spaces. Necessary for regular expressions as well.
    targetType = targetType.replaceAll(' ', ''); // ignore: parameter_assignments

    // If the expected target type is String, nothing to do...
    return targetType == 'String'
      ? value
      : fromJson(json.decode(value), targetType, growable: growable);
  }

  // ignore: deprecated_member_use_from_same_package
  Future<String> serializeAsync(Object? value) async => serialize(value);

  @Deprecated('Scheduled for removal in OpenAPI Generator 6.x. Use serializeAsync() instead.')
  String serialize(Object? value) => value == null ? '' : json.encode(value);

  /// Returns a native instance of an OpenAPI class matching the [specified type][targetType].
  static dynamic fromJson(dynamic value, String targetType, {bool growable = false,}) {
    try {
      switch (targetType) {
        case 'String':
          return value is String ? value : value.toString();
        case 'int':
          return value is int ? value : int.parse('$value');
        case 'double':
          return value is double ? value : double.parse('$value');
        case 'bool':
          if (value is bool) {
            return value;
          }
          final valueString = '$value'.toLowerCase();
          return valueString == 'true' || valueString == '1';
        case 'DateTime':
          return value is DateTime ? value : DateTime.tryParse(value);
        case 'AccountView':
          return AccountView.fromJson(value);
        case 'ActionResult':
          return ActionResult.fromJson(value);
        case 'ApiError':
          return ApiError.fromJson(value);
        case 'AppSettings':
          return AppSettings.fromJson(value);
        case 'BatchPlan':
          return BatchPlan.fromJson(value);
        case 'BindLabel':
          return BindLabel.fromJson(value);
        case 'ChangePassword':
          return ChangePassword.fromJson(value);
        case 'ClaimTask':
          return ClaimTask.fromJson(value);
        case 'ContractSample':
          return ContractSample.fromJson(value);
        case 'CreateAccount':
          return CreateAccount.fromJson(value);
        case 'DeviceConfiguration':
          return DeviceConfiguration.fromJson(value);
        case 'DeviceMode':
          return DeviceModeTypeTransformer().decode(value);
        case 'DeviceView':
          return DeviceView.fromJson(value);
        case 'DiscardTask':
          return DiscardTask.fromJson(value);
        case 'DoseAmounts':
          return DoseAmounts.fromJson(value);
        case 'DoseUnit':
          return DoseUnitTypeTransformer().decode(value);
        case 'ExecutionEvent':
          return ExecutionEvent.fromJson(value);
        case 'FeedForm':
          return FeedFormTypeTransformer().decode(value);
        case 'Health':
          return Health.fromJson(value);
        case 'LabelView':
          return LabelView.fromJson(value);
        case 'LearningAdjustment':
          return LearningAdjustment.fromJson(value);
        case 'LearningEvidence':
          return LearningEvidence.fromJson(value);
        case 'LearningResult':
          return LearningResult.fromJson(value);
        case 'LearningSample':
          return LearningSample.fromJson(value);
        case 'Login':
          return Login.fromJson(value);
        case 'LoginResult':
          return LoginResult.fromJson(value);
        case 'MealRelation':
          return MealRelationTypeTransformer().decode(value);
        case 'MedicationParameters':
          return MedicationParameters.fromJson(value);
        case 'ParameterView':
          return ParameterView.fromJson(value);
        case 'PlanMedicine':
          return PlanMedicine.fromJson(value);
        case 'PlanPreview':
          return PlanPreview.fromJson(value);
        case 'PlanSnapshot':
          return PlanSnapshot.fromJson(value);
        case 'PlanTray':
          return PlanTray.fromJson(value);
        case 'PreparationItem':
          return PreparationItem.fromJson(value);
        case 'PrescriptionData':
          return PrescriptionData.fromJson(value);
        case 'PrescriptionView':
          return PrescriptionView.fromJson(value);
        case 'PreviewRequest':
          return PreviewRequest.fromJson(value);
        case 'RecognitionBinding':
          return RecognitionBinding.fromJson(value);
        case 'ResetPassword':
          return ResetPassword.fromJson(value);
        case 'ResidentData':
          return ResidentData.fromJson(value);
        case 'ResidentPage':
          return ResidentPage.fromJson(value);
        case 'ResidentView':
          return ResidentView.fromJson(value);
        case 'Role':
          return RoleTypeTransformer().decode(value);
        case 'SaveContractSample':
          return SaveContractSample.fromJson(value);
        case 'SaveDevice':
          return SaveDevice.fromJson(value);
        case 'SavePrescription':
          return SavePrescription.fromJson(value);
        case 'SaveResident':
          return SaveResident.fromJson(value);
        case 'SaveSettings':
          return SaveSettings.fromJson(value);
        case 'SavedContractSample':
          return SavedContractSample.fromJson(value);
        case 'StartTask':
          return StartTask.fromJson(value);
        case 'StoredEvent':
          return StoredEvent.fromJson(value);
        case 'SyncEvents':
          return SyncEvents.fromJson(value);
        case 'TaskReceipt':
          return TaskReceipt.fromJson(value);
        case 'TaskState':
          return TaskStateTypeTransformer().decode(value);
        case 'TaskView':
          return TaskView.fromJson(value);
        case 'UpdateAccount':
          return UpdateAccount.fromJson(value);
        default:
          dynamic match;
          if (value is List && (match = _regList.firstMatch(targetType)?.group(1)) != null) {
            return value
              .map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,))
              .toList(growable: growable);
          }
          if (value is Set && (match = _regSet.firstMatch(targetType)?.group(1)) != null) {
            return value
              .map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,))
              .toSet();
          }
          if (value is Map && (match = _regMap.firstMatch(targetType)?.group(1)) != null) {
            return Map<String, dynamic>.fromIterables(
              value.keys.cast<String>(),
              value.values.map<dynamic>((dynamic v) => fromJson(v, match, growable: growable,)),
            );
          }
      }
    } on Exception catch (error, trace) {
      throw ApiException.withInner(HttpStatus.internalServerError, 'Exception during deserialization.', error, trace,);
    }
    throw ApiException(HttpStatus.internalServerError, 'Could not find a suitable class for deserialization',);
  }
}

/// Primarily intended for use in an isolate.
class DeserializationMessage {
  const DeserializationMessage({
    required this.json,
    required this.targetType,
    this.growable = false,
  });

  /// The JSON value to deserialize.
  final String json;

  /// Target type to deserialize to.
  final String targetType;

  /// Whether to make deserialized lists or maps growable.
  final bool growable;
}

/// Primarily intended for use in an isolate.
Future<dynamic> decodeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
    ? message.json
    : json.decode(message.json);
}

/// Primarily intended for use in an isolate.
Future<dynamic> deserializeAsync(DeserializationMessage message) async {
  // Remove all spaces. Necessary for regular expressions as well.
  final targetType = message.targetType.replaceAll(' ', '');

  // If the expected target type is String, nothing to do...
  return targetType == 'String'
    ? message.json
    : ApiClient.fromJson(
        json.decode(message.json),
        targetType,
        growable: message.growable,
      );
}

/// Primarily intended for use in an isolate.
Future<String> serializeAsync(Object? value) async => value == null ? '' : json.encode(value);
