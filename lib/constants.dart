part of 'telephony.dart';

const _FOREGROUND_CHANNEL = 'plugins.shounakmulay.com/foreground_sms_channel';
const _BACKGROUND_CHANNEL = 'plugins.shounakmulay.com/background_sms_channel';

const HANDLE_BACKGROUND_MESSAGE = "handleBackgroundMessage";
const BACKGROUND_SERVICE_INITIALIZED = "backgroundServiceInitialized";
const GET_ALL_INBOX_SMS = "getAllInboxSms";
const GET_ALL_SENT_SMS = "getAllSentSms";
const GET_ALL_DRAFT_SMS = "getAllDraftSms";
const GET_ALL_CONVERSATIONS = "getAllConversations";
const GET_RECIPIENT_ADDRESSES = "getRecipientAddresses";
const GET_CONVERSATION_MESSAGES = "getConversationMessages";
const GET_MMS_DATA = "getMmsData";
const SEND_SMS = "sendSms";
const SEND_MULTIPART_SMS = "sendMultipartSms";
const SEND_MMS = "sendMms";
const SEND_SMS_INTENT = "sendSmsIntent";
const IS_SMS_CAPABLE = "isSmsCapable";
const GET_CELLULAR_DATA_STATE = "getCellularDataState";
const GET_CALL_STATE = "getCallState";
const GET_DATA_ACTIVITY = "getDataActivity";
const GET_NETWORK_OPERATOR = "getNetworkOperator";
const GET_NETWORK_OPERATOR_NAME = "getNetworkOperatorName";
const GET_DATA_NETWORK_TYPE = "getDataNetworkType";
const GET_PHONE_TYPE = "getPhoneType";
const GET_SIM_OPERATOR = "getSimOperator";
const GET_SIM_OPERATOR_NAME = "getSimOperatorName";
const GET_SIM_STATE = "getSimState";
const IS_NETWORK_ROAMING = "isNetworkRoaming";
const GET_SIGNAL_STRENGTH = "getSignalStrength";
const GET_SERVICE_STATE = "getServiceState";
const REQUEST_SMS_PERMISSION = "requestSmsPermissions";
const REQUEST_PHONE_PERMISSION = "requestPhonePermissions";
const REQUEST_PHONE_AND_SMS_PERMISSION = "requestPhoneAndSmsPermissions";
const OPEN_DIALER = "openDialer";
const DIAL_PHONE_NUMBER = "dialPhoneNumber";

const ON_MESSAGE = "onMessage";
const SMS_SENT = "smsSent";
const SMS_DELIVERED = "smsDelivered";
const MMS_SENT = "mmsSent";

///
/// Possible parameters that can be fetched during a SMS query operation.
class _MessageProjections {
//  static const String COUNT = "_count";
  static const String ID = "_id";
  static const String ORIGINATING_ADDRESS = "originating_address";
  static const String ADDRESS = "address";
  static const String MESSAGE_BODY = "message_body";
  static const String BODY = "body";

//  static const String CREATOR = "creator";
  static const String TIMESTAMP = "timestamp";
  static const String DATE = "date";
  static const String DATE_SENT = "date_sent";

  static const String ERROR_CODE = "error_code";
  static const String MESSAGE_BOX = "msg_box";
//  static const String LOCKED = "locked";
//  static const int MESSAGE_TYPE_ALL = 0;
//  static const int MESSAGE_TYPE_DRAFT = 3;
//  static const int MESSAGE_TYPE_FAILED = 5;
//  static const int MESSAGE_TYPE_INBOX = 1;
//  static const int MESSAGE_TYPE_OUTBOX = 4;
//  static const int MESSAGE_TYPE_QUEUED = 6;
//  static const int MESSAGE_TYPE_SENT = 2;
//  static const String PERSON = "person";
//  static const String PROTOCOL = "protocol";
  static const String READ = "read";

//  static const String REPLY_PATH_PRESENT = "reply_path_present";
  static const String SEEN = "seen";

//  static const String SERVICE_CENTER = "service_center";
  static const String STATUS = "status";

//  static const int STATUS_COMPLETE = 0;
//  static const int STATUS_FAILED = 64;
//  static const int STATUS_NONE = -1;
//  static const int STATUS_PENDING = 32;
  static const String SUBJECT = "subject";
  static const String SUBJECT_2 = "sub";
  static const String SUBSCRIPTION_ID = "sub_id";
  static const String THREAD_ID = "thread_id";
  static const String TYPE = "type";
}

