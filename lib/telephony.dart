import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:platform/platform.dart';

part 'constants.dart';

part 'filter.dart';

typedef MessageHandler(Message message);
typedef SmsSendStatusListener(SendStatus status);

void _flutterSmsSetupBackgroundChannel(
    {MethodChannel backgroundChannel =
        const MethodChannel(_BACKGROUND_CHANNEL)}) async {
  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel.setMethodCallHandler((call) async {
    if (call.method == HANDLE_BACKGROUND_MESSAGE) {
      final CallbackHandle handle =
          CallbackHandle.fromRawHandle(call.arguments['handle']);
      final Function handlerFunction =
          PluginUtilities.getCallbackFromHandle(handle)!;
      try {
        await handlerFunction(Message.fromMap(
            call.arguments['message'], INCOMING_SMS_COLUMNS));
      } catch (e) {
        print('Unable to handle incoming background message.');
        print(e);
      }
      return Future<void>.value();
    }
  });

  backgroundChannel.invokeMethod<void>(BACKGROUND_SERVICE_INITIALIZED);
}

///
/// A Flutter plugin to use telephony features such as
/// - Send SMS Messages
/// - Query SMS Messages
/// - Listen for incoming SMS
/// - Retrieve various network parameters
///
///
/// This plugin tries to replicate some of the functionality provided by Android's Telephony class.
///
///
class Telephony {
  final MethodChannel _foregroundChannel;
  final Platform _platform;

  late MessageHandler _onNewMessage;
  late MessageHandler _onBackgroundMessages;
  final Map<String, SmsSendStatusListener> _statusListeners = {};

  ///
  /// Gets a singleton instance of the [Telephony] class.
  ///
  static Telephony get instance => _instance;

  ///
  /// Gets a singleton instance of the [Telephony] class to be used in background execution context.
  ///
  static Telephony get backgroundInstance => _backgroundInstance;

  /// ## Do not call this method. This method is visible only for testing.
  @visibleForTesting
  Telephony.private(MethodChannel methodChannel, Platform platform)
      : _foregroundChannel = methodChannel,
        _platform = platform;

  Telephony._newInstance(MethodChannel methodChannel, LocalPlatform platform)
      : _foregroundChannel = methodChannel,
        _platform = platform {
    _foregroundChannel.setMethodCallHandler(handler);
  }

  static final Telephony _instance = Telephony._newInstance(
      const MethodChannel(_FOREGROUND_CHANNEL), const LocalPlatform());
  static final Telephony _backgroundInstance = Telephony._newInstance(
      const MethodChannel(_FOREGROUND_CHANNEL), const LocalPlatform());

  ///
  /// Listens to incoming SMS.
  ///
  /// ### Requires RECEIVE_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [onNewMessage] : Called on every new message received when app is in foreground.
  /// - [onBackgroundMessage] (optional) : Called on every new message received when app is in background.
  /// - [listenInBackground] (optional) : Defaults to true. Set to false to only listen to messages in foreground. [listenInBackground] is
  /// ignored if [onBackgroundMessage] is not set.
  ///
  ///
  void listenIncomingSms(
      {required MessageHandler onNewMessage,
      MessageHandler? onBackgroundMessage,
      bool listenInBackground = true}) {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    assert(
        listenInBackground
            ? onBackgroundMessage != null
            : onBackgroundMessage == null,
        listenInBackground
            ? "`onBackgroundMessage` cannot be null when `listenInBackground` is true. Set `listenInBackground` to false if you don't need background processing."
            : "You have set `listenInBackground` to false. `onBackgroundMessage` can only be set when `listenInBackground` is true");

    _onNewMessage = onNewMessage;

    if (listenInBackground && onBackgroundMessage != null) {
      _onBackgroundMessages = onBackgroundMessage;
      final CallbackHandle backgroundSetupHandle =
          PluginUtilities.getCallbackHandle(_flutterSmsSetupBackgroundChannel)!;
      final CallbackHandle? backgroundMessageHandle =
          PluginUtilities.getCallbackHandle(_onBackgroundMessages);

      if (backgroundMessageHandle == null) {
        throw ArgumentError(
          '''Failed to setup background message handler! `onBackgroundMessage`
          should be a TOP-LEVEL OR STATIC FUNCTION and should NOT be tied to a
          class or an anonymous function.''',
        );
      }

      _foregroundChannel.invokeMethod<bool>(
        'startBackgroundService',
        <String, dynamic>{
          'setupHandle': backgroundSetupHandle.toRawHandle(),
          'backgroundHandle': backgroundMessageHandle.toRawHandle()
        },
      );
    } else {
      _foregroundChannel.invokeMethod('disableBackgroundService');
    }
  }

