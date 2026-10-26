//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/contract_api.dart';
part 'api/default_api.dart';
part 'api/identity_api.dart';
part 'api/planning_api.dart';
part 'api/prescriptions_api.dart';
part 'api/residents_api.dart';
part 'api/settings_api.dart';

part 'model/account_view.dart';
part 'model/action_result.dart';
part 'model/api_error.dart';
part 'model/app_settings.dart';
part 'model/change_password.dart';
part 'model/contract_sample.dart';
part 'model/create_account.dart';
part 'model/dose_amounts.dart';
part 'model/dose_unit.dart';
part 'model/feed_form.dart';
part 'model/health.dart';
part 'model/login.dart';
part 'model/login_result.dart';
part 'model/meal_relation.dart';
part 'model/plan_medicine.dart';
part 'model/plan_preview.dart';
part 'model/plan_snapshot.dart';
part 'model/plan_tray.dart';
part 'model/prescription_data.dart';
part 'model/prescription_view.dart';
part 'model/preview_request.dart';
part 'model/reset_password.dart';
part 'model/resident_data.dart';
part 'model/resident_page.dart';
part 'model/resident_view.dart';
part 'model/role.dart';
part 'model/save_contract_sample.dart';
part 'model/save_prescription.dart';
part 'model/save_resident.dart';
part 'model/save_settings.dart';
part 'model/saved_contract_sample.dart';
part 'model/update_account.dart';


/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) => pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
