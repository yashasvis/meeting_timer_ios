import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:intl/intl.dart';
import 'package:ios_calendar_demo/Model/calendar_events_model.dart';
import 'package:ios_calendar_demo/Screens/login_page.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visuals_calendar/types/calendar_format.types.dart';
import 'package:visuals_calendar/types/event.types.dart';
import 'package:visuals_calendar/visuals_calendar.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../Model/app_theme.dart';
import 'no_internet_connection_page.dart';
import 'countdown_page.dart';

class CalendarPage extends StatefulWidget {
  final String? accessToken;
  final dynamic navigatorKey;
  const CalendarPage(this.accessToken, this.navigatorKey, {super.key});

  @override
  State<CalendarPage> createState() => _CalendarPage();
}

class _CalendarPage extends State<CalendarPage> {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool isCalendarLoading = false;
  bool isLoaded = false;
  String version='',firstName='',lastName='',email='';
  DateTime focusedDay = DateTime.now();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  List<CalendarEventsModel> events = [];
  final GlobalKey<VisualsCalendarState> _calendarKey = GlobalKey();
  var currentCalendarFormat = CalendarFormat.day;
  final GlobalKey _scaffoldKey = GlobalKey();

  final Map<String, Color> categoryColors = {
    "default": Colors.blue,
    "Purple category": Colors.purple,
    "Blue category": Colors.blue,
    "Green category": Colors.green,
    "Orange category": Colors.orange,
    "Red category": Colors.red.shade300,
    "Yellow category": Colors.yellow.shade700
  };

  List<Event> getEvents = [];

  @override
  void initState() {
    _getCalendarEvents();
    showTimer();
    if (Platform.isAndroid) {
      KeepScreenOn.turnOn();
    }
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    super.initState();
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      KeepScreenOn.turnOff();
    }
    _connectivitySubscription.cancel();
    super.dispose();
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

