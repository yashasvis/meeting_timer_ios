import 'dart:async';
import 'dart:io';

import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:ios_calendar_demo/main.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'no_internet_connection_page.dart';
import 'calendar_page.dart';
import 'login_page.dart';

class CountdownWidget extends StatefulWidget {
  final dynamic countdownNotifier;
  final dynamic navigatorKey;

  const CountdownWidget(this.countdownNotifier,this.navigatorKey, {super.key});

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
  String endDate ="";
  String lastEventStartedDate = "";
  String lastEventEndDate = "";
  bool isMeetingStarted = false;
  bool isMeetingRunningOver = false;

  void storeMeetingDetails() async{
    SharedPreferences preferences = await SharedPreferences.getInstance();

    String loggedDate = preferences.getString('LoggedDate') ?? '';
    if(loggedDate != ""){
      DateTime dateTime = DateTime.parse(DateFormat('yyyy-MM-dd').format(DateTime.now()));
      if(dateTime.isAfter(DateTime.parse(loggedDate))){
        preferences.remove('LoggedDate');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginPage(widget.navigatorKey)),
        );
      }
    }

    preferences.setBool('isTimerShown', true);
    if(preferences.containsKey('currentMeetingTitle')){
      isMeetingStarted = preferences.getBool('currentHasScheduleWorkStarted') ?? false;
      if(isMeetingStarted == false){
        isMeetingStarted = preferences.getBool('HasScheduleWorkStarted') ?? false;
      }
      meetingTitle = preferences.getString('currentMeetingTitle') ?? '';
      subject = preferences.getString('currentSubject') ?? '';
      content = preferences.getString('currentContent') ?? '';
      meetingUrl = preferences.getString('currentMeetingUrl') ?? '';
      startDate = preferences.getString('currentStartDate') ?? '';
      endDate = preferences.getString('currentEndDate') ?? '';
    }
    else{
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

    setState(() {

    });
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
      if(DateTime.now().isAfter(DateTime.parse(endDate))){
        bool hasNextMeetingAdded = preferences.getBool('HasNextMeetingAdded') ?? false;
        if (hasNextMeetingAdded) {
          var endDt = preferences.getString('eventStartDate') ?? '';
          if(DateTime.now().isAfter(DateTime.parse(endDt)))
          {
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

            preferences.setBool('currentHasScheduleWorkStarted', isMeetingStarted);
            preferences.setString('currentMeetingTitle', meetingTitle);
            preferences.setString('currentSubject', subject);
            preferences.setString('currentContent', content);
            preferences.setString('currentMeetingUrl', meetingUrl);
            preferences.setString('currentStartDate', startDate);
            preferences.setString('currentEndDate', endDate);

            preferences.setBool('isMeetingRunningOver', false);
            preferences.remove('HasNextMeetingAdded');
          }
          else{
            var currentEndDate = preferences.containsKey('currentEndDate') ? true : false;
            if(currentEndDate){
              isMeetingRunningOver = true;
              lastEventStartedDate = preferences.getString('lastEventStartedDate') ?? '';
              lastEventEndDate = preferences.getString('lastEventEndDate') ?? '';
              preferences.setBool('isMeetingRunningOver', true);
              refresh();
            }

          }
        }
        else
        {
          var currentEndDate = preferences.containsKey('currentEndDate') ? true : false;
          if(currentEndDate) {
            lastEventStartedDate = preferences.getString('lastEventStartedDate') ?? '';
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

  void refresh(){
    setState(() {

    });
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
    Size screenSize = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop,result){
        if (didPop) return;
        if (Platform.isAndroid) {
          final service = FlutterBackgroundService();
          service.invoke("stopService");
          exit(0);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: _connectionStatus != ConnectivityResult.none ? Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              isMeetingStarted == false ? Padding(
                  padding: EdgeInsets.only(
                      bottom:screenSize.height * 0.004
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Text(
                          isMeetingRunningOver ? "Meeting Running Over" : isMeetingStarted ? "In Meeting" : "Reminder",
                          style: TextStyle(
                            color: isMeetingRunningOver ? Colors.red : isMeetingStarted ? Colors.blue : Colors.orange,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  )
              ) : const Padding(padding: EdgeInsets.zero),
              Padding(
                padding: EdgeInsets.only(
                    bottom: isMeetingRunningOver ? 0.00 : screenSize.width * 0.008
                ),
                child: Text(
                  subject,
                  style:const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              isMeetingStarted && !isMeetingRunningOver ? Padding(
                padding: EdgeInsets.only(
                    left: screenSize.width * 0.02,
                    right: screenSize.width * 0.02
                ),
                child: Text(
                  "Your schedule meeting has started which will end at ${DateFormat('hh:mm a').format(DateTime.parse(endDate).toLocal())}.",
                  style:const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ) : const Text(""),
              isMeetingRunningOver ? Padding(
                padding: EdgeInsets.only(
                    top: screenSize.height * 0.001
                ),
                child: Text(
                  "Meeting time: ${DateFormat('hh:mm a')
                      .format(DateTime.parse(startDate).toLocal())} to ${DateFormat('hh:mm a')
                      .format(DateTime.parse(endDate).toLocal())}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ) : const Padding(padding: EdgeInsets.zero),
              isMeetingRunningOver ? Padding(
                padding: EdgeInsets.only(
                    top:screenSize.height * 0.007,
                    left: screenSize.width * 0.02,
                    right: screenSize.width * 0.02
                ),
                child: const Text(
                  "Scheduled meeting is running over.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ) : const Text(""),
              isMeetingStarted == false ? ValueListenableBuilder<Duration?>(
                valueListenable: widget.countdownNotifier,
                builder: (context, duration, _) {
                  duration ??= const Duration(minutes: 4,seconds: 45);
                  if (duration.isNegative) {
                    return Text("Your schedule meeting has started which will end at ${DateFormat('hh:mm a').format(DateTime.parse(endDate).toLocal())}.!");
                  }

                  return CircularCountDownTimer(
                    duration: duration.inSeconds, // total seconds until event
                    initialDuration: 0,
                    controller: _controller,
                    width: 200,
                    height: 200,
                    ringColor: Colors.orange,
                    fillColor: Colors.orange,
                    backgroundColor: Colors.orange,
                    strokeWidth: 15,
                    strokeCap: StrokeCap.round,
                    textStyle: const TextStyle(
                      fontSize: 40.0,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    textFormat: CountdownTextFormat.MM_SS, // show minutes:seconds
                    isReverse: true,
                    isReverseAnimation: true,
                    isTimerTextShown: true,
                    autoStart: true,
                    onComplete: () async{
                      DateTime eventEndAt = DateTime.parse(endDate).toLocal();
                      widget.countdownNotifier.value = eventEndAt.difference(DateTime.now());
                      setState(() {
                        isMeetingStarted = true;
                      });
                      SharedPreferences preferences = await SharedPreferences.getInstance();
                      preferences.remove('alreadyRedirected');
                      preferences.setBool('HasScheduleWorkStarted', true);
                      preferences.setBool('currentHasScheduleWorkStarted', true);
                      preferences.setString('lastEventStartedDate', eventStartDate.toString());
                      preferences.setString('lastEventEndDate', eventEndAt.toString());
                      setState(() {

                      });
                    },
                  );
                },
              ) :
              const Padding(
                padding: EdgeInsets.zero,
              ),
              isMeetingStarted ?
              SizedBox(
                width: screenSize.width,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        color : isMeetingRunningOver ? Colors.red : isMeetingStarted ? Colors.blue : Colors.orange,
                        size: 300,
                      ),
                      SizedBox(
                          width: screenSize.width * 0.50,
                          child:Text(
                            isMeetingRunningOver ? "Meeting Running Over" : isMeetingStarted ? "In Meeting" : "Reminder",
                            style: TextStyle(
                                fontSize: screenSize.height > 1050 ? 20 : screenSize.height > 900 ? 30 : 21,
                                color: Colors.white,
                                overflow: TextOverflow.clip,
                                fontWeight: FontWeight.bold
                            ),
                            textAlign: TextAlign.center,
                          )
                      )
                    ],
                  ),
                ),
              )
                  : const Padding(padding: EdgeInsets.zero),
              if(meetingUrl != "" && isMeetingStarted == false)
                Container(
                  margin: EdgeInsets.only(
                    top: screenSize.height * 0.045,
                  ),
                  width: screenSize.width * 0.58,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade500,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TextButton(
                    onPressed: () async{
                      await launchUrl(
                        Uri.parse(meetingUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_camera_front_outlined, size: 25,color: Colors.black),
                        Padding(
                          padding: EdgeInsets.only(
                              left: screenSize.width * 0.02,
                              right: screenSize.width * 0.02
                          ),
                          child:const Text(
                            "Join Teams Meeting ",
                            style: TextStyle(
                                fontSize: 17,
                                color: Colors.black
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              if(isMeetingStarted)
                Container(
                  width: screenSize.width * 0.50,
                  margin: EdgeInsets.only(
                    top: screenSize.height * 0.025,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TextButton(
                    onPressed: () async{
                      setState(() {
                        isMeetingRunningOver = false;
                        isMeetingStarted= false;
                      });
                      SharedPreferences preference = await SharedPreferences.getInstance();
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
                      preference.remove('alreadyRedirected');

                      widget.navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => CalendarPage("", widget.navigatorKey),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_filled_sharp,color: Colors.white,),
                        Padding(
                          padding: EdgeInsets.only(
                              left: screenSize.width * 0.02
                          ),
                          child: const Text(
                            "Meeting Over",
                            style: TextStyle(
                                fontSize: 17,
                                color: Colors.white
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ) : const NoInternetConnectionPage(),
    );
  }
}