  /// ## Do not call this method. This method is visible only for testing.
  @visibleForTesting
  Future<void> handler(MethodCall call) async {
    switch (call.method) {
      case ON_MESSAGE:
        final message = call.arguments["message"];
        return _onNewMessage(Message.fromMap(message, INCOMING_SMS_COLUMNS));
      case SMS_SENT:
      case MMS_SENT:
        try {
          _statusListeners.entries.firstWhere((e) => e.key == call.arguments["transactionId"]).value.call(SendStatus.SENT);
        } catch (_) {}
        break;
      case SMS_DELIVERED:
        try {
          _statusListeners.entries.firstWhere((e) => e.key == call.arguments["transactionId"]).value.call(SendStatus.DELIVERED);
        } catch (_) {}
        break;
    }
  }

  ///
  /// Query SMS Inbox.
  ///
  /// ### Requires READ_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [columns] (optional) : List of [MessageColumn] to be returned by this query. Defaults to [ SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE ]
  /// - [filter] (optional) : [SmsFilter] to filter the results of this query. Works like SQL WHERE clause.
  /// - [sortOrder] (optional): List of [OrderBy]. Orders the results of this query by the provided columns and order.
  ///
  /// Returns:
  ///
  /// [Future<List<SmsMessage>>]
  Future<List<Message>> getInboxSms(
      {List<MessageColumn> columns = DEFAULT_SMS_COLUMNS,
      SmsFilter? filter,
      List<OrderBy>? sortOrder}) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = _getArguments(columns, filter, sortOrder);

    final messages =
        await _foregroundChannel.invokeMethod<List?>(GET_ALL_INBOX_SMS, args);

