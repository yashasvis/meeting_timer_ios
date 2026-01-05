import 'dart:async';
import 'dart:ui';

import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:ios_calendar_demo/Screens/calendar_page.dart';
import 'package:ios_calendar_demo/Screens/countdown_page.dart';
import 'package:ios_calendar_demo/Screens/login_page.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'Model/calendar_events_model.dart';
import 'Model/app_theme.dart';
import 'dart:io' show Platform;
import 'package:timezone/data/latest.dart' as tz;

import 'NotificationService.dart';

final navigatorKey = GlobalKey<NavigatorState>();
List<String> lastShownNotification = [];
ValueNotifier<Duration?> countdownNotifier = ValueNotifier(null);
DateTime? eventStartDate;
DateTime? eventEndDate;
bool isLoading = false;

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight
  ]);
  KeepScreenOn.turnOn();

  await initializeServices();

  if (Platform.isAndroid) {
    FlutterBackgroundService().startService();
    FlutterBackgroundService().invoke('setAsForeground');
  }
  else{
    tz.initializeTimeZones();
    await NotificationService.init();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  bool isConnectedToVPN = false;

  Future checkFirstSeen() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.reload();
    int isLoggedIn = 0;
    isLoggedIn = preferences.getInt('isLoggedIn') ?? 0;
    String loggedDate = preferences.getString('LoggedDate') ?? '';
    if(loggedDate != ""){
      DateTime dateTime = DateTime.parse(DateFormat('yyyy-MM-dd').format(DateTime.now()));
      if(dateTime.isAfter(DateTime.parse(loggedDate))){
        preferences.remove('LoggedDate');

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginPage(navigatorKey)),
        );
      }
    }

    if(preferences.containsKey('HasScheduleWorkStarted')){
      var hasScheduleWorkStarted = preferences.getBool('HasScheduleWorkStarted') ?? false;
      if(hasScheduleWorkStarted){
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CountdownWidget(countdownNotifier,navigatorKey)),
        );
      }
    }

    if(eventStartDate != null){
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CountdownWidget(countdownNotifier,navigatorKey)),
      );
    }
    else{
      if (isLoggedIn > 0){
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CalendarPage("",navigatorKey)),
        );
      }
      else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginPage(navigatorKey)),
        );
      }
    }

    FlutterBackgroundService()
        .on("showCountdownPage")
        .listen((event) async {
      if (!mounted) return;

      SharedPreferences preferences = await SharedPreferences.getInstance();
      preferences.reload();

      String loggedDate = preferences.getString('LoggedDate') ?? '';
      if(loggedDate != ""){
        DateTime dateTime = DateTime.parse(DateFormat('yyyy-MM-dd').format(DateTime.now()));
        if(dateTime.isAfter(DateTime.parse(loggedDate))){
          preferences.remove('LoggedDate');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LoginPage(navigatorKey)),
          );
        }
      }

      if(eventStartDate != null) {
        if (!DateTime.now().isAfter(eventStartDate!)) {
          DateTime eventStart = eventStartDate!.toLocal();
          countdownNotifier.value = eventStart.difference(DateTime.now());
        }
      }

      preferences.reload();
      if(!preferences.containsKey('alreadyRedirected')){
        preferences.setBool('alreadyRedirected', true);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CountdownWidget(countdownNotifier, navigatorKey),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    checkFirstSeen();

    if (Platform.isIOS) {
      Timer.periodic(
        const Duration(seconds: 5),
            (_) => fetchUpcomingMeeting(),
      );
    }
  }

  @override
  void dispose() {
    KeepScreenOn.turnOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      body: const Text(""),
    );
  }
}

