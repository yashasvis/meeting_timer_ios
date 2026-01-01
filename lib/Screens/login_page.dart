import 'dart:async';

import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ios_calendar_demo/Screens/calendar_page.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Model/app_theme.dart';
import 'no_internet_connection_page.dart';

class LoginPage extends StatefulWidget {
  final dynamic navigatorKey;

  const LoginPage(this.navigatorKey, {super.key});

  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  late GlobalKey<NavigatorState> navigatorKey;

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    KeepScreenOn.turnOn();
    cleanPreferences();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    super.initState();
  }

  @override
  void dispose() {
    KeepScreenOn.turnOff();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> cleanPreferences() async{
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.clear();
  }

  Future<void> initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException {
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      _connectionStatus = result[0];
    });
  }

  @override
  Widget build(BuildContext context) {
    return _connectionStatus.index != 4 ? Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final Config config = Config(
                    tenant: "common",
                    clientId: "fd5ccd50-5603-4e29-b149-2bedc44a3a89",
                    scope: "openid profile offline_access User.Read Calendars.ReadWrite Calendars.Read",
                    navigatorKey: widget.navigatorKey,
                    redirectUri: ThemeModel.baseUrl,
                    loader: const Center(child: CircularProgressIndicator(),),
                    postLogoutRedirectUri: ThemeModel.baseUrl,
                    customParameters: {
                      'login_hint': '',
                      'max_age': '0',
                    },
                    prompt: "login"
                  );

                  try {
                    final AadOAuth oauth = AadOAuth(config);
                    await oauth.logout();
                    try{
                      final result = await oauth.login();
                      result.fold(
                            (failure) async {
                          final errorMessage = failure.toString().toLowerCase();
                          if (errorMessage.contains('too many requests') ||
                              errorMessage.contains('429')) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Too many login attempts. Please wait a minute and try again.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        LoginPage(widget.navigatorKey)),
                              );
                            }
                          }
                        }, (token) async {
                          final SharedPreferences preferences =
                          await SharedPreferences.getInstance();
                          await preferences.setInt('isLoggedIn', 1);

                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CalendarPage(
                                    token.accessToken, widget.navigatorKey),
                              ),
                            );
                          }
                        },
                      );
                    } catch (e) {
                      if (kDebugMode) {
                        print("exception : $e");
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => LoginPage(widget.navigatorKey)),
                      );
                    }
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print("exception : $e");
                  }
                }
              },
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text("Sing In with Microsoft"),
            ),
          )
        ],
      ),
    ): const NoInternetConnectionPage();
  }
}
