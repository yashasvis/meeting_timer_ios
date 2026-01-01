class CalendarEventsModel {
  String id;
  String createdDateTime;
  String lastModifiedDateTime;
  String changeKey;
  List<String> categories;
  String transactionId;
  String originalStartTimeZone;
  String originalEndTimeZone;
  String iCalUId;
  String uid;
  int reminderMinutesBeforeStart;
  bool isReminderOn;
  bool hasAttachments;
  String subject;
  String bodyPreview;
  String importance;
  String sensitivity;
  bool isAllDay;
  bool isCancelled;
  bool isOrganizer;
  bool responseRequested;
  Map<String, dynamic>? seriesMasterId;
  String showAs;
  String type;
  String webLink;
  Map<String, dynamic>? onlineMeetingUrl; // <-- nullable
  bool isOnlineMeeting;
  String onlineMeetingProvider;
  bool allowNewTimeProposals;
  Map<String, dynamic>? occurrenceId;
  bool isDraft;
  bool hideAttendees;
  Map<String, dynamic> responseStatus;
  Map<String, dynamic> body;
  Map<String, dynamic> start;
  Map<String, dynamic> end;
  Map<String, dynamic> location; // <-- single map
  List<Map<String, dynamic>>? locations;
  Map<String, dynamic>? recurrence; // <-- fixed type
  List<dynamic>? attendees;
  Map<String, dynamic>? organizer; // <-- single map
  Map<String, dynamic>? onlineMeeting; // <-- nullable

  CalendarEventsModel({
    required this.id,
    required this.createdDateTime,
    required this.lastModifiedDateTime,
    required this.changeKey,
    required this.categories,
    required this.transactionId,
    required this.originalStartTimeZone,
    required this.originalEndTimeZone,
    required this.iCalUId,
    required this.uid,
    required this.reminderMinutesBeforeStart,
    required this.isReminderOn,
    required this.hasAttachments,
    required this.subject,
    required this.bodyPreview,
    required this.importance,
    required this.sensitivity,
    required this.isAllDay,
    required this.isCancelled,
    required this.isOrganizer,
    required this.responseRequested,
    this.seriesMasterId,
    required this.showAs,
    required this.type,
    required this.webLink,
    this.onlineMeetingUrl,
    required this.isOnlineMeeting,
    required this.onlineMeetingProvider,
    required this.allowNewTimeProposals,
    this.occurrenceId,
    required this.isDraft,
    required this.hideAttendees,
    required this.responseStatus,
    required this.body,
    required this.start,
    required this.end,
    required this.location,
    this.locations,
    this.recurrence,
    this.attendees,
    this.organizer,
    this.onlineMeeting,
  });

  factory CalendarEventsModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventsModel(
      id: json['id'] ?? '',
      createdDateTime: json['createdDateTime'] ?? '',
      lastModifiedDateTime: json['lastModifiedDateTime'] ?? '',
      changeKey: json['changeKey'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      transactionId: json['transactionId'] ?? '',
      originalStartTimeZone: json['originalStartTimeZone'] ?? '',
      originalEndTimeZone: json['originalEndTimeZone'] ?? '',
      iCalUId: json['iCalUId'] ?? '',
      uid: json['uid'] ?? '',
      reminderMinutesBeforeStart: json['reminderMinutesBeforeStart'] ?? 0,
      isReminderOn: json['isReminderOn'] ?? false,
      hasAttachments: json['hasAttachments'] ?? false,
      subject: json['subject'] ?? '',
      bodyPreview: json['bodyPreview'] ?? '',
      importance: json['importance'] ?? '',
      sensitivity: json['sensitivity'] ?? '',
      isAllDay: json['isAllDay'] ?? false,
      isCancelled: json['isCancelled'] ?? false,
      isOrganizer: json['isOrganizer'] ?? false,
      responseRequested: json['responseRequested'] ?? false,
      seriesMasterId: json['seriesMasterId'],
      showAs: json['showAs'] ?? '',
      type: json['type'] ?? '',
      webLink: json['webLink'] ?? '',
      onlineMeetingUrl: json['onlineMeetingUrl'],
      isOnlineMeeting: json['isOnlineMeeting'] ?? false,
      onlineMeetingProvider: json['onlineMeetingProvider'] ?? '',
      allowNewTimeProposals: json['allowNewTimeProposals'] ?? false,
      occurrenceId: json['occurrenceId'],
      isDraft: json['isDraft'] ?? false,
      hideAttendees: json['hideAttendees'] ?? false,
      responseStatus: json['responseStatus'] ?? {},
      body: json['body'] ?? {},
      start: json['start'] ?? {},
      end: json['end'] ?? {},
      location: json['location'] ?? {},
      locations: json['locations'] != null ? List<Map<String, dynamic>>.from(json['locations']) : null,
      recurrence: json['recurrence'],
      attendees: json['attendees'],
      organizer: json['organizer'],
      onlineMeeting: json['onlineMeeting'],
    );
  }
}