    return messages
            ?.map((message) => Message.fromMap(message, columns))
            .toList(growable: false) ??
        List.empty();
  }

  ///
  /// Query SMS Outbox / Sent messages.
  ///
  /// ### Requires READ_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [columns] (optional) : List of [MessageColumn] to be returned by this query. Defaults to [ SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE ]
  /// - [filter] (optional) : [SmsFilter] to filter the results of this query. Works like SQL WHERE clause.
  /// - [sortOrder] (optional): List of [OrderBy]. Orders the results of this query by the provided columns and order.
  ///
  /// Returns:
  ///
  /// [Future<List<SmsMessage>>]
  Future<List<Message>> getSentSms(
      {List<MessageColumn> columns = DEFAULT_SMS_COLUMNS,
      SmsFilter? filter,
      List<OrderBy>? sortOrder}) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = _getArguments(columns, filter, sortOrder);

    final messages =
        await _foregroundChannel.invokeMethod<List?>(GET_ALL_SENT_SMS, args);

    return messages
            ?.map((message) => Message.fromMap(message, columns))
            .toList(growable: false) ??
        List.empty();
  }

  ///
  /// Query SMS Drafts.
  ///
  /// ### Requires READ_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [columns] (optional) : List of [MessageColumn] to be returned by this query. Defaults to [ SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE ]
  /// - [filter] (optional) : [SmsFilter] to filter the results of this query. Works like SQL WHERE clause.
  /// - [sortOrder] (optional): List of [OrderBy]. Orders the results of this query by the provided columns and order.
  ///
  /// Returns:
  ///
  /// [Future<List<SmsMessage>>]
  Future<List<Message>> getDraftSms(
      {List<MessageColumn> columns = DEFAULT_SMS_COLUMNS,
      SmsFilter? filter,
      List<OrderBy>? sortOrder}) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = _getArguments(columns, filter, sortOrder);

    final messages =
        await _foregroundChannel.invokeMethod<List?>(GET_ALL_DRAFT_SMS, args);

    return messages
            ?.map((message) => Message.fromMap(message, columns))
            .toList(growable: false) ??
        List.empty();
  }

  ///
  /// Query Conversation Threads..
  ///
  /// ### Requires READ_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [filter] (optional) : [ConversationFilter] to filter the results of this query. Works like SQL WHERE clause.
  /// - [sortOrder] (optional): List of [OrderBy]. Orders the results of this query by the provided columns and order.
  ///
  /// Returns:
  ///
  /// [Future<List<Conversation>>]
  Future<List<Conversation>> getConversations(
      {ConversationFilter? filter, List<OrderBy>? sortOrder}) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = _getArguments(DEFAULT_CONVERSATION_COLUMNS, filter, sortOrder);

    final conversations = await _foregroundChannel.invokeMethod<List?>(
        GET_ALL_CONVERSATIONS, args);

    return conversations
            ?.map((conversation) => Conversation.fromMap(conversation))
            .toList(growable: false) ??
        List.empty();
  }

  Future<List<String>> getAddressesForConversation(List<int> recipientIds) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = {
      "ids": recipientIds
    };

    return ((await _foregroundChannel.invokeMethod<List<dynamic>>(GET_RECIPIENT_ADDRESSES, args)) ?? []).map((e) => e.toString()).toList();
  }

  Future<List<Message>> getMessagesForConversation(int threadId) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = {
      "threadId": threadId
    };

    final messages = await _foregroundChannel.invokeMethod<List?>(GET_CONVERSATION_MESSAGES, args);

    return messages
        ?.map((message) => Message.fromMap(message, List.from(DEFAULT_SMS_COLUMNS)..addAll([MessageColumn.SUBJECT_2, MessageColumn.MESSAGE_BOX, MessageColumn.TYPE])))
        .toList(growable: false) ??
        List.empty();
  }

  Future<dynamic> getMmsData(int messageId) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    final args = {
      "messageId": messageId
    };

    final messages = await _foregroundChannel.invokeMethod<Map?>(GET_MMS_DATA, args);

    print(messages.toString());
  }

  Map<String, dynamic> _getArguments(List<_TelephonyColumn> columns,
      Filter? filter, List<OrderBy>? sortOrder) {
    final Map<String, dynamic> args = {};

    args["projection"] = columns.map((c) => c._name).toList();

    if (filter != null) {
      args["selection"] = filter.selection;
      args["selection_args"] = filter.selectionArgs;
    }

    if (sortOrder != null && sortOrder.isNotEmpty) {
      args["sort_order"] = sortOrder.map((o) => o._value).join(",");
    }

    return args;
  }

  ///
  /// Send an SMS directly from your application. Uses Android's SmsManager to send SMS.
  ///
  /// ### Requires SEND_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [to] : Address to send the SMS to.
  /// - [message] : Message to be sent. If message body is longer than standard SMS length limits set appropriate
  /// value for [isMultipart]
  /// - [statusListener] (optional) : Listen to the status of the sent SMS. Values can be one of [MessageStatus]
  /// - [isMultipart] (optional) : If message body is longer than standard SMS limit of 160 characters, set this flag to
  /// send the SMS in multiple parts.
  Future<void> sendSms({
    required String to,
    required String message,
    SmsSendStatusListener? statusListener,
    bool isMultipart = false,
  }) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    bool listenStatus = false;
    final transactionId = randomString(9);
    if (statusListener != null) {
      _statusListeners[transactionId] = statusListener;
      listenStatus = true;
    }
    final Map<String, dynamic> args = {
      "address": to,
      "message_body": message,
      "listen_status": listenStatus,
      "transaction_id": transactionId,
    };
    final String method = isMultipart ? SEND_MULTIPART_SMS : SEND_SMS;
    await _foregroundChannel.invokeMethod(method, args);
  }

  ///
  /// Open Android's default SMS application with the provided message and address.
  ///
  /// ### Requires SEND_SMS permission.
  ///
  /// Parameters:
  ///
  /// - [to] : Address to send the SMS to.
  /// - [message] : Message to be sent.
  ///
  Future<void> sendSmsByDefaultApp({
    required String to,
    required String message,
  }) async {
    final Map<String, dynamic> args = {
      "address": to,
      "message_body": message,
    };
    await _foregroundChannel.invokeMethod(SEND_SMS_INTENT, args);
  }

  Future<void> sendMms({
    required List<String> to,
    String? message,
    String? subject,
    required int threadId,
    List<MmsAttachment> attachments = const [],
    SmsSendStatusListener? statusListener,
  }) async {
    assert(_platform.isAndroid == true, "Can only be called on Android.");
    bool listenStatus = false;
    final transactionId = randomString(9);
    if (statusListener != null) {
      _statusListeners[transactionId] = statusListener;
      listenStatus = true;
    }
    final Map<String, dynamic> args = {
      "addresses": to,
      "message_body": message,
      "message_subject": subject,
      "threadId": threadId,
      "attachments": attachments.map((e) => e.toMap()).toList(),
      "listen_status": listenStatus,
      "transaction_id": transactionId,
    };
    await _foregroundChannel.invokeMethod(SEND_MMS, args);
  }

  ///
  /// Checks if the device has necessary features to send and receive SMS.
  ///
  /// Uses TelephonyManager class on Android.
  ///
  Future<bool?> get isSmsCapable =>
      _foregroundChannel.invokeMethod<bool>(IS_SMS_CAPABLE);

  ///
  /// Returns a constant indicating the current data connection state (cellular).
  ///
  /// Returns:
  ///
  /// [Future<DataState>]
  Future<DataState> get cellularDataState async {
    final int? dataState =
        await _foregroundChannel.invokeMethod<int>(GET_CELLULAR_DATA_STATE);
    if (dataState == null || dataState == -1) {
      return DataState.UNKNOWN;
    } else {
      return DataState.values[dataState];
    }
  }

  ///
  /// Returns a constant that represents the current state of all phone calls.
  ///
  /// Returns:
  ///
  /// [Future<CallState>]
  Future<CallState> get callState async {
    final int? state =
        await _foregroundChannel.invokeMethod<int>(GET_CALL_STATE);
    if (state != null) {
      return CallState.values[state];
    } else {
      return CallState.UNKNOWN;
    }
  }

  ///
  /// Returns a constant that represents the current state of all phone calls.
  ///
  /// Returns:
  ///
  /// [Future<CallState>]
  Future<DataActivity> get dataActivity async {
    final int? activity =
        await _foregroundChannel.invokeMethod<int>(GET_DATA_ACTIVITY);
    if (activity != null) {
      return DataActivity.values[activity];
    } else {
      return DataActivity.UNKNOWN;
    }
  }

  ///
  /// Returns the numeric name (MCC+MNC) of current registered operator.
  ///
  /// Availability: Only when user is registered to a network.
  ///
  /// Result may be unreliable on CDMA networks (use phoneType to determine if on a CDMA network).
  ///
  Future<String?> get networkOperator =>
      _foregroundChannel.invokeMethod<String>(GET_NETWORK_OPERATOR);

  ///
  /// Returns the alphabetic name of current registered operator.
  ///
  /// Availability: Only when user is registered to a network.
  ///
  /// Result may be unreliable on CDMA networks (use phoneType to determine if on a CDMA network).
  ///
  Future<String?> get networkOperatorName =>
      _foregroundChannel.invokeMethod<String>(GET_NETWORK_OPERATOR_NAME);

  ///
  /// Returns a constant indicating the radio technology (network type) currently in use on the device for data transmission.
  ///
  /// ### Requires READ_PHONE_STATE permission.
  ///
  Future<NetworkType> get dataNetworkType async {
    final int? type =
        await _foregroundChannel.invokeMethod<int>(GET_DATA_NETWORK_TYPE);
    if (type != null) {
      return NetworkType.values[type];
    } else {
      return NetworkType.UNKNOWN;
    }
  }

  ///
  /// Returns a constant indicating the device phone type. This indicates the type of radio used to transmit voice calls.
  ///
  Future<PhoneType> get phoneType async {
    final int? type =
        await _foregroundChannel.invokeMethod<int>(GET_PHONE_TYPE);
    if (type != null) {
      return PhoneType.values[type];
    } else {
      return PhoneType.UNKNOWN;
    }
  }

  ///
  /// Returns the MCC+MNC (mobile country code + mobile network code) of the provider of the SIM. 5 or 6 decimal digits.
  ///
  /// Availability: SimState must be SIM\_STATE\_READY
  Future<String?> get simOperator =>
      _foregroundChannel.invokeMethod<String>(GET_SIM_OPERATOR);

  ///
  /// Returns the Service Provider Name (SPN).
  ///
  /// Availability: SimState must be SIM_STATE_READY
  Future<String?> get simOperatorName =>
      _foregroundChannel.invokeMethod<String>(GET_SIM_OPERATOR_NAME);

  ///
  /// Returns a constant indicating the state of the default SIM card.
  ///
  /// Returns:
  ///
  /// [Future<SimState>]
  Future<SimState> get simState async {
    final int? state =
        await _foregroundChannel.invokeMethod<int>(GET_SIM_STATE);
    if (state != null) {
      return SimState.values[state];
    } else {
      return SimState.UNKNOWN;
    }
  }

  ///
  /// Returns true if the device is considered roaming on the current network, for GSM purposes.
  ///
  /// Availability: Only when user registered to a network.
  Future<bool?> get isNetworkRoaming =>
      _foregroundChannel.invokeMethod<bool>(IS_NETWORK_ROAMING);

  ///
  /// Returns a List of SignalStrength or an empty List if there are no valid measurements.
  ///
  /// ### Requires Android build version 29 --> Android Q
  ///
  /// Returns:
  ///
  /// [Future<List<SignalStrength>>]
  Future<List<SignalStrength>> get signalStrengths async {
    final List<dynamic>? strengths =
        await _foregroundChannel.invokeMethod(GET_SIGNAL_STRENGTH);
    return (strengths ?? [])
        .map((s) => SignalStrength.values[s])
        .toList(growable: false);
  }

  ///
  /// Returns current voice service state.
  ///
  /// ### Requires Android build version 26 --> Android O
  /// ### Requires permissions ACCESS_COARSE_LOCATION and READ_PHONE_STATE
  ///
  /// Returns:
  ///
  /// [Future<ServiceState>]
  Future<ServiceState> get serviceState async {
    final int? state =
        await _foregroundChannel.invokeMethod<int>(GET_SERVICE_STATE);
    if (state != null) {
      return ServiceState.values[state];
    } else {
      return ServiceState.UNKNOWN;
    }
  }

  ///
  /// Request the user for all the sms permissions listed in the app's AndroidManifest.xml
  ///
  Future<bool?> get requestSmsPermissions =>
      _foregroundChannel.invokeMethod<bool>(REQUEST_SMS_PERMISSION);

  ///
  /// Request the user for all the phone permissions listed in the app's AndroidManifest.xml
  ///
  Future<bool?> get requestPhonePermissions =>
      _foregroundChannel.invokeMethod<bool>(REQUEST_PHONE_PERMISSION);

  ///
  /// Request the user for all the phone and sms permissions listed in the app's AndroidManifest.xml
  ///
  Future<bool?> get requestPhoneAndSmsPermissions =>
      _foregroundChannel.invokeMethod<bool>(REQUEST_PHONE_AND_SMS_PERMISSION);

  ///
  /// Opens the default dialer with the given phone number.
  ///
  Future<void> openDialer(String phoneNumber) async {
    assert(phoneNumber.isNotEmpty, "phoneNumber cannot be empty");
    final Map<String, dynamic> args = {"phoneNumber": phoneNumber};
    await _foregroundChannel.invokeMethod(OPEN_DIALER, args);
  }

  ///
  /// Starts a phone all with the given phone number.
  ///
  /// ### Requires permission CALL_PHONE
  ///
  Future<void> dialPhoneNumber(String phoneNumber) async {
    assert(phoneNumber.isNotEmpty, "phoneNumber cannot be null or empty");
    final Map<String, dynamic> args = {"phoneNumber": phoneNumber};
    await _foregroundChannel.invokeMethod(DIAL_PHONE_NUMBER, args);
  }
}

