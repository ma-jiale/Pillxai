//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class ExecutionApi {
  ExecutionApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Bind Label
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [BindLabel] bindLabel (required):
  Future<Response> bindLabelWithHttpInfo(String residentId, BindLabel bindLabel, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/labels'
      .replaceAll('{resident_id}', residentId);

    // ignore: prefer_final_locals
    Object? postBody = bindLabel;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Bind Label
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [BindLabel] bindLabel (required):
  Future<LabelView?> bindLabel(String residentId, BindLabel bindLabel, { Future<void>? abortTrigger, }) async {
    final response = await bindLabelWithHttpInfo(residentId, bindLabel, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'LabelView',) as LabelView;
    
    }
    return null;
  }

  /// Cancel Task
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [DiscardTask] discardTask (required):
  Future<Response> cancelTaskWithHttpInfo(String taskId, DiscardTask discardTask, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}/cancel'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody = discardTask;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Cancel Task
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [DiscardTask] discardTask (required):
  Future<TaskView?> cancelTask(String taskId, DiscardTask discardTask, { Future<void>? abortTrigger, }) async {
    final response = await cancelTaskWithHttpInfo(taskId, discardTask, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TaskView',) as TaskView;
    
    }
    return null;
  }

  /// Claim Task
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [ClaimTask] claimTask (required):
  Future<Response> claimTaskWithHttpInfo(String taskId, ClaimTask claimTask, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody = claimTask;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Claim Task
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [ClaimTask] claimTask (required):
  Future<TaskView?> claimTask(String taskId, ClaimTask claimTask, { Future<void>? abortTrigger, }) async {
    final response = await claimTaskWithHttpInfo(taskId, claimTask, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TaskView',) as TaskView;
    
    }
    return null;
  }

  /// Discard Task
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [DiscardTask] discardTask (required):
  Future<Response> discardTaskWithHttpInfo(String taskId, DiscardTask discardTask, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}/discard'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody = discardTask;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Discard Task
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [DiscardTask] discardTask (required):
  Future<TaskReceipt?> discardTask(String taskId, DiscardTask discardTask, { Future<void>? abortTrigger, }) async {
    final response = await discardTaskWithHttpInfo(taskId, discardTask, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TaskReceipt',) as TaskReceipt;
    
    }
    return null;
  }

  /// Get Parameters
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  Future<Response> getParametersWithHttpInfo(String residentId, String prescriptionId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/prescriptions/{prescription_id}/parameters'
      .replaceAll('{resident_id}', residentId)
      .replaceAll('{prescription_id}', prescriptionId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Get Parameters
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  Future<ParameterView?> getParameters(String residentId, String prescriptionId, { Future<void>? abortTrigger, }) async {
    final response = await getParametersWithHttpInfo(residentId, prescriptionId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ParameterView',) as ParameterView?;
    
    }
    return null;
  }

  /// Get Task
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  Future<Response> getTaskWithHttpInfo(String taskId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Get Task
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  Future<TaskView?> getTask(String taskId, { Future<void>? abortTrigger, }) async {
    final response = await getTaskWithHttpInfo(taskId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TaskView',) as TaskView;
    
    }
    return null;
  }

  /// List Devices
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listDevicesWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/devices';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List Devices
  Future<List<DeviceView>?> listDevices({ Future<void>? abortTrigger, }) async {
    final response = await listDevicesWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<DeviceView>') as List)
        .cast<DeviceView>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Labels
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  Future<Response> listLabelsWithHttpInfo(String residentId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/labels'
      .replaceAll('{resident_id}', residentId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List Labels
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  Future<List<LabelView>?> listLabels(String residentId, { Future<void>? abortTrigger, }) async {
    final response = await listLabelsWithHttpInfo(residentId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<LabelView>') as List)
        .cast<LabelView>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Events
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [int] after:
  Future<Response> listTaskEventsWithHttpInfo(String taskId, { int? after, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}/events'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (after != null) {
      queryParams.addAll(_queryParams('', 'after', after));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List Events
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [int] after:
  Future<List<StoredEvent>?> listTaskEvents(String taskId, { int? after, Future<void>? abortTrigger, }) async {
    final response = await listTaskEventsWithHttpInfo(taskId, after: after, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<StoredEvent>') as List)
        .cast<StoredEvent>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Tasks
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] active:
  Future<Response> listTasksWithHttpInfo({ bool? active, Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (active != null) {
      queryParams.addAll(_queryParams('', 'active', active));
    }

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// List Tasks
  ///
  /// Parameters:
  ///
  /// * [bool] active:
  Future<List<TaskView>?> listTasks({ bool? active, Future<void>? abortTrigger, }) async {
    final response = await listTasksWithHttpInfo(active: active, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<TaskView>') as List)
        .cast<TaskView>()
        .toList(growable: false);

    }
    return null;
  }

  /// Save Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] deviceId (required):
  ///
  /// * [SaveDevice] saveDevice (required):
  Future<Response> saveDeviceWithHttpInfo(String deviceId, SaveDevice saveDevice, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/devices/{device_id}'
      .replaceAll('{device_id}', deviceId);

    // ignore: prefer_final_locals
    Object? postBody = saveDevice;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Save Device
  ///
  /// Parameters:
  ///
  /// * [String] deviceId (required):
  ///
  /// * [SaveDevice] saveDevice (required):
  Future<DeviceView?> saveDevice(String deviceId, SaveDevice saveDevice, { Future<void>? abortTrigger, }) async {
    final response = await saveDeviceWithHttpInfo(deviceId, saveDevice, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'DeviceView',) as DeviceView;
    
    }
    return null;
  }

  /// Save Parameters
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  ///
  /// * [MedicationParameters] medicationParameters (required):
  Future<Response> saveParametersWithHttpInfo(String residentId, String prescriptionId, MedicationParameters medicationParameters, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/prescriptions/{prescription_id}/parameters'
      .replaceAll('{resident_id}', residentId)
      .replaceAll('{prescription_id}', prescriptionId);

    // ignore: prefer_final_locals
    Object? postBody = medicationParameters;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Save Parameters
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  ///
  /// * [MedicationParameters] medicationParameters (required):
  Future<ParameterView?> saveParameters(String residentId, String prescriptionId, MedicationParameters medicationParameters, { Future<void>? abortTrigger, }) async {
    final response = await saveParametersWithHttpInfo(residentId, prescriptionId, medicationParameters, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ParameterView',) as ParameterView?;
    
    }
    return null;
  }

  /// Start Task
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [StartTask] startTask (required):
  Future<Response> startTaskWithHttpInfo(String taskId, StartTask startTask, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}/start'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody = startTask;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Start Task
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [StartTask] startTask (required):
  Future<TaskView?> startTask(String taskId, StartTask startTask, { Future<void>? abortTrigger, }) async {
    final response = await startTaskWithHttpInfo(taskId, startTask, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TaskView',) as TaskView;
    
    }
    return null;
  }

  /// Sync Events
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [SyncEvents] syncEvents (required):
  Future<Response> syncEventsWithHttpInfo(String taskId, SyncEvents syncEvents, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/tasks/{task_id}/events'
      .replaceAll('{task_id}', taskId);

    // ignore: prefer_final_locals
    Object? postBody = syncEvents;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
      abortTrigger: abortTrigger,
    );
  }

  /// Sync Events
  ///
  /// Parameters:
  ///
  /// * [String] taskId (required):
  ///
  /// * [SyncEvents] syncEvents (required):
  Future<TaskView?> syncEvents(String taskId, SyncEvents syncEvents, { Future<void>? abortTrigger, }) async {
    final response = await syncEventsWithHttpInfo(taskId, syncEvents, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TaskView',) as TaskView;
    
    }
    return null;
  }
}
