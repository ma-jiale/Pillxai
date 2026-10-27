//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PlanningApi {
  PlanningApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Create Preview
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [PreviewRequest] previewRequest (required):
  Future<Response> createPlanPreviewWithHttpInfo(String residentId, PreviewRequest previewRequest, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/plans/preview'
      .replaceAll('{resident_id}', residentId);

    // ignore: prefer_final_locals
    Object? postBody = previewRequest;

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

  /// Create Preview
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [PreviewRequest] previewRequest (required):
  Future<PlanPreview?> createPlanPreview(String residentId, PreviewRequest previewRequest, { Future<void>? abortTrigger, }) async {
    final response = await createPlanPreviewWithHttpInfo(residentId, previewRequest, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PlanPreview',) as PlanPreview;
    
    }
    return null;
  }

  /// Get Preview
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  Future<Response> getPlanPreviewWithHttpInfo(String planId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/plans/{plan_id}'
      .replaceAll('{plan_id}', planId);

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

  /// Get Preview
  ///
  /// Parameters:
  ///
  /// * [String] planId (required):
  Future<PlanPreview?> getPlanPreview(String planId, { Future<void>? abortTrigger, }) async {
    final response = await getPlanPreviewWithHttpInfo(planId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PlanPreview',) as PlanPreview;
    
    }
    return null;
  }

  /// List Preparation
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> listPreparationWithHttpInfo({ Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/preparation';

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

  /// List Preparation
  Future<List<PreparationItem>?> listPreparation({ Future<void>? abortTrigger, }) async {
    final response = await listPreparationWithHttpInfo(abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PreparationItem>') as List)
        .cast<PreparationItem>()
        .toList(growable: false);

    }
    return null;
  }
}