///
/// Represents a message returned by one of the query functions such as
/// [getInboxSms], [getSentSms], [getDraftSms]
class Message {
  int? id;
  String? address;
  String? body;
  DateTime? date;
  DateTime? dateSent;
  int? errorCode;
  MessageMethod? method;
  bool? read;
  bool? seen;
  String? subject;
  int? subscriptionId;
  int? threadId;
  MessageType? type;
  MessageStatus? status;

  /// ## Do not call this method. This method is visible only for testing.
  @visibleForTesting
  Message.fromMap(Map rawMessage, List<MessageColumn> columns) {
    final message = Map.castFrom<dynamic, dynamic, String, dynamic>(rawMessage);
    for (var column in columns) {
      final value = message[column._columnName];
      switch (column._columnName) {
        case _MessageProjections.ID:
          this.id = int.tryParse(value ?? "");
          break;
        case _MessageProjections.ORIGINATING_ADDRESS:
        case _MessageProjections.ADDRESS:
          this.address = value;
          break;
        case _MessageProjections.MESSAGE_BODY:
        case _MessageProjections.BODY:
          this.body = value;
          break;
        case _MessageProjections.DATE:
        case _MessageProjections.TIMESTAMP:
          final ms = int.tryParse(value ?? "");
          this.date = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
          break;
        case _MessageProjections.DATE_SENT:
          final ms = int.tryParse(value ?? "");
          this.dateSent = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
          break;
        case _MessageProjections.ERROR_CODE:
          this.errorCode = int.tryParse(value ?? "");
          break;
        case _MessageProjections.MESSAGE_BOX:
          this.method = value != null ? MessageMethod.MMS : MessageMethod.SMS;
          break;
        case _MessageProjections.READ:
          this.read = int.tryParse(value ?? "") == 0 ? false : true;
          break;
        case _MessageProjections.SEEN:
          this.seen = int.tryParse(value ?? "") == 0 ? false : true;
          break;
        case _MessageProjections.STATUS:
          switch (int.tryParse(value ?? "")) {
            case 0:
              this.status = MessageStatus.STATUS_COMPLETE;
              break;
            case 32:
              this.status = MessageStatus.STATUS_PENDING;
              break;
            case 64:
              this.status = MessageStatus.STATUS_FAILED;
              break;
            case -1:
            default:
              this.status = MessageStatus.STATUS_NONE;
              break;
          }
          break;
        case _MessageProjections.SUBJECT:
        case _MessageProjections.SUBJECT_2:
          this.subject = value;
          break;
        case _MessageProjections.SUBSCRIPTION_ID:
          this.subscriptionId = int.tryParse(value ?? "");
          break;
        case _MessageProjections.THREAD_ID:
          this.threadId = int.tryParse(value ?? "");
          break;
        case _MessageProjections.TYPE:
          var smsTypeIndex = int.tryParse(value ?? "");
          this.type = smsTypeIndex != null ? MessageType.values[smsTypeIndex] : null;
          break;
      }
    }
  }