///
/// Possible parameters that can be fetched during a Conversation query operation.
class _ConversationProjections {
  static const String THREAD_ID = "_id";
  static const String DATE = "date";
  static const String MESSAGE_COUNT = "message_count";
  static const String RECIPIENT_IDS = "recipient_ids";
  static const String SNIPPET = "snippet";
  static const String SNIPPET_CS = "snippet_cs";
  static const String READ = "read";
  static const String ARCHIVED = "archived";
  static const String TYPE = "type";
  static const String ERROR = "error";
  static const String HAS_ATTACHMENT = "has_attachment";
  static const String UNREAD_COUNT = "unread_count";
  static const String ALERT_EXPIRED = "alert_expired";
  static const String REPLY_ALL = "reply_all";
  static const String GROUP_SNIPPET = "group_snippet";
  static const String MESSAGE_TYPE = "message_type";
  static const String DISPLAY_RECIPIENT_IDS = "display_recipient_ids";
  static const String TRANSLATE_MODE = "translate_mode";
  static const String SECRET_MODE = "secret_mode";
  static const String SAFE_MESSAGE = "safe_message";
  static const String CLASSIFICATION = "classification";
  static const String IS_MUTE = "is_mute";
  static const String CHAT_TYPE = "chat_type";
  static const String PA_UUID = "pa_uuid";
  static const String PA_THREAD = "pa_thread";
  static const String MENUSTRING = "menustring";
  static const String PIN_TO_TOP = "pin_to_top";
  static const String USING_MODE = "using_mode";
  static const String FROM_ADDRESS = "from_address";
  static const String MESSAGE_DATE = "message_date";
  static const String PA_OWNNUMBER = "pa_ownnumber";
  static const String SNIPPET_TYPE = "snippet_type";
  static const String BIN_STATUS = "bin_status";
}

abstract class _TelephonyColumn {
  const _TelephonyColumn();

  String get _name;
}

/// Represents all the possible parameters for a SMS
class MessageColumn extends _TelephonyColumn {
  final String _columnName;

  const MessageColumn._(this._columnName);

  static const ID = MessageColumn._(_MessageProjections.ID);
  static const ADDRESS = MessageColumn._(_MessageProjections.ADDRESS);
  static const BODY = MessageColumn._(_MessageProjections.BODY);
  static const DATE = MessageColumn._(_MessageProjections.DATE);
  static const DATE_SENT = MessageColumn._(_MessageProjections.DATE_SENT);
  static const ERROR_CODE = MessageColumn._(_MessageProjections.ERROR_CODE);
  static const MESSAGE_BOX = MessageColumn._(_MessageProjections.MESSAGE_BOX);
  static const READ = MessageColumn._(_MessageProjections.READ);
  static const SEEN = MessageColumn._(_MessageProjections.SEEN);
  static const STATUS = MessageColumn._(_MessageProjections.STATUS);
  static const SUBJECT = MessageColumn._(_MessageProjections.SUBJECT);
  static const SUBJECT_2 = MessageColumn._(_MessageProjections.SUBJECT_2);
  static const SUBSCRIPTION_ID = MessageColumn._(_MessageProjections.SUBSCRIPTION_ID);
  static const THREAD_ID = MessageColumn._(_MessageProjections.THREAD_ID);
  static const TYPE = MessageColumn._(_MessageProjections.TYPE);

  @override
  String get _name => _columnName;
}

/// Represents all the possible parameters for a Conversation
class ConversationColumn extends _TelephonyColumn {
  final String _columnName;

  const ConversationColumn._(this._columnName);

  static const THREAD_ID =
      ConversationColumn._(_ConversationProjections.THREAD_ID);
  static const DATE = ConversationColumn._(_ConversationProjections.DATE);
  static const MESSAGE_COUNT = ConversationColumn._(_ConversationProjections.MESSAGE_COUNT);
  static const RECIPIENT_IDS = ConversationColumn._(_ConversationProjections.RECIPIENT_IDS);
  static const SNIPPET = ConversationColumn._(_ConversationProjections.SNIPPET);
  static const SNIPPET_CS = ConversationColumn._(_ConversationProjections.SNIPPET_CS);
  static const READ = ConversationColumn._(_ConversationProjections.READ);
  static const ARCHIVED = ConversationColumn._(_ConversationProjections.ARCHIVED);
  static const TYPE = ConversationColumn._(_ConversationProjections.TYPE);
  static const ERROR = ConversationColumn._(_ConversationProjections.ERROR);
  static const HAS_ATTACHMENT = ConversationColumn._(_ConversationProjections.HAS_ATTACHMENT);
  static const UNREAD_COUNT = ConversationColumn._(_ConversationProjections.UNREAD_COUNT);
  static const ALERT_EXPIRED = ConversationColumn._(_ConversationProjections.ALERT_EXPIRED);
  static const REPLY_ALL = ConversationColumn._(_ConversationProjections.REPLY_ALL);
  static const GROUP_SNIPPET = ConversationColumn._(_ConversationProjections.GROUP_SNIPPET);
  static const MESSAGE_TYPE = ConversationColumn._(_ConversationProjections.MESSAGE_TYPE);
  static const DISPLAY_RECIPIENT_IDS = ConversationColumn._(_ConversationProjections.DISPLAY_RECIPIENT_IDS);
  static const TRANSLATE_MODE = ConversationColumn._(_ConversationProjections.TRANSLATE_MODE);
  static const SECRET_MODE = ConversationColumn._(_ConversationProjections.SECRET_MODE);
  static const SAFE_MESSAGE = ConversationColumn._(_ConversationProjections.SAFE_MESSAGE);
  static const CLASSIFICATION = ConversationColumn._(_ConversationProjections.CLASSIFICATION);
  static const IS_MUTE = ConversationColumn._(_ConversationProjections.IS_MUTE);
  static const CHAT_TYPE = ConversationColumn._(_ConversationProjections.CHAT_TYPE);
  static const PA_UUID = ConversationColumn._(_ConversationProjections.PA_UUID);
  static const PA_THREAD = ConversationColumn._(_ConversationProjections.PA_THREAD);
  static const MENUSTRING = ConversationColumn._(_ConversationProjections.MENUSTRING);
  static const PIN_TO_TOP = ConversationColumn._(_ConversationProjections.PIN_TO_TOP);
  static const USING_MODE = ConversationColumn._(_ConversationProjections.USING_MODE);
  static const FROM_ADDRESS = ConversationColumn._(_ConversationProjections.FROM_ADDRESS);
  static const MESSAGE_DATE = ConversationColumn._(_ConversationProjections.MESSAGE_DATE);
  static const PA_OWNNUMBER = ConversationColumn._(_ConversationProjections.PA_OWNNUMBER);
  static const SNIPPET_TYPE = ConversationColumn._(_ConversationProjections.SNIPPET_TYPE);
  static const BIN_STATUS = ConversationColumn._(_ConversationProjections.BIN_STATUS);

