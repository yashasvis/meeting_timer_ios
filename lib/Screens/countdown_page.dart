import 'dart:async';
import 'dart:io';

import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'no_internet_connection_page.dart';
import 'calendar_page.dart';
import 'login_page.dart';

class CountdownWidget extends StatefulWidget {
  final dynamic countdownNotifier;
  final dynamic navigatorKey;

  const CountdownWidget(this.countdownNotifier, this.navigatorKey, {super.key});

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  late GlobalKey<NavigatorState> navigatorKey;

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late Timer _timer;
  bool isLoading = true;

  final CountDownController _controller = CountDownController();
  String meetingTitle = "";
  String subject = "";
  String content = "";
  String meetingUrl = "";
  String startDate = "";
  String endDate = "";
  String lastEventStartedDate = "";
  String lastEventEndDate = "";
  bool isMeetingStarted = false;
  bool isMeetingRunningOver = false;

  void storeMeetingDetails() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();

    String loggedDate = preferences.getString('LoggedDate') ?? '';
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

    preferences.setBool('isTimerShown', true);
    if (preferences.containsKey('currentMeetingTitle')) {
      isMeetingStarted =
          preferences.getBool('currentHasScheduleWorkStarted') ?? false;
      if (isMeetingStarted == false) {
        isMeetingStarted =
            preferences.getBool('HasScheduleWorkStarted') ?? false;
      }
      meetingTitle = preferences.getString('currentMeetingTitle') ?? '';
      subject = preferences.getString('currentSubject') ?? '';
      content = preferences.getString('currentContent') ?? '';
      meetingUrl = preferences.getString('currentMeetingUrl') ?? '';
      startDate = preferences.getString('currentStartDate') ?? '';
      endDate = preferences.getString('currentEndDate') ?? '';
    } else {
      isMeetingStarted = preferences.getBool('HasScheduleWorkStarted') ?? false;
      meetingTitle = preferences.getString('meetingTitle') ?? '';
      subject = preferences.getString('subject') ?? '';
      content = preferences.getString('content') ?? '';
      meetingUrl = preferences.getString('meetingUrl') ?? '';
      startDate = preferences.getString('eventStartDate') ?? '';
      endDate = preferences.getString('eventEndDate') ?? '';

      preferences.setBool('currentHasScheduleWorkStarted', isMeetingStarted);
      preferences.setString('currentMeetingTitle', meetingTitle);
      preferences.setString('currentSubject', subject);
      preferences.setString('currentContent', content);
      preferences.setString('currentMeetingUrl', meetingUrl);
      preferences.setString('currentStartDate', startDate);
      preferences.setString('currentEndDate', endDate);
    }

