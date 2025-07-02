import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:com.raj.raj_pdv_gestor/conexao_ws.dart';
import 'package:com.raj.raj_pdv_gestor/globais.dart';
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
import 'package:location/location.dart';
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
      title: 'EasyApplication ERP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
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
    await Future.delayed(Duration(milliseconds: 100));

    if (Platform.isIOS) {
      Map<Permission, per.PermissionStatus> statuses = await [
        Permission.locationWhenInUse,
      ].request();
    }

    await Future.delayed(
      Duration(milliseconds: 100),
    );

    Map<Permission, per.PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      // Permission.location,
      // Permission.locationAlways,
      // Permission.microphone
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MyHomePage(title: "EasyApplication"),
          ),
        );
      }
    } else {

      if (mounted) {

        _requestPermissions();

        
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      Map<Permission, per.PermissionStatus> statuses = await [
        Permission.locationWhenInUse,
      ].request();
    }
    await Future.delayed(Duration(milliseconds: 100));

    await Permission.camera.request();
    await Permission.videos.request();
    await Permission.microphone.request();
    // await Permission.location.request();
    // await Permission.locationAlways.request();

    Map<Permission, per.PermissionStatus> statuses = await [
      Permission.camera,
      Permission.videos,
      Permission.microphone
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
        if (!Platform.isIOS) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Permissões necessárias não foram concedidas.')),
          );
        }

        // Mesmo sem todas as permissões, avançar para a tela principal
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
  Location location = Location();
  int usuarioLogado = 0;
  String clienteConexao = "";
  String codigo_usuario = "";
  String codigo_cliente = "";

  late int tempoRastreio = 150;

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
            'Uma nova versão ($versaoLoja) do EasyApplication está disponível. Por favor, atualize para continuar usando.'),
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
    }
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

      verificarVersao();
    } catch (e) {
      print('Erro em didChangeDependencies: $e');
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
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
                  allow: true, origin: origin, retain: true);
            },
            initialUrlRequest: URLRequest(
              url: WebUri.uri(
                  Uri.tryParse('https://rajtecnologiaws.com.br//rajpdv/app_gestor/login.php?versaoApp=${Globais.versaoAtual}') ??
                      Uri()),
            ),
            onDownloadStartRequest: (controller, downloadStartRequest) async {
              final url = downloadStartRequest.url.toString();
              final filename =
                  downloadStartRequest.suggestedFilename ?? 'file.pdf';

              if (await Permission.manageExternalStorage.request().isGranted) {
                Directory? directory;
                if (Platform.isAndroid) {
                  directory = Directory('/storage/emulated/0/Download');
                } else if (Platform.isIOS) {
                  directory = await getApplicationDocumentsDirectory();
                }

                if (directory != null) {
                  final filePath = '${directory.path}/$filename';
                  await downloadFile(url, filePath);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Download concluído: $filePath')),
                  );

                  final result = await OpenFile.open(filePath);
                  if (result.type == ResultType.error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Erro ao abrir o arquivo: ${result.message}'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Erro ao acessar o armazenamento.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Permissão de armazenamento negada.')),
                );
              }
            },
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,            
            ),
            onWebViewCreated: (InAppWebViewController controller) {
              _webViewController = controller;
            },
            onPermissionRequest: (controller, request) async {
              if (request.resources.contains(PermissionResourceType.CAMERA) &&
                  await Permission.camera.isGranted) {
                return PermissionResponse(
                    resources: [PermissionResourceType.CAMERA],
                    action: PermissionResponseAction.GRANT);
              }

              if (request.resources
                      .contains(PermissionResourceType.MICROPHONE) &&
                  await Permission.microphone.isGranted) {
                return PermissionResponse(
                    resources: [PermissionResourceType.MICROPHONE],
                    action: PermissionResponseAction.GRANT);
              }

              if (request.resources
                      .contains(PermissionResourceType.CAMERA_AND_MICROPHONE) &&
                  await Permission.camera.isGranted) {
                return PermissionResponse(
                    resources: [PermissionResourceType.CAMERA_AND_MICROPHONE],
                    action: PermissionResponseAction.GRANT);
              }

              if (request.resources
                      .contains(PermissionResourceType.FILE_READ_WRITE) &&
                  await Permission.storage.isGranted) {
                return PermissionResponse(
                    resources: [PermissionResourceType.FILE_READ_WRITE],
                    action: PermissionResponseAction.GRANT);
              }

              return PermissionResponse(action: PermissionResponseAction.DENY);
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