  /// ## Do not call this method. This method is visible only for testing.
  @visibleForTesting
  bool equals(Message other) {
    return this.id == other.id &&
        this.address == other.address &&
        this.body == other.body &&
        this.date == other.date &&
        this.dateSent == other.dateSent &&
        this.read == other.read &&
        this.seen == other.seen &&
        this.subject == other.subject &&
        this.subscriptionId == other.subscriptionId &&
        this.threadId == other.threadId &&
        this.type == other.type &&
        this.status == other.status;
  }
}

///
/// Represents a conversation returned by the query conversation functions
/// [getConversations]
class Conversation {
  int? threadId;
  DateTime? date;
  int? messageCount;
  List<int> recipientIds = [];
  String? snippet;
  int? snippetCs;
  bool? read;
  bool? archived;
  int? type;
  int? error;
  bool? hasAttachment;
  int? unreadCount;
  bool? alertExpired;
  bool? replyAll;
  String? groupSnippet;
  int? messageType;
  List<int> displayRecipientIds = [];
  int? translateMode;
  int? secretMode;
  int? safeMessage;
  int? classification;
  bool? isMute;
  int? chatType;
  String? paUuid;
  int? paThread;
  String? menustring;
  bool? pinToTop;
  int? usingMode;
  String? fromAddress;
  DateTime? messageDate;
  String? paOwnnumber;
  int? snippetType;
  int? binStatus;