  @override
  String get _name => _columnName;
}

const DEFAULT_SMS_COLUMNS = [
  MessageColumn.ID,
  MessageColumn.ADDRESS,
  MessageColumn.BODY,
  MessageColumn.DATE,
  MessageColumn.STATUS,
  MessageColumn.ERROR_CODE,
];

const INCOMING_SMS_COLUMNS = [
  MessageColumn._(_MessageProjections.ORIGINATING_ADDRESS),
  MessageColumn._(_MessageProjections.MESSAGE_BODY),
  MessageColumn._(_MessageProjections.TIMESTAMP),
  MessageColumn.STATUS
];

const DEFAULT_CONVERSATION_COLUMNS = [
  ConversationColumn.THREAD_ID,
  ConversationColumn.DATE,
  ConversationColumn.MESSAGE_COUNT,
  ConversationColumn.RECIPIENT_IDS,
  ConversationColumn.SNIPPET,
  ConversationColumn.READ,
  ConversationColumn.ARCHIVED,
  ConversationColumn.HAS_ATTACHMENT,
  ConversationColumn.UNREAD_COUNT,
  ConversationColumn.IS_MUTE,
];

/// Represents types of SMS.
enum MessageType {
  MESSAGE_TYPE_ALL,
  MESSAGE_TYPE_INBOX,
  MESSAGE_TYPE_SENT,
  MESSAGE_TYPE_DRAFT,
  MESSAGE_TYPE_OUTBOX,
  MESSAGE_TYPE_FAILED,
  MESSAGE_TYPE_QUEUED
}

/// Represents states of SMS.
enum MessageStatus { STATUS_COMPLETE, STATUS_FAILED, STATUS_NONE, STATUS_PENDING }

enum MessageMethod { SMS, MMS }

/// Represents data connection state.
enum DataState { DISCONNECTED, CONNECTING, CONNECTED, SUSPENDED, UNKNOWN }

/// Represents state of cellular calls.
enum CallState { IDLE, RINGING, OFFHOOK, UNKNOWN }

/// Represents state of cellular network data activity.
enum DataActivity { NONE, IN, OUT, INOUT, DORMANT, UNKNOWN }

/// Represents types of networks for a device.
enum NetworkType {
  UNKNOWN,
  GPRS,
  EDGE,
  UMTS,
  CDMA,
  EVDO_0,
  EVDO_A,
  TYPE_1xRTT,
  HSDPA,
  HSUPA,
  HSPA,
  IDEN,
  EVDO_B,
  LTE,
  EHRPD,
  HSPAP,
  GSM,
  TD_SCDMA,
  IWLAN,
  LTE_CA,
  NR,
}

/// Represents types of cellular technology supported by a device.
enum PhoneType { NONE, GSM, CDMA, SIP, UNKNOWN }

/// Represents state of SIM.
enum SimState {
  UNKNOWN,
  ABSENT,
  PIN_REQUIRED,
  PUK_REQUIRED,
  NETWORK_LOCKED,
  READY,
  NOT_READY,
  PERM_DISABLED,
  CARD_IO_ERROR,
  CARD_RESTRICTED,
  LOADED,
  PRESENT
}

/// Represents state of cellular service.
enum ServiceState {
  IN_SERVICE,
  OUT_OF_SERVICE,
  EMERGENCY_ONLY,
  POWER_OFF,
  UNKNOWN
}

/// Represents the quality of cellular signal.
enum SignalStrength { NONE_OR_UNKNOWN, POOR, MODERATE, GOOD, GREAT }

/// Represents sort order for [OrderBy].
enum Sort { ASC, DESC }

extension Value on Sort {
  String get value {
    switch (this) {
      case Sort.ASC:
        return "ASC";
      case Sort.DESC:
      default:
        return "DESC";
    }
  }
}

/// Represents the status of a sms message sent from the device.
enum SendStatus { SENT, DELIVERED }