    setState(() {});
  }

  @override
  void initState() {
    if (Platform.isAndroid) {
      KeepScreenOn.turnOn();
    }
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    storeMeetingDetails();
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (widget.countdownNotifier.value != null) {
        widget.countdownNotifier.value =
            widget.countdownNotifier.value! - const Duration(seconds: 1);
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      preferences.reload();
      if (DateTime.now().isAfter(DateTime.parse(endDate))) {
        bool hasNextMeetingAdded =
            preferences.getBool('HasNextMeetingAdded') ?? false;
        if (hasNextMeetingAdded) {
          var endDt = preferences.getString('eventStartDate') ?? '';
          if (DateTime.now().isAfter(DateTime.parse(endDt))) {
            isMeetingRunningOver = false;
            meetingTitle = preferences.getString('meetingTitle') ?? '';
            subject = preferences.getString('subject') ?? '';
            content = preferences.getString('content') ?? '';
            meetingUrl = preferences.getString('meetingUrl') ?? '';
            startDate = preferences.getString('eventStartDate') ?? '';
            endDate = preferences.getString('eventEndDate') ?? '';
            lastEventStartedDate = startDate;
            lastEventEndDate = endDt;

            refresh();

            preferences.setBool(
                'currentHasScheduleWorkStarted', isMeetingStarted);
            preferences.setString('currentMeetingTitle', meetingTitle);
            preferences.setString('currentSubject', subject);
            preferences.setString('currentContent', content);
            preferences.setString('currentMeetingUrl', meetingUrl);
            preferences.setString('currentStartDate', startDate);
            preferences.setString('currentEndDate', endDate);

            preferences.setBool('isMeetingRunningOver', false);
            preferences.remove('HasNextMeetingAdded');
          } else {
            var currentEndDate =
                preferences.containsKey('currentEndDate') ? true : false;
            if (currentEndDate) {
              isMeetingRunningOver = true;
              lastEventStartedDate =
                  preferences.getString('lastEventStartedDate') ?? '';
              lastEventEndDate =
                  preferences.getString('lastEventEndDate') ?? '';
              preferences.setBool('isMeetingRunningOver', true);
              refresh();
            }
          }
        } else {
          var currentEndDate =
              preferences.containsKey('currentEndDate') ? true : false;
          if (currentEndDate) {
            lastEventStartedDate =
                preferences.getString('lastEventStartedDate') ?? '';
            lastEventEndDate = preferences.getString('lastEventEndDate') ?? '';
            isMeetingRunningOver = true;
            preferences.setBool('isMeetingRunningOver', true);
            refresh();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    if (Platform.isAndroid) {
      KeepScreenOn.turnOff();
    }
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void refresh() {
    setState(() {});
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
              backgroundColor: Colors.white,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: constraints.maxWidth * 0.85,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              /// ---------------- TITLE ----------------
                              if (!isMeetingStarted)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    isMeetingRunningOver
                                        ? "Meeting Running Over"
                                        : "Reminder",
                                    style: TextStyle(
                                      color: isMeetingRunningOver
                                          ? Colors.red
                                          : Colors.orange,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              /// ---------------- SUBJECT ----------------
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  subject,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              /// ---------------- INFO TEXT ----------------
                              if (isMeetingStarted && !isMeetingRunningOver)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    "Your scheduled meeting has started and will end at "
                                    "${DateFormat('hh:mm a').format(DateTime.parse(endDate).toLocal())}.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),

                              if (isMeetingRunningOver)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    "Meeting time: "
                                    "${DateFormat('hh:mm a').format(DateTime.parse(startDate).toLocal())} "
                                    "to ${DateFormat('hh:mm a').format(DateTime.parse(endDate).toLocal())}",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 20),

                              /// ---------------- COUNTDOWN ----------------
                              if (!isMeetingStarted && widget.countdownNotifier != null)
                                ValueListenableBuilder<Duration?>(
                                  valueListenable: widget.countdownNotifier,
                                  builder: (context, duration, _) {
                                    duration ??=
                                        const Duration(minutes: 4, seconds: 45);

                                    if (duration.inSeconds <= 0 &&
                                        !isMeetingStarted) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) async {
                                        if (!mounted) return;
                                        setState(() => isMeetingStarted = true);
                                      });
                                    }

                                    return duration.inSeconds >= 0 ?CircularCountDownTimer(
                                      duration: duration.inSeconds,
                                      controller: _controller,
                                      width: 210,
                                      height: 210,
                                      ringColor: Colors.orange,
                                      fillColor: Colors.orange,
                                      backgroundColor: Colors.orange,
                                      strokeWidth: 20,
                                      strokeCap: StrokeCap.round,
                                      textStyle: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textFormat: CountdownTextFormat.MM_SS,
                                      isReverse: true,
                                      autoStart: true,
                                    ) : const Padding(padding: EdgeInsets.zero);
                                  },
                                ),

                              /// ---------------- MEETING STATE ----------------
                              if (isMeetingStarted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 300,
                                        color: isMeetingRunningOver
                                            ? Colors.red
                                            : Colors.blue,
                                      ),
                                      Text(
                                        isMeetingRunningOver
                                            ? "Meeting Running Over"
                                            : "In Meeting",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: isMeetingRunningOver ? 18 : 26,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              /// ---------------- JOIN BUTTON ----------------
                              if (meetingUrl.isNotEmpty && !isMeetingStarted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 30),
                                  child: SizedBox(
                                    width: 260,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      icon:
                                          const Icon(Icons.video_camera_front),
                                      label: const Text("Join Teams Meeting"),
                                      onPressed: () async {
                                        await launchUrl(
                                          Uri.parse(meetingUrl),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                              /// ---------------- MEETING OVER ----------------
                              if (isMeetingStarted)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: SizedBox(
                                    width: 260,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        iconColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      icon: const Icon(Icons.access_time),
                                      label: const Text("Meeting Over",style: TextStyle(color: Colors.white),),
                                      onPressed: () async {
                                        setState(() {
                                          isMeetingStarted = false;
                                          isMeetingRunningOver = false;
                                        });
                                        SharedPreferences preference = await SharedPreferences.getInstance();
                                        var currentEndDate = preference.getString('currentEndDate');
                                        preference.reload();
                                        preference.remove('HasScheduleWorkStarted');

                                        preference.remove('currentHasScheduleWorkStarted');
                                        preference.remove('currentMeetingTitle');
                                        preference.remove('currentSubject');
                                        preference.remove('currentContent');
                                        preference.remove('currentMeetingUrl');
                                        preference.remove('currentStartDate');
                                        preference.remove('currentEndDate');

                                        preference.remove('lastEventStartedDate');
                                        preference.remove('lastEventEndDate');
                                        preference.remove('isTimerShown');
                                        preference.remove('HasNextMeetingAdded');
                                        preference.remove('isMeetingRunningOver');

                                        preference.setBool('isTimerShown', false);
                                        preference.setBool('hasNextMeetingAdded', false);
                                        preference.setBool('isMeetingRunningOver', false);
                                        preference.setBool('currentHasScheduleWorkStarted', false);
                                        preference.setBool('HasScheduleWorkStarted', false);
                                        preference.remove('alreadyRedirected');
                                        if(currentEndDate != null)
                                          preference.setString('meetingOverTime', currentEndDate!);

                                        widget.navigatorKey.currentState?.push(
                                          MaterialPageRoute(
                                            builder: (_) => CalendarPage("", widget.navigatorKey),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : const NoInternetConnectionPage(),
    );
  }
}