Future<void> initializeServices() async{
  const notificationId = 888;
  var service = FlutterBackgroundService();
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    "foreground_channel_id",
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
    showBadge: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    iosConfiguration: IosConfiguration(),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: "foreground_channel_id",
      initialNotificationTitle: 'Meeting Timer',
      initialNotificationContent: 'Meeting Timer Application is running.',
      foregroundServiceNotificationId: notificationId,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if(service is AndroidServiceInstance){
    service.on("setAsForeground").listen((event){
      service.setAsForegroundService();
    });
    service.on("setAsBackground").listen((event){
      service.setAsBackgroundService();
    });
  }

  service.on("stopService").listen((event){
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 1),(timer) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.reload();
    if(eventStartDate != null){
      if (!DateTime.now().isAfter(eventStartDate!)) {
        DateTime eventStart = eventStartDate!.toLocal();
        countdownNotifier.value = eventStart.difference(DateTime.now());
      }
      else{
        isLoading = false;
        lastShownNotification = [];
        eventStartDate = null;
      }
    }

    if(lastShownNotification.isNotEmpty){
      var isLoggedIn = preferences.getInt('isLoggedIn') ?? 0;
      var isTimerShown = preferences.getBool('isTimerShown') ?? false;
      bool isMeetingRunningOver = isTimerShown ? preferences.getBool('isMeetingRunningOver') ?? false : false;
      preferences.setBool('HasNextMeetingAdded', true);
      if(isLoggedIn > 0) {
        if(!isMeetingRunningOver){
          if(!isTimerShown){
            service.invoke("showCountdownPage");
          }
        }
      }
    }
  });

  Timer.periodic(const Duration(seconds: 5),(timer) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.reload();
    if(service is AndroidServiceInstance) {
      if(lastShownNotification.isEmpty){
        var isLoggedIn = preferences.getInt('isLoggedIn') ?? 0;
        if(isLoggedIn > 0){
          final Config config = Config(
            tenant: "common",
            clientId: "fd5ccd50-5603-4e29-b149-2bedc44a3a89",
            scope: "openid profile offline_access User.Read Calendars.ReadWrite Calendars.Read",
            navigatorKey: navigatorKey,
            redirectUri: ThemeModel.baseUrl,
            prompt: "consent",
          );

          final AadOAuth oauth = AadOAuth(config);
          String? token = await oauth.getAccessToken();

          if(token != null){
            DateTime startDate = DateTime.now();
            DateTime endDate = DateTime.now().add(const Duration(minutes: 5,seconds: 8));

            final startUtc = '${startDate.toUtc().toIso8601String().split('.').first}Z';
            final endUtc   = '${endDate.toUtc().toIso8601String().split('.').first}Z';
            final dio = Dio();
            final response = await dio.get("https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=$startUtc&endDateTime=$endUtc",
              options: Options(headers: {
                "Authorization": "Bearer $token"
              }),
            );

            final data = response.data;
            final List<dynamic> eventList = data['value'] ?? [];
            var events = eventList
                .map((e) => CalendarEventsModel.fromJson(e as Map<String, dynamic>))
                .toList();
            if(events.isNotEmpty){
              for (var e in events) {
                if(e.isDraft == false && !lastShownNotification.contains(e.id)){
                  var location = "";
                  var content = e.body['content'];
                  bool isMeetingJoining = false;
                  if(content.toString().contains("Join online meeting")){
                    dom.Document document = html.parse(content.toString());

                    document.body!.querySelectorAll("*").forEach((element) {
                      if (element.text.contains("Join online meeting")) {
                        element.remove();
                        isMeetingJoining = true;
                      }
                      if (element.text.contains("..............")) {
                        element.remove();
                      }
                    });

                    content = document.body!.innerHtml;
                  }
                  if(e.location.isNotEmpty){
                    var locations = e.location.containsKey('displayName') ? true : false;
                    var meeting = locations ? e.location['displayName'] : "";
                    location = meeting;
                  }

                  if(isMeetingJoining){
                    var meetingUrl = e.onlineMeeting!['joinUrl'];
                    preferences.setString('meetingUrl',meetingUrl);
                  }
                  else{
                    preferences.remove('meetingUrl');
                  }

                  preferences.setString('meetingTitle', location);
                  preferences.setString('content', content);
                  preferences.setString('subject', e.subject);

                  lastShownNotification.add(e.id);

                  eventStartDate = DateTime.parse(e.start['dateTime']+"Z");
                  eventEndDate = DateTime.parse(e.end['dateTime']+"Z");

                  preferences.setString('eventEndDate', eventEndDate.toString());
                  preferences.setString('eventStartDate', eventStartDate.toString());

                  bool hasScheduleWorkStarted = preferences.getBool('HasScheduleWorkStarted') ?? false;
                  if(hasScheduleWorkStarted){
                    preferences.setBool('HasNextMeetingAdded',true);
                  }
                }
              }
            }
          }
        }
      }
      else{
        preferences.setBool('HasNextMeetingAdded', true);
      }
    }
  });
}

Future<void> fetchUpcomingMeeting() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();

  final Config config = Config(
    tenant: "common",
    clientId: "fd5ccd50-5603-4e29-b149-2bedc44a3a89",
    scope: "openid profile offline_access User.Read Calendars.ReadWrite Calendars.Read",
    navigatorKey: navigatorKey,
    redirectUri: ThemeModel.baseUrl,
    prompt: "consent",
  );

  final AadOAuth oauth = AadOAuth(config);
  final token = await oauth.getAccessToken();
  if (token == null) return;

  DateTime start = DateTime.now();
  DateTime end = DateTime.now().add(const Duration(minutes: 5));

  final dio = Dio();
  final response = await dio.get(
    "https://graph.microsoft.com/v1.0/me/calendarView"
        "?startDateTime=${start.toUtc().toIso8601String()}"
        "&endDateTime=${end.toUtc().toIso8601String()}",
    options: Options(headers: {"Authorization": "Bearer $token"}),
  );

  final events = (response.data['value'] as List)
      .map((e) => CalendarEventsModel.fromJson(e))
      .toList();

  if (events.isEmpty) return;

  final e = events.first;

  eventStartDate = DateTime.parse(e.start['dateTime'] + "Z");
  eventEndDate = DateTime.parse(e.end['dateTime'] + "Z");

  preferences.setString('eventStartDate', eventStartDate.toString());
  preferences.setString('eventEndDate', eventEndDate.toString());

  if (navigatorKey.currentState != null) {
    countdownNotifier.value =
        eventStartDate!.difference(DateTime.now());

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) =>
            CountdownWidget(countdownNotifier, navigatorKey),
      ),
    );
  }
}