  void showTimer() async {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      version = packageInfo.version;
      setState(() {

      });
    });
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      preferences.reload();
      var isMeetingRunningOver =
          preferences.getBool('isMeetingRunningOver') ?? false;
      var isTimerShown = preferences.getBool('isTimerShown') ?? false;
      if (!isMeetingRunningOver ||
          !preferences.containsKey('isTimerShown') ||
          isTimerShown) {
        ValueNotifier<Duration?> countdownNotifier = ValueNotifier(null);
        var endDates = "";
        if (preferences.containsKey('currentMeetingTitle')) {
          endDates = preferences.getString('currentEndDate') ?? '';
        } else {
          endDates = preferences.getString('eventEndDate') ?? '';
        }
        if (endDates != "") {
          if (DateTime.now().isBefore(DateTime.parse(endDates))) {
            if (preferences.containsKey('HasScheduleWorkStarted')) {
              bool hasScheduleWorkStarted =
                  preferences.getBool('HasScheduleWorkStarted') ?? false;
              if (hasScheduleWorkStarted) {
                timer.cancel();
                preferences.reload();
                if (!preferences.containsKey('alreadyRedirected')) {
                  preferences.setBool('alreadyRedirected', true);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => CountdownWidget(
                            countdownNotifier, widget.navigatorKey)),
                  );
                }
              }
            }
            if (preferences.containsKey('eventStartDate')) {
              var eventStartDate =
                  preferences.getString('eventStartDate') ?? '';
              if (eventStartDate != "") {
                timer.cancel();
                var eventStartDateTime = DateTime.parse(eventStartDate);
                if (!DateTime.now().isAfter(eventStartDateTime)) {
                  DateTime eventStart = eventStartDateTime.toLocal();
                  setState(() {
                    countdownNotifier.value =
                        eventStart.difference(DateTime.now());
                  });
                  preferences.reload();
                  if (!preferences.containsKey('alreadyRedirected')) {
                    preferences.setBool('alreadyRedirected', true);
                    preferences.setBool('currentHasScheduleWorkStarted', true);
                    // Navigator.of(context).push(
                    //   MaterialPageRoute(builder: (_) => CountdownWidget(countdownNotifier,widget.navigatorKey)),
                    // );
                  }
                }
              }
            }
          }
        } else {
          if (preferences.containsKey('HasScheduleWorkStarted')) {
            bool hasScheduleWorkStarted =
                preferences.getBool('HasScheduleWorkStarted') ?? false;
            if (hasScheduleWorkStarted) {
              timer.cancel();
              preferences.reload();
              if (!preferences.containsKey('alreadyRedirected')) {
                preferences.setBool('alreadyRedirected', true);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => CountdownWidget(
                          countdownNotifier, widget.navigatorKey)),
                );
              }
            }
          }
          if (preferences.containsKey('eventStartDate')) {
            var eventStartDate = preferences.getString('eventStartDate') ?? '';
            if (eventStartDate != "") {
              timer.cancel();
              var eventStartDateTime = DateTime.parse(eventStartDate);
              if (!DateTime.now().isAfter(eventStartDateTime)) {
                DateTime eventStart = eventStartDateTime.toLocal();
                setState(() {
                  countdownNotifier.value =
                      eventStart.difference(DateTime.now());
                });
                preferences.reload();
                if (!preferences.containsKey('alreadyRedirected')) {
                  preferences.setBool('alreadyRedirected', true);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => CountdownWidget(
                            countdownNotifier, widget.navigatorKey)),
                  );
                }
              }
            }
          }
        }
      }
    });
  }

  Future<String?> getValidTokenKey() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.setInt('isLoggedIn', 1);
    preferences.setString(
        'LoggedDate', DateFormat('yyyy-MM-dd').format(DateTime.now()));

    final Config config = Config(
      tenant: "common",
      clientId: "fd5ccd50-5603-4e29-b149-2bedc44a3a89",
      scope:
          "openid profile offline_access User.Read Calendars.ReadWrite Calendars.Read",
      navigatorKey: widget.navigatorKey,
      redirectUri: ThemeModel.baseUrl,
      prompt: "consent",
    );

    final AadOAuth oauth = AadOAuth(config);

    try {
      return await oauth.getAccessToken();
    } catch (e) {
      await oauth.login();
      return await oauth.getAccessToken();
    }
  }

  void _getCalendarEvents() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    String loggedDate = preferences.getString('LoggedDate') ?? '';
    firstName = preferences.getString('firstName') ?? '';
    lastName = preferences.getString('lastName') ?? '';
    email = preferences.getString('email') ?? '';
    setState(() {
      
    });
    if (loggedDate != "") {
      DateTime dateTime =
          DateTime.parse(DateFormat('yyyy-MM-dd').format(DateTime.now()));
      if (dateTime.isAfter(DateTime.parse(loggedDate))) {
        preferences.remove('LoggedDate');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginPage(widget.navigatorKey)),
        );
      }
    }

    final accessToken = await getValidTokenKey();
    final dio = Dio();
    try {
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      endDate = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));

      setState(() {});

      final response = await dio.get(
        "https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=${startDate.toIso8601String()}Z&endDateTime=${endDate.toIso8601String()}Z&top=500",
        options: Options(headers: {
          "Authorization": "Bearer $accessToken",
        }),
      );

      final data = response.data;

      final List<dynamic> eventList = data['value'] ?? [];

      setState(() {
        events = eventList
            .map((e) => CalendarEventsModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

      if (events.isNotEmpty) {
        setState(() {
          getEvents = [];
        });
        for (var e in events) {
          final color = e.categories.isNotEmpty
              ? categoryColors[e.categories.first]
              : categoryColors['default']!;
          var location = "";
          var content = e.body['content'];
          var hasContent = true;
          bool isMeetingJoining = false;
          if (content.toString().contains("Join online meeting")) {
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
          if (e.location.isNotEmpty) {
            var locations =
                e.location.containsKey('displayName') ? true : false;
            var meeting = locations ? e.location['displayName'] : "";
            location = meeting;
          }
          RegExp brOnlyRegex =
              RegExp(r'^[ \n\r]*(<br\s*\/?>[ \n\r]*)*$', caseSensitive: true);
          if (brOnlyRegex.hasMatch(content) && content != "") {
            hasContent = false;
          }
          getEvents.add(Event(
              DateTime.parse(e.start['dateTime'] + "Z").toLocal(),
              e.subject,
              color!,
              end: DateTime.parse(e.end['dateTime'] + "Z").toLocal(),
              type: e.type, onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                Size screenSize = MediaQuery.of(context).size;
                return Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    width: double.infinity,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: screenSize.width * 0.70,
                            child: Text(
                              e.subject,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.clip,
                              ),
                              overflow: TextOverflow.clip,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: screenSize.width * 0.70,
                                child: Text(
                                    "${DateFormat('dd/MMM/yyyy hh:mm a').format(DateTime.parse(e.start['dateTime'] + "Z").toLocal())} - ${DateFormat('hh:mm a').format(DateTime.parse(e.end['dateTime'] + "Z").toLocal())}",
                                    style: const TextStyle(
                                        fontSize: 15,
                                        overflow: TextOverflow.clip),
                                    overflow: TextOverflow.clip),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (location != "")
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 20, color: Colors.blue),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    location,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          if (e.bodyPreview.isNotEmpty)
                            hasContent == true
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.dehaze_outlined,
                                          size: 20, color: Colors.blue),
                                      Flexible(child: Html(data: content)),
                                    ],
                                  )
                                : const Padding(padding: EdgeInsets.zero),
                          const SizedBox(height: 12),
                          if (isMeetingJoining)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.video_camera_front_outlined,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                Flexible(
                                    child: TextButton(
                                  onPressed: () async {
                                    await launchUrl(
                                      Uri.parse(e.onlineMeeting!['joinUrl']),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: const Text(
                                    "Join Teams Meeting",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                )),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("Close"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
              label: e.showAs,
              location: '',
              isAllDay: e.isAllDay,
              description: location));
        }
      }

      setState(() {});

      setState(() {
        isCalendarLoading = true;
        isLoaded = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  DateTime getStartOfWeek(DateTime date, {int startWeekday = DateTime.monday}) {
    int diff = date.weekday - startWeekday;
    if (diff < 0) diff += 7;
    return DateTime(date.year, date.month, date.day - diff);
  }

  DateTime getEndOfWeek(DateTime date, {int startWeekday = DateTime.monday}) {
    DateTime start = getStartOfWeek(date, startWeekday: startWeekday);
    return start.add(const Duration(days: 6));
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Platform.isAndroid) {
          final service = FlutterBackgroundService();
          service.invoke("stopService");
          exit(0);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: _connectionStatus != ConnectivityResult.none
          ? Scaffold(
                key:_scaffoldKey,
                backgroundColor: Colors.white,
                drawer: Drawer( 
                  child: ListView( 
                    padding: EdgeInsets.zero, 
                    children: [ 
                      DrawerHeader( 
                        decoration: BoxDecoration(color: Colors.blue.shade300,), 
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          Text('$firstName $lastName',style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            overflow: TextOverflow.clip,
                            fontWeight: FontWeight.bold
                          ),),
                          Text(email,style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            overflow: TextOverflow.clip,
                            fontWeight: FontWeight.bold
                          ),)
                        ],)
                      ), 
                      ListTile( 
                        leading: const Icon(Icons.logout), 
                        title: const Text('Logout'), 
                        onTap: () async {
                          try {
                            SharedPreferences
                                preferences =
                                await SharedPreferences
                                    .getInstance();
                            preferences
                                .remove('isLoggedIn');

                            final Config config = Config(
                              tenant: "common",
                              clientId:
                                  "fd5ccd50-5603-4e29-b149-2bedc44a3a89",
                              scope:
                                  "openid profile offline_access User.Read Calendars.ReadWrite Calendars.Read",
                              navigatorKey:
                                  widget.navigatorKey,
                              redirectUri:
                                  ThemeModel.baseUrl,
                              loader: const Center(
                                child:
                                    CircularProgressIndicator(),
                              ),
                              postLogoutRedirectUri:
                                  ThemeModel.baseUrl,
                              customParameters: {
                                'prompt': 'login',
                                // 'amr_values': 'mfa',
                                'login_hint': '',
                                'max_age':
                                    '0', // Forces fresh authentication
                              },
                              prompt: "login",
                            );

                            final AadOAuth oauth =
                                AadOAuth(config);
                            await oauth.logout();
                            await oauth.logout();

                            SharedPreferences preference =
                                await SharedPreferences
                                    .getInstance();
                            preference.clear();

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      LoginPage(widget
                                          .navigatorKey)),
                            );
                          } catch (e) {
                            if (kDebugMode) {
                              print(e);
                            }
                          }
                        },   
                      ), 
                      const Divider(),
                      Container(
                        width: screenSize.width,
                        margin: EdgeInsets.only(bottom: screenSize.height * 0.01,top: screenSize.height * 0.01),
                        padding: EdgeInsets.zero,
                        child: Text(
                          "Version $version",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cabin-Bold',
                            fontSize: 14,
                            color: Colors.blue.shade400
                          ),
                        ),
                      )
                    ], 
                  ), 
                ),
                body: isLoaded
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.zero,
                            child: SizedBox(
                              height: screenSize.height,
                              child: VisualsCalendar(
                                events: getEvents,
                                key: _calendarKey,
                                defaultFormat: CalendarFormat.day,
                                selectionEnabled: false,
                                onPageChanged: (start, end) {
                                  setState(() {
                                    startDate = start;
                                    endDate = end;
                                  });

                                  _getCalendarEvents(); // fetch events for that range
                                },
                                appBarBuilder: (
                                  BuildContext context,
                                  String title,
                                  CalendarFormat format,
                                  VoidCallback onLeftArrow,
                                  Function(CalendarFormat) onFormatChanged,
                                  List<CalendarFormat> availableFormats,
                                ) {
                                  return AppBar(
                                    backgroundColor: Colors.blue.shade300,
                                    automaticallyImplyLeading: false,
                                    title: Text(
                                      title,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    leading: IconButton( 
                                      icon: const Icon(Icons.menu, color: Colors.white), 
                                      onPressed: () { 
                                        Scaffold.of(context).openDrawer(); 
                                      }, 
                                    ),
                                    bottom: PreferredSize(
                                      preferredSize: const Size.fromHeight(56),
                                      child: _calendarFormatSelector(
                                        format,
                                            (newFormat) {
                                          onFormatChanged(newFormat);

                                          setState(() {
                                            currentCalendarFormat = newFormat;
                                          });
                                        },
                                      ),
                                    ),
                                    actions: [
                                      IconButton(
                                        style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero),
                                        onPressed: () async {
                                          SharedPreferences preferences =
                                              await SharedPreferences
                                                  .getInstance();
                                          var currentHasScheduleWorkStarted =
                                              preferences.getBool(
                                                      'currentHasScheduleWorkStarted') ??
                                                  false;
                                          if (currentHasScheduleWorkStarted) {
                                            ValueNotifier<Duration?>
                                                countdownNotifier =
                                                ValueNotifier(null);
                                            preferences.reload();
                                            if (!preferences.containsKey(
                                                'alreadyRedirected')) {
                                              preferences.setBool(
                                                  'alreadyRedirected', true);
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        CountdownWidget(
                                                            countdownNotifier,
                                                            widget
                                                                .navigatorKey)),
                                              );
                                            }
                                          } else {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) => super.widget),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.sync,
                                            color: Colors.white),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.calendar_month_outlined,
                                          color: Colors.white,
                                        ),
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: startDate,
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            format = CalendarFormat.day;
                                            onFormatChanged(format);
                                            if (format == CalendarFormat.day) {
                                              startDate = focusedDay;
                                              endDate = focusedDay;
                                            } else if (format ==
                                                CalendarFormat.week) {
                                              startDate = getStartOfWeek(
                                                  focusedDay); // always Monday
                                              endDate =
                                                  getEndOfWeek(focusedDay);
                                            } else if (format ==
                                                CalendarFormat.threeDays) {
                                              startDate = DateTime.now().add(
                                                  const Duration(days: -1));
                                              endDate = DateTime.now()
                                                  .add(const Duration(days: 1));
                                            }
                                            setState(() {
                                              currentCalendarFormat = format;
                                            });

                                            startDate = DateTime(picked.year,
                                                picked.month, picked.day);
                                            endDate = DateTime(picked.year,
                                                    picked.month, picked.day)
                                                .add(const Duration(days: 1));
                                            if (_calendarKey.currentState
                                                is VisualsCalendarState) {
                                              final calendarState =
                                                  _calendarKey.currentState
                                                      as VisualsCalendarState;
                                              _calendarKey.currentState
                                                  ?.jumpToDate(startDate);
                                              calendarState.widget.onPageChanged
                                                  ?.call(startDate, endDate);
                                            }
                                            setState(() {});
                                            _getCalendarEvents();
                                          }
                                        },
                                      ),
                                   ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            )
          : const NoInternetConnectionPage(),
    );
  }
}

Widget _calendarFormatSelector(
    CalendarFormat current,
    Function(CalendarFormat) onChanged,
    ) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SegmentedButton<CalendarFormat>(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.black,
        selectedBackgroundColor: Colors.blue.shade200,
        selectedForegroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8)
      ),
      segments: const [
        ButtonSegment(
          value: CalendarFormat.day,
          label: Text('Day'),
        ),
        ButtonSegment(
          value: CalendarFormat.threeDays,
          label: Text('3 Days'),
        ),
        ButtonSegment(
          value: CalendarFormat.week,
          label: Text('Week'),
        ),
      ],
      selected: {current},
      onSelectionChanged: (value) {
        onChanged(value.first);
      },
    ),
  );
}
