import 'dart:io';

import 'package:dio/dio.dart';

class EnvioRastreioWS {
  static Future<Response?> enviaRastreioRomaneioWS({
    String? codigoRegional,
    String? codigoUsuario,
    String? codigoUnidade,
    String? codigoClientePmobile,
    String? latitudeUsuario,
    String? longitudeUsuario,
    String? velocidade,
    String? rumo,
    String? clienteConexao
  
  }) async {
    final dio = Dio();
   
      String webservice = 'https://rajtecnologiaws.com.br/rajpdv/webservices/ws_easy_erp.php';
     
    try {
      // return await dio.get('', options: Options(headers: {
      return await dio.get(webservice, options: Options(headers: {
        HttpHeaders.acceptHeader: 'json/application/json',

      } ), queryParameters: {  		
        'metodo': 'RecebeRastreioNovo', 
        'latitude': latitudeUsuario,
        'longitude': longitudeUsuario,
        'velocidade': velocidade,
        'rumo': rumo,
        'codigo_regional': codigoRegional,
        'codigo_usuario': codigoUsuario,        
        'codigo_unidade': 1,
        'codigo_cliente_pmobile': 1,
        'cliente_conexao':clienteConexao      
        
      });
    } on DioException catch (e) {
      print("Erro na requisição: $e");
      return null;
    }
  }
}