  /// ## Do not call this method. This method is visible only for testing.
  @visibleForTesting
  Conversation.fromMap(Map rawConversation) {
    final conversation =
        Map.castFrom<dynamic, dynamic, String, dynamic>(rawConversation);
    for (var column in DEFAULT_CONVERSATION_COLUMNS) {
      final String? value = conversation[column._columnName];
      switch (column._columnName) {
        case _ConversationProjections.THREAD_ID:
          this.threadId = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.DATE:
          final ms = int.tryParse(value ?? "");
          this.date = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
          break;
        case _ConversationProjections.MESSAGE_COUNT:
          this.messageCount = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.RECIPIENT_IDS:
          this.recipientIds = (value ?? "").split(" ").map((e) => int.parse(e)).toList();
          break;
        case _ConversationProjections.SNIPPET:
          this.snippet = value;
          break;
        case _ConversationProjections.SNIPPET_CS:
          this.snippetCs = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.READ:
          final val = int.tryParse(value ?? "");
          this.read = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.ARCHIVED:
          final val = int.tryParse(value ?? "");
          this.archived = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.TYPE:
          this.type = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.ERROR:
          this.error = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.HAS_ATTACHMENT:
          final val = int.tryParse(value ?? "");
          this.hasAttachment = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.UNREAD_COUNT:
          this.unreadCount = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.ALERT_EXPIRED:
          final val = int.tryParse(value ?? "");
          this.alertExpired = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.REPLY_ALL:
          final val = int.tryParse(value ?? "");
          this.replyAll = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.GROUP_SNIPPET:
          this.groupSnippet = value;
          break;
        case _ConversationProjections.MESSAGE_TYPE:
          this.messageType = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.DISPLAY_RECIPIENT_IDS:
          this.displayRecipientIds = (value ?? "").split(" ").map((e) => int.parse(e)).toList();
          break;
        case _ConversationProjections.TRANSLATE_MODE:
          this.translateMode = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.SECRET_MODE:
          this.secretMode = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.SAFE_MESSAGE:
          this.safeMessage = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.CLASSIFICATION:
          this.classification = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.IS_MUTE:
          final val = int.tryParse(value ?? "");
          this.isMute = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.CHAT_TYPE:
          this.chatType = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.PA_UUID:
          this.paUuid = value;
          break;
        case _ConversationProjections.PA_THREAD:
          this.paThread = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.MENUSTRING:
          this.menustring = value;
          break;
        case _ConversationProjections.PIN_TO_TOP:
          final val = int.tryParse(value ?? "");
          this.pinToTop = val == 1 ? true : val == 0 ? false : null;
          break;
        case _ConversationProjections.USING_MODE:
          this.usingMode = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.FROM_ADDRESS:
          this.fromAddress = value;
          break;
        case _ConversationProjections.MESSAGE_DATE:
          final ms = int.tryParse(value ?? "");
          this.messageDate = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
          break;
        case _ConversationProjections.PA_OWNNUMBER:
          this.paOwnnumber = value;
          break;
        case _ConversationProjections.SNIPPET_TYPE:
          this.snippetType = int.tryParse(value ?? "");
          break;
        case _ConversationProjections.BIN_STATUS:
          this.binStatus = int.tryParse(value ?? "");
          break;
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          threadId == other.threadId &&
          date == other.date &&
          messageCount == other.messageCount &&
          recipientIds == other.recipientIds &&
          snippet == other.snippet &&
          snippetCs == other.snippetCs &&
          read == other.read &&
          archived == other.archived &&
          type == other.type &&
          error == other.error &&
          hasAttachment == other.hasAttachment &&
          unreadCount == other.unreadCount &&
          alertExpired == other.alertExpired &&
          replyAll == other.replyAll &&
          groupSnippet == other.groupSnippet &&
          messageType == other.messageType &&
          displayRecipientIds == other.displayRecipientIds &&
          translateMode == other.translateMode &&
          secretMode == other.secretMode &&
          safeMessage == other.safeMessage &&
          classification == other.classification &&
          isMute == other.isMute &&
          chatType == other.chatType &&
          paUuid == other.paUuid &&
          paThread == other.paThread &&
          menustring == other.menustring &&
          pinToTop == other.pinToTop &&
          usingMode == other.usingMode &&
          fromAddress == other.fromAddress &&
          messageDate == other.messageDate &&
          paOwnnumber == other.paOwnnumber &&
          snippetType == other.snippetType &&
          binStatus == other.binStatus;

  @override
  int get hashCode =>
      threadId.hashCode ^
      date.hashCode ^
      messageCount.hashCode ^
      recipientIds.hashCode ^
      snippet.hashCode ^
      snippetCs.hashCode ^
      read.hashCode ^
      archived.hashCode ^
      type.hashCode ^
      error.hashCode ^
      hasAttachment.hashCode ^
      unreadCount.hashCode ^
      alertExpired.hashCode ^
      replyAll.hashCode ^
      groupSnippet.hashCode ^
      messageType.hashCode ^
      displayRecipientIds.hashCode ^
      translateMode.hashCode ^
      secretMode.hashCode ^
      safeMessage.hashCode ^
      classification.hashCode ^
      isMute.hashCode ^
      chatType.hashCode ^
      paUuid.hashCode ^
      paThread.hashCode ^
      menustring.hashCode ^
      pinToTop.hashCode ^
      usingMode.hashCode ^
      fromAddress.hashCode ^
      messageDate.hashCode ^
      paOwnnumber.hashCode ^
      snippetType.hashCode ^
      binStatus.hashCode;
}

class MmsAttachment {
  final Uint8List data;
  final String mimeType;
  final String name;

  MmsAttachment({required this.data, required this.mimeType, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'data': this.data,
      'mimeType': this.mimeType,
      'name': this.name,
    };
  }
}

String randomString(int length) {
  var rand = Random();
  var codeUnits = List.generate(length, (index) {
    return rand.nextInt(33) + 89;
  });

  return String.fromCharCodes(codeUnits);
}