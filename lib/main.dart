import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:com.raj.raj_pdv_gestor/conexao_ws.dart';
import 'package:com.raj.raj_pdv_gestor/globais.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart' as dio;
import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as per;
//import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Gestor ERP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print("Iniciando SplashScreen"); // Log para debug

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showPermissionDialog();
      }
    });
  }

  Future<void> _showPermissionDialog() async {
    if (mounted) {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    await Future.delayed(Duration(milliseconds: 100));

    await Permission.camera.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.videos.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.microphone.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.storage.request();
    // await Permission.location.request();
    // await Permission.locationAlways.request();

    Map<Permission, per.PermissionStatus> statuses = await [
      Permission.camera,
      Permission.videos,
      Permission.microphone,
      Permission.storage,
      // Permission.location,
      // Permission.locationAlways,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => MyHomePage(title: "App Gestor")),
        );
      }
    } else {
      if (mounted) {
        // if (!Platform.isIOS) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //         content: Text('Permissões necessárias não foram concedidas.')),
        //   );
        // }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => MyHomePage(title: "App Gestor")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  InAppWebViewController? _webViewController;
  bool temInternet = true;
  bool carregando = true;
  //Location location = Location();
  int usuarioLogado = 0;
  String clienteConexao = "";
  String codigo_usuario = "";
  String codigo_cliente = "";

  late int tempoRastreio = 150;

  // NOVA FUNÇÃO: Abrir WhatsApp
  Future<void> _openWhatsApp(String data) async {
    try {
      print('📱 Tentando abrir WhatsApp com dados: $data');

      // Tenta decodificar como JSON primeiro
      Map<String, dynamic>? parsedData;
      String phoneNumber = '';
      String message = '';

      try {
        parsedData = json.decode(data);
        phoneNumber = parsedData!['phone'] ?? data;
        message = parsedData['message'] ?? '';
      } catch (e) {
        // Se não for JSON, trata como número simples
        phoneNumber = data;
      }

      // Remove caracteres não numéricos
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      print('🔗 Número limpo: $cleanNumber');

      if (Platform.isIOS) {
        // iOS: Tenta primeiro o app nativo
        await _openWhatsAppIOS(cleanNumber, message);
      } else {
        // Android: Usa wa.me que funciona bem
        await _openWhatsAppAndroid(cleanNumber, message);
      }
    } catch (e) {
      print('❌ Erro ao abrir WhatsApp: $e');
      _showSnackBar('Erro ao abrir WhatsApp: $e');
    }
  }

  // Função específica para iOS
  Future<void> _openWhatsAppIOS(String phoneNumber, String message) async {
    try {
      // URL do app nativo do WhatsApp no iOS
      String nativeUrl = "whatsapp://send?phone=$phoneNumber";
      if (message.isNotEmpty) {
        nativeUrl += "&text=${Uri.encodeComponent(message)}";
      }

      print('🍎 Tentando app nativo iOS: $nativeUrl');

      final Uri nativeUri = Uri.parse(nativeUrl);

      // Tenta abrir o app nativo primeiro
      if (await canLaunchUrl(nativeUri)) {
        bool launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          print('✅ WhatsApp iOS nativo aberto com sucesso');
          return;
        }
      }

      // Fallback para WhatsApp Web se o app nativo falhar
      print('⚠️ App nativo falhou, tentando WhatsApp Web...');
      String webUrl = "https://wa.me/$phoneNumber";
      if (message.isNotEmpty) {
        webUrl += "?text=${Uri.encodeComponent(message)}";
      }

      final Uri webUri = Uri.parse(webUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        print('✅ WhatsApp Web aberto como fallback');
      } else {
        _showSnackBar('WhatsApp não está instalado');
      }
    } catch (e) {
      print('❌ Erro ao abrir WhatsApp no iOS: $e');
      _showSnackBar('Erro ao abrir WhatsApp: $e');
    }
  }

  // Função específica para Android
  Future<void> _openWhatsAppAndroid(String phoneNumber, String message) async {
    try {
      // Para Android, wa.me funciona bem e abre o app automaticamente
      String whatsappUrl = "https://wa.me/$phoneNumber";
      if (message.isNotEmpty) {
        whatsappUrl += "?text=${Uri.encodeComponent(message)}";
      }

      print('🔗 URL do WhatsApp: $whatsappUrl');

      // Tenta abrir o WhatsApp
      final Uri uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          print('✅ WhatsApp aberto com sucesso');
        } else {
          print('❌ Falha ao abrir WhatsApp');
          _showSnackBar('Erro ao abrir WhatsApp');
        }
      } else {
        print('❌ Não é possível abrir a URL: $whatsappUrl');
        _showSnackBar('WhatsApp não está instalado');
      }
    } catch (e) {
      print('❌ Erro ao abrir WhatsApp: $e');
      _showSnackBar('Erro ao abrir WhatsApp: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> verificarVersao() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String versaoAtual = packageInfo.version;

      final response = await http.get(Uri.parse(
          'https://play.google.com/store/apps/details?id=com.raj.raj_pdv_gestor&pli=1'));

      if (response.statusCode == 200) {
        RegExp regex = RegExp(r'\[\[\["(\d+\.\d+\.\d+)"\]\]');
        Match? match = regex.firstMatch(response.body);

        if (match != null) {
          String versaoLoja = match.group(1) ?? '';

          print('Versão da Play Store: $versaoLoja');
          print('Versão instalada: $versaoAtual');

          if (_compararVersoes(versaoAtual, versaoLoja) < 0) {
            _mostrarDialogoAtualizacao(versaoLoja);
          }
        } else {
          print('Versão do app não encontrada na Play Store');
        }
      } else {
        print('Erro ao acessar a Play Store');
      }
    } catch (e) {
      print('Erro ao verificar versão: $e');
    }
  }

  void _mostrarDialogoAtualizacao(versaoLoja) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Atualização Necessária'),
        content: Text(
            'Uma nova versão ($versaoLoja) do App Gestor está disponível. Por favor, atualize para continuar usando.'),
        actions: [
          TextButton(
            child: Text('Atualizar Agora'),
            onPressed: () async {
              final url = 'market://details?id=com.raj.raj_pdv_gestor';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                await launchUrl(Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.raj.raj_pdv_gestor'));
              }
            },
          ),
        ],
      ),
    );
  }

  int _compararVersoes(String atual, String loja) {
    List<int> partesAtual = atual.split('.').map(int.parse).toList();
    List<int> partesLoja = loja.split('.').map(int.parse).toList();

    for (int i = 0; i < partesAtual.length; i++) {
      if (partesLoja.length <= i) return 1;
      if (partesAtual[i] < partesLoja[i]) return -1;
      if (partesAtual[i] > partesLoja[i]) return 1;
    }
    return partesLoja.length > partesAtual.length ? -1 : 0;
  }

  Future<void> getLocation() async {
    /*
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          print('Serviço de localização não está ativado');
          return;
        }
      }

      LocationData currentLocation = await location.getLocation();

      print(
          'LatitudeApp: ${currentLocation.latitude}, LongitudeApp: ${currentLocation.longitude}');

      if (usuarioLogado == 1) {
        await sendLocation(
            currentLocation.latitude!,
            currentLocation.longitude!,
            currentLocation.speed!,
            currentLocation.heading!);
      }
    } catch (e) {
      print("Erro ao obter a localização: $e");
    }*/
  }

  Future<bool> enviaRastreioRomaneio(
      String latitudeUsuario,
      String longitudeUsuario,
      String velocidade,
      String rumo,
      String codigoUsuario,
      String clienteConexao) async {
    dio.Response<dynamic>? res = await EnvioRastreioWS.enviaRastreioRomaneioWS(
        codigoRegional: "1",
        codigoUsuario: codigoUsuario,
        codigoUnidade: "1",
        codigoClientePmobile: "1",
        latitudeUsuario: latitudeUsuario,
        longitudeUsuario: longitudeUsuario,
        velocidade: velocidade,
        rumo: rumo,
        clienteConexao: clienteConexao);

    if (res != null && res.data != null) {
      var decodedData = jsonDecode(res.data);

      if (decodedData is List && decodedData.isNotEmpty) {
        Map<String, dynamic> json = decodedData[0];
        if (json["valido"] == 1) {
          return true;
        } else {
          return false;
        }
      } else {
        print("Formato inesperado da resposta da API");
        return false;
      }
    }
    if (mounted) {
      setState(() {});
    }
    return false;
  }

  bool retorno = false;

  Future<void> sendLocation(
      double latitude, double longitude, double velocidade, double rumo) async {
    retorno = await enviaRastreioRomaneio(
        latitude.toString(),
        longitude.toString(),
        velocidade.toString(),
        rumo.toString(),
        codigo_usuario,
        clienteConexao);

    if (retorno) {
      print("Localização enviada");
    } else {
      print("Falha ao enviar localização do usuário");
    }
  }

  Future<void> downloadFile(String url, String savePath) async {
    try {
      final dio.Dio client = dio.Dio();
      final response = await client.get(
        url,
        options: dio.Options(
          responseType: dio.ResponseType.bytes,
          followRedirects: true,
          headers: {
            'Accept': 'application/pdf',
          },
        ),
      );

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.data);

        if (await file.exists()) {
          await OpenFile.open(savePath);
        } else {
          print("Arquivo não encontrado");
        }
      } else {
        throw Exception('Erro ao baixar o arquivo: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro no download: $e');
    }
  }

  bool _isRunning = true;

  void startLocationUpdates() async {
    if (tempoRastreio == 0) {
      _isRunning = false;
      return;
    }

    while (_isRunning) {
      try {
        // await getLocation();
      } catch (e) {
        print("Erro ao obter localização periódica: $e");
      }

      try {
        // await Future.delayed(Duration(seconds: tempoRastreio));
      } catch (e) {
        print("Erro no delay: $e");
      }
    }
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    try {
      // await location.enableBackgroundMode(enable: true);

      try {
        temInternet = await InternetConnection().hasInternetAccess;
      } catch (e) {
        print('Erro ao verificar internet: $e');
        temInternet = true; // Assume que há internet se o check falhar
      }

      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
      if (Platform.isAndroid) {
        verificarVersao();
      }
    } catch (e) {
      print('Erro em didChangeDependencies: $e');
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

// NOVA FUNÇÃO: Verificar permissão de armazenamento (compatível com Android 13+)
Future<bool> _hasStoragePermission() async {
  if (Platform.isAndroid) {
    // Android 13+ (API 33+) não precisa de permissão para Downloads
    // Mas podemos verificar se temos acesso
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    
    if (androidInfo.version.sdkInt >= 33) {
      // Android 13+: Downloads é sempre acessível, não precisa de permissão
      print('📱 Android 13+: Acesso direto a Downloads');
      return true;
    } else {
      // Android 12 e inferior: verificar permissão de storage
      final status = await Permission.storage.status;
      print('📱 Android <13: Storage permission = $status');
      return status.isGranted;
    }
  }
  return true; // iOS sempre permite
}
  @override
  void initState() {
    super.initState();
    // startLocationUpdates();
  }

  @override
  void dispose() {
    _isRunning = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return Scaffold(
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: const Row(
            children: [
              Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Spacer(),
                  CircularProgressIndicator(),
                  Spacer(),
                ],
              ),
              Spacer(),
            ],
          ),
        ),
      );
    }

    if (!temInternet) {
      return Scaffold(
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: const Row(
            children: [
              Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Spacer(),
                  Text(
                    'Ops! Erro ao carregar página:\n\nPor favor verifique sua internet.',
                    textAlign: TextAlign.center,
                  ),
                  Spacer(),
                ],
              ),
              Spacer(),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Scaffold(
          body: InAppWebView(
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              return GeolocationPermissionShowPromptResponse(
                allow: Platform.isIOS ? false : true,
                origin: origin,
                retain: true,
              );
            },
            initialUrlRequest: URLRequest(
              url: WebUri.uri(Uri.tryParse(
                      'https://rajtecnologiaws.com.br//rajpdv/app_gestor/login.php?versaoApp=${Globais.versaoAtual}') ??
                  Uri()),
            ),
            onDownloadStartRequest: (controller, downloadStartRequest) async {
              final url = downloadStartRequest.url.toString();
              final filename =
                  downloadStartRequest.suggestedFilename ?? 'file.pdf';

              print('📥 Iniciando download: $filename');
              print('🔗 URL: $url');

              try {
                Directory? directory;

                if (Platform.isAndroid) {
                  // Android 13+ (API 33+) - Usar diretório público Downloads
                  if (await _hasStoragePermission()) {
                    // Usar pasta Downloads pública (não precisa de permissão especial)
                    directory = Directory('/storage/emulated/0/Download');

                    // Se não existir, criar
                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }
                  } else {
                    // Fallback: usar pasta interna do app (sempre permitida)
                    directory = await getApplicationDocumentsDirectory();
                    print('⚠️ Usando diretório interno do app');
                  }
                } else if (Platform.isIOS) {
                  // iOS: usar diretório de documentos do app
                  directory = await getApplicationDocumentsDirectory();
                }

                if (directory != null) {
                  final filePath = '${directory.path}/$filename';
                  print('💾 Salvando em: $filePath');

                  await downloadFile(url, filePath);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Download concluído: $filename'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }

                  // Tentar abrir o arquivo
                  final result = await OpenFile.open(filePath);
                  if (result.type == ResultType.error) {
                    print('❌ Erro ao abrir: ${result.message}');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Arquivo baixado mas não foi possível abrir'),
                          action: SnackBarAction(
                            label: 'OK',
                            onPressed: () {},
                          ),
                        ),
                      );
                    }
                  } else {
                    print('✅ Arquivo aberto com sucesso');
                  }
                } else {
                  throw Exception('Não foi possível acessar o armazenamento');
                }
              } catch (e) {
                print('❌ Erro no download: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao baixar arquivo: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              allowsPictureInPictureMediaPlayback: true,
              isFraudulentWebsiteWarningEnabled: false,
              supportZoom: false,
              builtInZoomControls: false,
              displayZoomControls: false,
              javaScriptEnabled: true, // IMPORTANTE: Habilita JavaScript
            ),
            onWebViewCreated: (InAppWebViewController controller) {
              _webViewController = controller;

              // NOVA FUNCIONALIDADE: Adiciona handler para WhatsApp
              controller.addJavaScriptHandler(
                  handlerName: 'whatsappHandler',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      _openWhatsApp(args[0].toString());
                    }
                  });

              print('✅ JavaScript Handler para WhatsApp adicionado');
            },
            onLoadStop: (controller, url) async {
              // Injeta JavaScript para criar a função global
              await controller.evaluateJavascript(source: '''
                window.openWhatsApp = function(phoneNumber, message) {
                  console.log('📱 openWhatsApp chamado:', phoneNumber, message);
                  
                  var data = {
                    phone: phoneNumber,
                    message: message || ''
                  };
                  
                  // Chama o handler do Flutter
                  window.flutter_inappwebview.callHandler('whatsappHandler', JSON.stringify(data));
                };
                
                console.log('✅ Função openWhatsApp injetada no JavaScript');
              ''');
            },
            onPermissionRequest: (controller, request) async {
              print('📱 Permissões solicitadas: ${request.resources}');
              print('🌐 Origin: ${request.origin}');

              // Verificar status atual das permissões
              bool cameraGranted = await Permission.camera.isGranted;
              bool microphoneGranted = await Permission.microphone.isGranted;
              bool storageGranted = await Permission.storage.isGranted;

              print('🎥 Camera: $cameraGranted');
              print('🎤 Microphone: $microphoneGranted');
              print('💾 Storage: $storageGranted');

              // Lista para recursos aprovados
              List<PermissionResourceType> grantedResources = [];

              for (var resource in request.resources) {
                if (resource == PermissionResourceType.CAMERA) {
                  if (cameraGranted) {
                    grantedResources.add(resource);
                    print('✅ CAMERA aprovada');
                  } else {
                    print('❌ CAMERA negada');
                  }
                } else if (resource == PermissionResourceType.MICROPHONE) {
                  if (microphoneGranted) {
                    grantedResources.add(resource);
                    print('✅ MICROPHONE aprovada');
                  } else {
                    print('❌ MICROPHONE negada');
                  }
                } else if (resource ==
                    PermissionResourceType.CAMERA_AND_MICROPHONE) {
                  // ✅ CORREÇÃO: Verificar AMBAS as permissões
                  if (cameraGranted && microphoneGranted) {
                    grantedResources.add(resource);
                    print('✅ CAMERA_AND_MICROPHONE aprovada');
                  } else {
                    print(
                        '❌ CAMERA_AND_MICROPHONE negada - Camera: $cameraGranted, Mic: $microphoneGranted');
                  }
                } else if (resource == PermissionResourceType.FILE_READ_WRITE) {
                  if (storageGranted) {
                    grantedResources.add(resource);
                    print('✅ FILE_READ_WRITE aprovada');
                  } else {
                    print('❌ FILE_READ_WRITE negada');
                  }
                } else {
                  print('⚠️ Recurso desconhecido: $resource');
                }
              }

              // Retornar resposta baseada nos recursos aprovados
              if (grantedResources.length == request.resources.length) {
                print('🎉 Todas as permissões concedidas: $grantedResources');
                return PermissionResponse(
                  resources: grantedResources,
                  action: PermissionResponseAction.GRANT,
                );
              } else {
                print('🚫 Algumas permissões negadas');
                print('   Solicitadas: ${request.resources}');
                print('   Aprovadas: $grantedResources');
                return PermissionResponse(
                  action: PermissionResponseAction.PROMPT,
                );
              }
            },
            onConsoleMessage: (controller, consoleMessage) {
              if (consoleMessage.messageLevel == ConsoleMessageLevel.LOG) {
                final message = consoleMessage.message;

                try {
                  final data = jsonDecode(message);
                  print("versaoApp: ${data['versaoApp']}");

                  if (data is Map<String, dynamic> && data['valido'] == 1) {
                    codigo_usuario = data['codigo_usuario'];
                    clienteConexao = data['clienteConexao'];
                    tempoRastreio = data['tempoRastreio'];
                    usuarioLogado = 1;
                  }
                } catch (e) {
                  print("Mensagem de console não é um JSON válido: $message");
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
