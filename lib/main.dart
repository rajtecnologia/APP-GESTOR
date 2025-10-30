import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// 🆕 IMPORTAÇÕES PARA IMPRESSÃO BLUETOOTH
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

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
    print("Iniciando SplashScreen");

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

    // 🆕 Adicionar permissões Bluetooth
    await Permission.bluetoothScan.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.bluetoothConnect.request();
    await Future.delayed(Duration(milliseconds: 100));

    await Permission.camera.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.videos.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.microphone.request();
    await Future.delayed(Duration(milliseconds: 100));
    await Permission.storage.request();

    Map<Permission, per.PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.camera,
      Permission.videos,
      Permission.microphone,
      Permission.storage,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted || true) {
      // Permite prosseguir mesmo sem todas as permissões
      if (mounted) {
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
  int usuarioLogado = 0;
  String clienteConexao = "";
  String codigo_usuario = "";
  String codigo_cliente = "";

  late int tempoRastreio = 150;

  // 🆕 VARIÁVEIS PARA IMPRESSÃO BLUETOOTH
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _deviceConectado;
  bool _impressoraConectada = false;

  // 🆕 CONECTAR À IMPRESSORA BLUETOOTH
  Future<Map<String, dynamic>> _conectarImpressora(String? deviceName) async {
    try {
      print('🔍 Procurando impressoras Bluetooth...');

      // Buscar dispositivos pareados
      List<BluetoothDevice>? devices = await bluetooth.getBondedDevices();

      if (devices == null || devices.isEmpty) {
        return {
          'success': false,
          'error': 'Nenhuma impressora Bluetooth pareada encontrada'
        };
      }

      print('📱 Dispositivos encontrados: ${devices.length}');

      // Buscar dispositivo correto
      BluetoothDevice? device;

      if (deviceName != null && deviceName.isNotEmpty) {
        // Procurar pelo nome especificado
        print('🔎 Buscando dispositivo que contenha: "$deviceName"');

        // Tentar encontrar dispositivo que contenha o nome
        try {
          device = devices.firstWhere(
            (d) {
              final name = d.name?.toLowerCase() ?? '';
              final search = deviceName.toLowerCase();

              // Procurar por correspondências parciais
              bool match = name.contains(search) ||
                  name.contains(search.replaceAll('-', '')) ||
                  name.contains(search.replaceAll('_', ''));

              if (match) {
                print('✓ Encontrado: ${d.name}');
              }

              return match;
            },
          );
        } catch (e) {
          print(
              '⚠️ Dispositivo "$deviceName" não encontrado, procurando por PT...');
          // Se não encontrou, procurar por qualquer impressora
          device = null;
        }
      }

      // Se não encontrou ainda, procurar por PT260, PT-260, ou qualquer variação
      if (device == null) {
        print('🔎 Buscando dispositivo PT260/PT-260...');

        try {
          device = devices.firstWhere(
            (d) {
              final name = d.name?.toLowerCase() ?? '';
              bool isPrinter = name.contains('pt') ||
                  name.contains('260') ||
                  name.contains('print') ||
                  name.contains('thermal');

              if (isPrinter) {
                print('✓ Impressora encontrada: ${d.name}');
              }

              return isPrinter;
            },
          );
        } catch (e) {
          print(
              '⚠️ Nenhuma impressora encontrada, tentando primeiro dispositivo');
          device = devices.first;
        }
      }

      if (device == null) {
        return {
          'success': false,
          'error': 'Nenhum dispositivo adequado encontrado'
        };
      }

      print('🔗 Tentando conectar em: ${device.name}');

      // Desconectar se já estiver conectado
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
        await bluetooth.disconnect();
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Conectar
      await bluetooth.connect(device);
      await Future.delayed(
          Duration(seconds: 1)); // Aguardar conexão estabilizar

      // Verificar conexão
      isConnected = await bluetooth.isConnected;

      if (isConnected == true) {
        setState(() {
          _deviceConectado = device;
          _impressoraConectada = true;
        });

        print('✅ Conectado à impressora: ${device.name}');

        return {
          'success': true,
          'device': device.name,
          'message': 'Conectado com sucesso'
        };
      } else {
        return {'success': false, 'error': 'Falha ao conectar'};
      }
    } catch (e) {
      print('❌ Erro ao conectar impressora: $e');
      return {'success': false, 'error': 'Erro: $e'};
    }
  }

  // 🆕 LISTAR IMPRESSORAS BLUETOOTH
  Future<List<Map<String, String>>> _listarImpressoras() async {
    try {
      List<BluetoothDevice>? devices = await bluetooth.getBondedDevices();

      if (devices == null) {
        return [];
      }

      return devices
          .map((device) => {
                'name': device.name ?? 'Desconhecido',
                'address': device.address ?? '',
              })
          .toList();
    } catch (e) {
      print('❌ Erro ao listar impressoras: $e');
      return [];
    }
  }

  // 🆕 IMPRIMIR NA IMPRESSORA BLUETOOTH
  Future<Map<String, dynamic>> _imprimirBluetooth(String base64Commands) async {
    try {
      // Verificar se está conectado
      bool? isConnected = await bluetooth.isConnected;

      if (isConnected != true) {
        // Tentar conectar automaticamente
        var resultado = await _conectarImpressora(null);
        if (!resultado['success']) {
          return {
            'success': false,
            'error': 'Impressora não conectada. ${resultado['error']}'
          };
        }
      }

      print('📄 Imprimindo etiqueta...');

      // Decodificar Base64 para bytes
      Uint8List bytes = base64Decode(base64Commands);

      // Enviar para impressora
      bluetooth.writeBytes(bytes);

      // Aguardar impressão
      await Future.delayed(Duration(milliseconds: 500));

      print('✅ Etiqueta enviada para impressão');

      return {'success': true, 'message': 'Impresso com sucesso'};
    } catch (e) {
      print('❌ Erro ao imprimir: $e');
      return {'success': false, 'error': 'Erro ao imprimir: $e'};
    }
  }

  // NOVA FUNÇÃO: Abrir WhatsApp
  Future<void> _openWhatsApp(String data) async {
    try {
      print('📱 Tentando abrir WhatsApp com dados: $data');

      Map<String, dynamic>? parsedData;
      String phoneNumber = '';
      String message = '';

      try {
        parsedData = json.decode(data);
        phoneNumber = parsedData!['phone'] ?? data;
        message = parsedData['message'] ?? '';
      } catch (e) {
        phoneNumber = data;
      }

      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      print('🔗 Número limpo: $cleanNumber');

      if (Platform.isIOS) {
        await _openWhatsAppIOS(cleanNumber, message);
      } else {
        await _openWhatsAppAndroid(cleanNumber, message);
      }
    } catch (e) {
      print('❌ Erro ao abrir WhatsApp: $e');
      _showSnackBar('Erro ao abrir WhatsApp: $e');
    }
  }

  Future<void> _openWhatsAppIOS(String phoneNumber, String message) async {
    try {
      String nativeUrl = "whatsapp://send?phone=$phoneNumber";
      if (message.isNotEmpty) {
        nativeUrl += "&text=${Uri.encodeComponent(message)}";
      }

      print('🍎 Tentando app nativo iOS: $nativeUrl');
      final Uri nativeUri = Uri.parse(nativeUrl);

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

      print('⚠️ App nativo falhou, tentando WhatsApp Web...');
      String webUrl = "https://wa.me/$phoneNumber";
      if (message.isNotEmpty) {
        webUrl += "?text=${Uri.encodeComponent(message)}";
      }

      final Uri webUri = Uri.parse(webUrl);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('❌ Erro iOS WhatsApp: $e');
      _showSnackBar('Erro ao abrir WhatsApp: $e');
    }
  }

  Future<void> _openWhatsAppAndroid(String phoneNumber, String message) async {
    try {
      String url = "https://wa.me/$phoneNumber";
      if (message.isNotEmpty) {
        url += "?text=${Uri.encodeComponent(message)}";
      }

      print('🤖 Abrindo WhatsApp Android: $url');
      final Uri uri = Uri.parse(url);

      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        print('✅ WhatsApp Android aberto com sucesso');
      } else {
        print('⚠️ Falha ao abrir WhatsApp');
        _showSnackBar('Não foi possível abrir o WhatsApp');
      }
    } catch (e) {
      print('❌ Erro Android WhatsApp: $e');
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

  Future<bool> _hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return true;
      }
      return await Permission.storage.isGranted;
    }
    return true;
  }

  Future<void> downloadFile(String url, String savePath) async {
    try {
      print('📥 Baixando arquivo de: $url');
      print('💾 Salvando em: $savePath');

      Dio dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            int progress = ((received / total) * 100).toInt();
            print('📊 Progresso: $progress%');
          }
        },
      );

      print('✅ Download concluído: $savePath');
    } catch (e) {
      print('❌ Erro no download: $e');
      throw e;
    }
  }

  @override
  void initState() {
    super.initState();
    _verificarConexao();
  }

  Future<void> _verificarConexao() async {
    var connectivityResult = await InternetConnection().hasInternetAccess;

    setState(() {
      temInternet = connectivityResult;
      carregando = false;
    });

    InternetConnection().onStatusChange.listen((InternetStatus status) {
      switch (status) {
        case InternetStatus.connected:
          setState(() {
            temInternet = true;
          });
          print('Conectado à internet');
          break;
        case InternetStatus.disconnected:
          setState(() {
            temInternet = false;
          });
          print('Desconectado da internet');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!temInternet) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 100, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'Sem conexão com a internet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Verifique sua conexão e tente novamente'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    carregando = true;
                  });
                  _verificarConexao();
                },
                child: Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Container(
          child: InAppWebView(
            initialUrlRequest: URLRequest(
                url: WebUri(
                    'https://rajtecnologiaws.com.br//rajpdv/app_gestor/login.php?versaoApp=${Globais.versaoAtual}')),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: '''
                  console.log('Script injetado com sucesso!');
                ''',
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();

              if (url.startsWith('https://api.whatsapp.com') ||
                  url.startsWith('whatsapp://')) {
                print('🔗 Interceptado link do WhatsApp: $url');
                _openWhatsApp(url);
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            onCreateWindow: (controller, createWindowAction) async {
              final url = createWindowAction.request.url.toString();
              print('🆕 Nova janela solicitada: $url');

              if (url.startsWith('https://api.whatsapp.com') ||
                  url.startsWith('whatsapp://')) {
                print('📱 Redirecionando para WhatsApp');
                _openWhatsApp(url);
                return false;
              }

              await launchUrl(
                createWindowAction.request.url!,
                mode: LaunchMode.externalApplication,
              );
              return false;
            },
            onGeolocationPermissionsShowPrompt: (controller, origin) async {
              return GeolocationPermissionShowPromptResponse(
                origin: origin,
                allow: true,
                retain: true,
              );
            },
            onLoadError: (controller, url, code, message) {
              print('Erro ao carregar: $message (Code: $code)');
            },
            shouldInterceptRequest: (controller, request) async {
              return null;
            },
            shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
              return ajaxRequest;
            },
            onAjaxProgress: (controller, ajaxRequest) async {
              return AjaxRequestAction.PROCEED;
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.PROCEED);
            },
            shouldInterceptFetchRequest: (controller, fetchRequest) async {
              return null;
            },
            onLoadHttpError: (controller, url, statusCode, description) async {
              print('Erro HTTP: $statusCode - $description');
            },
            onLoadStart: (controller, url) {
              print('Iniciando carregamento: $url');
            },
            onNavigationResponse: (controller, response) async {
              return NavigationResponseAction.ALLOW;
            },
            onReceivedHttpAuthRequest: (controller, challenge) async {
              return HttpAuthResponse(
                  action: HttpAuthResponseAction.PROCEED,
                  username: "",
                  password: "",
                  permanentPersistence: false);
            },
            onReceivedError: (controller, request, error) {
              print('Erro recebido: ${error.description}');
            },
            onCloseWindow: (controller) {
              print('Janela fechada');
            },
            onReceivedClientCertRequest: (controller, challenge) async {
              return ClientCertResponse(
                  certificatePath: "",
                  certificatePassword: "",
                  action: ClientCertResponseAction.PROCEED,
                  keyStoreType: "PKCS12");
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              print('Histórico atualizado: $url');
            },
            onReceivedIcon: (controller, icon) {
              print('Ícone recebido');
            },
            onReceivedTouchIconUrl: (controller, url, precomposed) {
              print('Touch icon recebido: $url');
            },
            onJsAlert: (controller, jsAlertRequest) async {
              return JsAlertResponse();
            },
            onJsConfirm: (controller, jsConfirmRequest) async {
              return JsConfirmResponse();
            },
            onJsPrompt: (controller, jsPromptRequest) async {
              return JsPromptResponse();
            },
            onJsBeforeUnload: (controller, jsBeforeUnloadRequest) async {
              return JsBeforeUnloadResponse();
            },
            onReceivedLoginRequest: (controller, loginRequest) {
              print('Login request: ${loginRequest.realm}');
            },
            onPrintRequest: (controller, url, printJobController) async {
              print('Impressão solicitada');
              return false;
            },
            onWindowBlur: (controller) {
              print('Janela perdeu foco');
            },
            onWindowFocus: (controller) {
              print('Janela ganhou foco');
            },
            onZoomScaleChanged: (controller, oldScale, newScale) {
              print('Zoom alterado: $oldScale -> $newScale');
            },
            onPageCommitVisible: (controller, url) {
              print('Página visível: $url');
            },
            onProgressChanged: (controller, progress) {},
            onTitleChanged: (controller, title) {
              print('Título alterado: $title');
            },
            androidOnSafeBrowsingHit: (controller, url, threatType) async {
              return SafeBrowsingResponse(
                  action: SafeBrowsingResponseAction.PROCEED, report: true);
            },
            androidOnRenderProcessResponsive: (controller, url) async {
              print('Processo responsivo novamente');
              return WebViewRenderProcessAction.TERMINATE;
            },
            androidOnRenderProcessUnresponsive: (controller, url) async {
              print('Processo não responsivo');
              return WebViewRenderProcessAction.TERMINATE;
            },
            androidOnFormResubmission: (controller, url) async {
              return FormResubmissionAction.RESEND;
            },
            iosOnWebContentProcessDidTerminate: (controller) {
              print('Processo web terminou (iOS)');
            },
            iosOnNavigationResponse: (controller, response) async {
              return IOSNavigationResponseAction.ALLOW;
            },
            onFindResultReceived: (controller, activeMatchOrdinal,
                numberOfMatches, isDoneCounting) {
              print(
                  'Resultado da busca: $activeMatchOrdinal de $numberOfMatches');
            },
            onWebContentProcessDidTerminate: (controller) {
              print('Processo web terminou');
            },
            onDidReceiveServerRedirectForProvisionalNavigation: (controller) {
              print('Redirecionamento do servidor recebido');
            },
            androidOnReceivedIcon: (controller, icon) {
              print('Ícone recebido (Android)');
            },
            androidOnReceivedTouchIconUrl: (controller, url, precomposed) {
              print('Touch icon recebido (Android): $url');
            },
            androidOnJsBeforeUnload: (controller, jsBeforeUnloadRequest) async {
              return JsBeforeUnloadResponse();
            },
            onContentSizeChanged: (controller, oldContentSize, newContentSize) {
              print(
                  'Tamanho do conteúdo alterado: $oldContentSize -> $newContentSize');
            },
            pullToRefreshController: PullToRefreshController(
              settings: PullToRefreshSettings(
                  color: Colors.blue,
                  enabled: false,
                  distanceToTriggerSync: 0,
                  slingshotDistance: 0,
                  backgroundColor: Colors.transparent,
                  attributedTitle: null),
              onRefresh: () {},
            ),
            findInteractionController: FindInteractionController(),
            onLoadResource: (controller, resource) {},
            onScrollChanged: (controller, x, y) {},
            initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                    useOnDownloadStart: true,
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportZoom: false,
                    mediaPlaybackRequiresUserGesture: false,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    cacheEnabled: true,
                    clearCache: false,
                    disableContextMenu: false,
                    incognito: false,
                    transparentBackground: false,
                    disableHorizontalScroll: false,
                    disableVerticalScroll: false,
                    preferredContentMode: UserPreferredContentMode.MOBILE),
                android: AndroidInAppWebViewOptions(
                    allowContentAccess: true,
                    allowFileAccess: true,
                    useHybridComposition: true,
                    builtInZoomControls: false,
                    displayZoomControls: false,
                    supportMultipleWindows: true,
                    domStorageEnabled: true,
                    databaseEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    mixedContentMode:
                        AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    geolocationEnabled: true),
                ios: IOSInAppWebViewOptions(
                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true,
                    isFraudulentWebsiteWarningEnabled: false,
                    allowsLinkPreview: true,
                    ignoresViewportScaleLimits: false,
                    allowsBackForwardNavigationGestures: true)),
            onEnterFullscreen: (controller) {
              print('Entrou em fullscreen');
            },
            onExitFullscreen: (controller) {
              print('Saiu de fullscreen');
            },
            onOverScrolled: (controller, x, y, clampedX, clampedY) {},
            onDownloadStartRequest: (controller, downloadStartRequest) async {
              final url = downloadStartRequest.url.toString();
              final filename =
                  downloadStartRequest.suggestedFilename ?? 'file.pdf';

              print('📥 Iniciando download: $filename');
              print('🔗 URL: $url');

              try {
                Directory? directory;

                if (Platform.isAndroid) {
                  if (await _hasStoragePermission()) {
                    directory = Directory('/storage/emulated/0/Download');

                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }
                  } else {
                    directory = await getApplicationDocumentsDirectory();
                    print('⚠️ Usando diretório interno do app');
                  }
                } else if (Platform.isIOS) {
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
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (InAppWebViewController controller) {
              _webViewController = controller;

              // Handler para WhatsApp
              controller.addJavaScriptHandler(
                  handlerName: 'whatsappHandler',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      _openWhatsApp(args[0].toString());
                    }
                  });

              // 🆕 HANDLER PARA CONECTAR IMPRESSORA
              controller.addJavaScriptHandler(
                  handlerName: 'conectarImpressora',
                  callback: (args) async {
                    String? deviceName =
                        args.isNotEmpty ? args[0].toString() : null;
                    var resultado = await _conectarImpressora(deviceName);
                    return resultado;
                  });

              // 🆕 HANDLER PARA LISTAR IMPRESSORAS
              controller.addJavaScriptHandler(
                  handlerName: 'listarImpressoras',
                  callback: (args) async {
                    var impressoras = await _listarImpressoras();
                    return impressoras;
                  });

              // 🆕 HANDLER PARA IMPRIMIR
              controller.addJavaScriptHandler(
                  handlerName: 'imprimir',
                  callback: (args) async {
                    if (args.isEmpty) {
                      return {
                        'success': false,
                        'error': 'Nenhum comando fornecido'
                      };
                    }

                    String base64Commands = args[0].toString();
                    var resultado = await _imprimirBluetooth(base64Commands);
                    return resultado;
                  });

              // 🆕 HANDLER PARA VERIFICAR STATUS DA CONEXÃO
              controller.addJavaScriptHandler(
                  handlerName: 'verificarConexaoImpressora',
                  callback: (args) async {
                    bool? isConnected = await bluetooth.isConnected;
                    return {
                      'connected': isConnected ?? false,
                      'device': _deviceConectado?.name ?? ''
                    };
                  });

              print(
                  '✅ Handlers JavaScript adicionados (WhatsApp + Impressora)');
            },
            onLoadStop: (controller, url) async {
              // Injeta JavaScript para criar as funções globais
              await controller.evaluateJavascript(source: '''
                window.openWhatsApp = function(phoneNumber, message) {
                  console.log('📱 openWhatsApp chamado:', phoneNumber, message);
                  
                  var data = {
                    phone: phoneNumber,
                    message: message || ''
                  };
                  
                  window.flutter_inappwebview.callHandler('whatsappHandler', JSON.stringify(data));
                };
                
                // 🆕 Funções para impressão Bluetooth
                window.conectarImpressora = async function(deviceName) {
                  console.log('🔗 Conectando impressora:', deviceName);
                  try {
                    const resultado = await window.flutter_inappwebview.callHandler('conectarImpressora', deviceName || '');
                    console.log('✅ Resultado conexão:', resultado);
                    return resultado;
                  } catch (error) {
                    console.error('❌ Erro ao conectar:', error);
                    return { success: false, error: error.toString() };
                  }
                };
                
                window.listarImpressoras = async function() {
                  console.log('📋 Listando impressoras...');
                  try {
                    const impressoras = await window.flutter_inappwebview.callHandler('listarImpressoras');
                    console.log('📱 Impressoras encontradas:', impressoras);
                    return impressoras;
                  } catch (error) {
                    console.error('❌ Erro ao listar:', error);
                    return [];
                  }
                };
                
                window.imprimirBluetooth = async function(base64Commands) {
                  console.log('🖨️ Imprimindo via Bluetooth...');
                  try {
                    const resultado = await window.flutter_inappwebview.callHandler('imprimir', base64Commands);
                    console.log('✅ Resultado impressão:', resultado);
                    return resultado;
                  } catch (error) {
                    console.error('❌ Erro ao imprimir:', error);
                    return { success: false, error: error.toString() };
                  }
                };
                
                window.verificarConexaoImpressora = async function() {
                  console.log('🔍 Verificando conexão...');
                  try {
                    const status = await window.flutter_inappwebview.callHandler('verificarConexaoImpressora');
                    console.log('📊 Status:', status);
                    return status;
                  } catch (error) {
                    console.error('❌ Erro ao verificar:', error);
                    return { connected: false, device: '' };
                  }
                };
                
                console.log('✅ Funções de impressão Bluetooth injetadas');
              ''');
            },
            onPermissionRequest: (controller, request) async {
              print('📱 Permissões solicitadas: ${request.resources}');
              print('🌐 Origin: ${request.origin}');

              bool cameraGranted = await Permission.camera.isGranted;
              bool microphoneGranted = await Permission.microphone.isGranted;
              bool storageGranted = await Permission.storage.isGranted;

              print('🎥 Camera: $cameraGranted');
              print('🎤 Microphone: $microphoneGranted');
              print('💾 Storage: $storageGranted');

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
