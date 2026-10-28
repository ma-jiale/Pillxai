//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class ContractApi {
  ContractApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] sampleId (required):
  Future<Response> getContractSampleWithHttpInfo(String sampleId, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/dev/contract-samples/{sample_id}'
      .replaceAll('{sample_id}', sampleId);

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

  /// Get
  ///
  /// Parameters:
  ///
  /// * [String] sampleId (required):
  Future<SavedContractSample?> getContractSample(String sampleId, { Future<void>? abortTrigger, }) async {
    final response = await getContractSampleWithHttpInfo(sampleId, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SavedContractSample',) as SavedContractSample;
    
    }
    return null;
  }

  /// Save
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SaveContractSample] saveContractSample (required):
  Future<Response> saveContractSampleWithHttpInfo(SaveContractSample saveContractSample, { Future<void>? abortTrigger, }) async {
    // ignore: prefer_const_declarations
    final path = r'/dev/contract-samples';

    // ignore: prefer_final_locals
    Object? postBody = saveContractSample;

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

  /// Save
  ///
  /// Parameters:
  ///
  /// * [SaveContractSample] saveContractSample (required):
  Future<SavedContractSample?> saveContractSample(SaveContractSample saveContractSample, { Future<void>? abortTrigger, }) async {
    final response = await saveContractSampleWithHttpInfo(saveContractSample, abortTrigger: abortTrigger,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'SavedContractSample',) as SavedContractSample;
    
    }
    return null;
  }
}
