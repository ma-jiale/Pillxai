//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PrescriptionsApi {
  PrescriptionsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Versions
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  Future<Response> listPrescriptionVersionsWithHttpInfo(String residentId, String prescriptionId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/prescriptions/{prescription_id}/versions'
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

  /// Versions
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  Future<List<PrescriptionView>?> listPrescriptionVersions(String residentId, String prescriptionId, { Future<void>? abortTrigger, }) async {
    final response = await listPrescriptionVersionsWithHttpInfo(residentId, prescriptionId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PrescriptionView>') as List)
        .cast<PrescriptionView>()
        .toList(growable: false);

    }
    return null;
  }

  /// List Prescriptions
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  Future<Response> listPrescriptionsWithHttpInfo(String residentId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/prescriptions'
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

  /// List Prescriptions
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  Future<List<PrescriptionView>?> listPrescriptions(String residentId, { Future<void>? abortTrigger, }) async {
    final response = await listPrescriptionsWithHttpInfo(residentId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<PrescriptionView>') as List)
        .cast<PrescriptionView>()
        .toList(growable: false);

    }
    return null;
  }

  /// Put
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  ///
  /// * [SavePrescription] savePrescription (required):
  Future<Response> savePrescriptionWithHttpInfo(String residentId, String prescriptionId, SavePrescription savePrescription, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/residents/{resident_id}/prescriptions/{prescription_id}'
      .replaceAll('{resident_id}', residentId)
      .replaceAll('{prescription_id}', prescriptionId);

    // ignore: prefer_final_locals
    Object? postBody = savePrescription;

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

  /// Put
  ///
  /// Parameters:
  ///
  /// * [String] residentId (required):
  ///
  /// * [String] prescriptionId (required):
  ///
  /// * [SavePrescription] savePrescription (required):
  Future<PrescriptionView?> savePrescription(String residentId, String prescriptionId, SavePrescription savePrescription, { Future<void>? abortTrigger, }) async {
    final response = await savePrescriptionWithHttpInfo(residentId, prescriptionId, savePrescription, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'PrescriptionView',) as PrescriptionView;
    
    }
    return null;
  }
}
