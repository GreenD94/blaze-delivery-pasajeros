import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:taxibooking/utils/Extensions/app_common.dart';
import '../main.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import 'RestApis.dart';

// Función para logging de API calls
void logApiCall(String url, Map<String, String> headers, Map? body, Map? params, Response response) {
  // Códigos ANSI para colores
  const String redColor = '\x1B[31m';
  const String greenColor = '\x1B[32m';
  const String resetColor = '\x1B[0m';
  
  print('----------- START [$url]--------');
  print('--------------HEADER-----------');
  print(jsonEncode(headers));
  print('---------------------------');
  
  
    print('----------body or param-----');
    print('body:');
    print(jsonEncode(body));
  
  
  
    print('param:');
    print(jsonEncode(params));
  
  
  // Determinar si es éxito o error y aplicar color
  bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
  String statusText = isSuccess ? "success" : "error";
  String colorCode = isSuccess ? greenColor : redColor;
  
  print('${colorCode}-------------------$statusText response [${response.statusCode}]--------$resetColor');
  try {
    final responseJson = jsonDecode(response.body);
    final encoder = JsonEncoder.withIndent('  ');
    print('${colorCode}${encoder.convert(responseJson)}$resetColor');
  } catch (e) {
    print('${colorCode}${response.body}$resetColor');
  }
  print('${colorCode}----------------------$resetColor');
}

Map<String, String> buildHeaderTokens() {
  Map<String, String> header = {
    HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    HttpHeaders.cacheControlHeader: 'no-cache',
    HttpHeaders.acceptHeader: 'application/json; charset=utf-8',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Origin': '*',
  };
  if (appStore.isLoggedIn) {
    header.putIfAbsent(HttpHeaders.authorizationHeader, () => 'Bearer ${sharedPref.getString(TOKEN)}');
  }
  log(jsonEncode(header));
  return header;
}

Uri buildBaseUrl(String endPoint) {
  Uri url = Uri.parse(endPoint);
  if (!endPoint.startsWith('http')) url = Uri.parse('$mBaseUrl$endPoint');

  log('URL: ${url.toString()}');

  return url;
}

Future<Response> buildHttpResponse(String endPoint, {HttpMethod method = HttpMethod.GET, Map? request}) async {
  if (await isNetworkAvailable()) {
    var headers = buildHeaderTokens();
    Uri url = buildBaseUrl(endPoint);

    try {
      Response response;

      if (method == HttpMethod.POST) {
        log('Request: $request');

        response = await http.post(url, body: jsonEncode(request), headers: headers).timeout(Duration(seconds: 20), onTimeout: () => throw 'Timeout');
      } else if (method == HttpMethod.DELETE) {
        response = await delete(url, headers: headers).timeout(Duration(seconds: 20), onTimeout: () => throw 'Timeout');
      } else if (method == HttpMethod.PUT) {
        response = await put(url, body: jsonEncode(request), headers: headers).timeout(Duration(seconds: 20), onTimeout: () => throw 'Timeout');
      } else {
        response = await get(url, headers: headers).timeout(Duration(seconds: 20), onTimeout: () => throw 'Timeout');
      }

      // Logging personalizado de API call
      logApiCall(url.toString(), headers, request, null, response);

      return response;
    } catch (e) {
      throw 'Something Went Wrong';
    }
  } else {
    throw 'Your internet is not working';
  }
}

//region Common

Future handleResponse(Response response, [bool? avoidTokenError]) async {
  if (!await isNetworkAvailable()) {
    throw 'Your internet is not working';
  }
  if (response.statusCode == 401) {
    if (appStore.isLoggedIn) {
      Map req = {
        'email': sharedPref.getString(USER_EMAIL),
        'password': sharedPref.getString(USER_PASSWORD),
      };

      await logInApi(req).then((value) {
        throw 'Please try again.';
      }).catchError((e) {
        throw TokenException(e);
      });
    } else {
      throw '';
    }
  }

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    try {
      var body = jsonDecode(response.body);
      throw parseHtmlString(body['message']);
    } on Exception catch (e) {
      log(e);
      throw 'Something Went Wrong';
    }
  }
}

enum HttpMethod { GET, POST, DELETE, PUT }

class TokenException implements Exception {
  final String message;

  const TokenException([this.message = ""]);

  String toString() => "FormatException: $message";
}
