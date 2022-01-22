package com.shounakmulay.telephony.sms

import android.annotation.SuppressLint
import android.app.Activity
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import androidx.annotation.RequiresApi
import com.shounakmulay.telephony.PermissionsController
import com.shounakmulay.telephony.utils.ActionType
import com.shounakmulay.telephony.utils.Constants
import com.shounakmulay.telephony.utils.Constants.ADDRESS
import com.shounakmulay.telephony.utils.Constants.ADDRESSES
import com.shounakmulay.telephony.utils.Constants.ATTACHMENTS
import com.shounakmulay.telephony.utils.Constants.BACKGROUND_HANDLE
import com.shounakmulay.telephony.utils.Constants.CALL_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.DEFAULT_CONVERSATION_MESSAGES_PROJECTION
import com.shounakmulay.telephony.utils.Constants.DEFAULT_CONVERSATION_PROJECTION
import com.shounakmulay.telephony.utils.Constants.DEFAULT_MMS_DATA_PROJECTION
import com.shounakmulay.telephony.utils.Constants.DEFAULT_SMS_PROJECTION
import com.shounakmulay.telephony.utils.Constants.FAILED_FETCH
import com.shounakmulay.telephony.utils.Constants.GET_STATUS_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.IDS
import com.shounakmulay.telephony.utils.Constants.ILLEGAL_ARGUMENT
import com.shounakmulay.telephony.utils.Constants.LISTEN_STATUS
import com.shounakmulay.telephony.utils.Constants.MESSAGE_BODY
import com.shounakmulay.telephony.utils.Constants.MESSAGE_ID
import com.shounakmulay.telephony.utils.Constants.MMS_SENT
import com.shounakmulay.telephony.utils.Constants.PERMISSION_DENIED
import com.shounakmulay.telephony.utils.Constants.PERMISSION_DENIED_MESSAGE
import com.shounakmulay.telephony.utils.Constants.PERMISSION_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.PHONE_NUMBER
import com.shounakmulay.telephony.utils.Constants.PROJECTION
import com.shounakmulay.telephony.utils.Constants.RECIPIENT_ADDRESS_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.SELECTION
import com.shounakmulay.telephony.utils.Constants.SELECTION_ARGS
import com.shounakmulay.telephony.utils.Constants.SETUP_HANDLE
import com.shounakmulay.telephony.utils.Constants.SHARED_PREFERENCES_NAME
import com.shounakmulay.telephony.utils.Constants.SHARED_PREFS_DISABLE_BACKGROUND_EXE
import com.shounakmulay.telephony.utils.Constants.SMS_BACKGROUND_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.SMS_DELIVERED
import com.shounakmulay.telephony.utils.Constants.SMS_QUERY_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.SMS_SEND_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.SMS_SENT
import com.shounakmulay.telephony.utils.Constants.SORT_ORDER
import com.shounakmulay.telephony.utils.Constants.SUBJECT
import com.shounakmulay.telephony.utils.Constants.THREAD_ID
import com.shounakmulay.telephony.utils.Constants.TRANSACTION_ID
import com.shounakmulay.telephony.utils.Constants.WRONG_METHOD_TYPE
import com.shounakmulay.telephony.utils.ContentUri
import com.shounakmulay.telephony.utils.SmsAction
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException


class SmsMethodCallHandler(
    private val context: Context,
    private val smsController: SmsController,
    private val permissionsController: PermissionsController
) : PluginRegistry.RequestPermissionsResultListener,
    MethodChannel.MethodCallHandler,
    BroadcastReceiver() {

  private lateinit var result: MethodChannel.Result
  private lateinit var action: SmsAction
  private lateinit var foregroundChannel: MethodChannel
  private lateinit var activity: Activity

  private var projection: List<String>? = null
  private var selection: String? = null
  private var selectionArgs: List<String>? = null
  private var sortOrder: String? = null
  private var ids: List<Int>? = null
  private var threadId: Int? = null
  private var messageId: Int? = null

  private var messageBody: String? = null
  private var messageSubject: String? = null
  private var address: String? = null
  private var listenStatus: Boolean = false
  private var addresses: Array<String>? = null
  private var attachments: List<HashMap<String, Any>>? = null
  private var transactionId: String? = null

  private var setupHandle: Long = -1
  private var backgroundHandle: Long = -1

  private lateinit var phoneNumber: String

  private var requestCode: Int = -1

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    this.result = result

    action = SmsAction.fromMethod(call.method)

    if (action == SmsAction.NO_SUCH_METHOD) {
      result.notImplemented()
      return
    }

    when (action.toActionType()) {
      ActionType.GET_SMS -> {
        projection = call.argument(PROJECTION)
        selection = call.argument(SELECTION)
        selectionArgs = call.argument(SELECTION_ARGS)
        sortOrder = call.argument(SORT_ORDER)
        threadId = null
        ids = null
        messageId = null

        handleMethod(action, SMS_QUERY_REQUEST_CODE)
      }
      ActionType.GET_RECIPIENTS -> {
        projection = null
        selection = null
        selectionArgs = null
        sortOrder = null
        ids = call.argument(IDS)
        threadId = null
        messageId = null

        handleMethod(action, RECIPIENT_ADDRESS_REQUEST_CODE)
      }
      ActionType.GET_CONVERSATION_MESSAGES -> {
        projection = null
        selection = null
        selectionArgs = null
        sortOrder = null
        ids = null
        threadId = call.argument(THREAD_ID)
        messageId = null

        handleMethod(action, SMS_QUERY_REQUEST_CODE)
      }
      ActionType.GET_MMS_DATA -> {
        projection = null
        selection = null
        selectionArgs = null
        sortOrder = null
        ids = null
        threadId = null
        messageId = call.argument(MESSAGE_ID)

        handleMethod(action, SMS_QUERY_REQUEST_CODE)
      }
      ActionType.SEND_SMS -> {
        if (call.hasArgument(MESSAGE_BODY)
            && call.hasArgument(ADDRESS)) {
          val messageBody = call.argument<String>(MESSAGE_BODY)
          val address = call.argument<String>(ADDRESS)
          if (messageBody.isNullOrBlank() || address.isNullOrBlank()) {
            result.error(ILLEGAL_ARGUMENT, Constants.MESSAGE_OR_ADDRESS_CANNOT_BE_NULL, null)
            return
          }

          this.messageBody = messageBody
          this.address = address
          this.transactionId = call.argument<String>(TRANSACTION_ID)

          listenStatus = call.argument(LISTEN_STATUS) ?: false
        }
        handleMethod(action, SMS_SEND_REQUEST_CODE)
      }
      ActionType.SEND_MMS -> {
        val messageBody = call.argument<String>(MESSAGE_BODY)
        val addresses = call.argument<List<String>>(ADDRESSES)
        val attachments = call.argument<List<HashMap<String, Any>>>(ATTACHMENTS)
        val threadId = call.argument<Int>(THREAD_ID)
        val subject = call.argument<String>(SUBJECT)
        if (addresses.isNullOrEmpty()) {
          result.error(ILLEGAL_ARGUMENT, Constants.MESSAGE_OR_ADDRESS_CANNOT_BE_NULL, null)
          return
        }

        this.messageBody = messageBody
        this.addresses = addresses.toTypedArray()
        this.attachments = attachments
        this.threadId = threadId
        this.messageSubject = subject
        this.transactionId = call.argument<String>(TRANSACTION_ID)

        listenStatus = call.argument(LISTEN_STATUS) ?: false
        handleMethod(action, SMS_SEND_REQUEST_CODE)
      }
      ActionType.BACKGROUND -> {
        if (call.hasArgument(SETUP_HANDLE)
            && call.hasArgument(BACKGROUND_HANDLE)) {
          val setupHandle = call.argument<Long>(SETUP_HANDLE)
          val backgroundHandle = call.argument<Long>(BACKGROUND_HANDLE)
          if (setupHandle == null || backgroundHandle == null) {
            result.error(ILLEGAL_ARGUMENT, "Setup handle or background handle missing", null)
            return
          }

          this.setupHandle = setupHandle
          this.backgroundHandle = backgroundHandle
        }
        handleMethod(action, SMS_BACKGROUND_REQUEST_CODE)
      }
      ActionType.GET -> handleMethod(action, GET_STATUS_REQUEST_CODE)
      ActionType.PERMISSION -> handleMethod(action, PERMISSION_REQUEST_CODE)
      ActionType.CALL -> {
        if (call.hasArgument(PHONE_NUMBER)) {
          val phoneNumber = call.argument<String>(PHONE_NUMBER)

          if (!phoneNumber.isNullOrBlank()) {
            this.phoneNumber = phoneNumber
          }

          handleMethod(action, CALL_REQUEST_CODE)
        }
      }
    }
  }

  /**
   * Called by [handleMethod] after checking the permissions.
   *
   * #####
   *
   * If permission was not previously granted, [handleMethod] will request the user for permission
   *
   * Once user grants the permission this method will be executed.
   *
   * #####
   */
  private fun execute(smsAction: SmsAction) {
    try {
      when (smsAction.toActionType()) {
        ActionType.GET_SMS -> handleGetSmsActions(smsAction)
        ActionType.GET_RECIPIENTS -> handleGetRecipientsAction()
        ActionType.GET_CONVERSATION_MESSAGES -> handleGetSmsActions(smsAction)
        ActionType.GET_MMS_DATA -> handleGetMmsDataAction()
        ActionType.SEND_SMS -> handleSendSmsActions(smsAction)
        ActionType.SEND_MMS -> handleSendMmsAction()
        ActionType.BACKGROUND -> handleBackgroundActions(smsAction)
        ActionType.GET -> handleGetActions(smsAction)
        ActionType.PERMISSION -> result.success(true)
        ActionType.CALL -> handleCallActions(smsAction)
      }
    } catch (e: IllegalArgumentException) {
      result.error(ILLEGAL_ARGUMENT, WRONG_METHOD_TYPE, null)
    } catch (e: RuntimeException) {
      result.error(FAILED_FETCH, e.message, null)
    }
  }

  private fun handleGetSmsActions(smsAction: SmsAction) {
    if (projection == null) {
      projection = when (smsAction) {
          SmsAction.GET_CONVERSATIONS -> DEFAULT_CONVERSATION_PROJECTION
          SmsAction.GET_CONVERSATION_MESSAGES -> DEFAULT_CONVERSATION_MESSAGES_PROJECTION
          else -> DEFAULT_SMS_PROJECTION
      }
    }
    val contentUri = when (smsAction) {
      SmsAction.GET_INBOX -> ContentUri.INBOX.uri
      SmsAction.GET_SENT -> ContentUri.SENT.uri
      SmsAction.GET_DRAFT -> ContentUri.DRAFT.uri
      SmsAction.GET_CONVERSATIONS -> ContentUri.CONVERSATIONS.uri
      SmsAction.GET_CONVERSATION_MESSAGES -> ContentUris.withAppendedId(Telephony.Threads.CONTENT_URI, threadId!!.toLong())
      else -> throw IllegalArgumentException()
    }
    val messages = smsController.getMessages(contentUri, projection!!, selection, selectionArgs, sortOrder)
    result.success(messages)
  }

  private fun handleGetRecipientsAction() {
    // Getting the target URI
    val addressUri = Uri.parse("content://mms-sms/canonical-address")

    result.success(ids!!.mapNotNull { recipientID ->
      //Querying for the recipient data
      try {
        context.contentResolver.query(
                ContentUris.withAppendedId(addressUri, recipientID.toLong()),
                arrayOf(Telephony.CanonicalAddressesColumns.ADDRESS),
                null, null, null).use { cursor ->
          //Ignoring invalid or empty results
          if(cursor == null || !cursor.moveToNext()) {
            return@mapNotNull null
          }

          //Adding the address to the array
          return@mapNotNull cursor.getString(cursor.getColumnIndexOrThrow(Telephony.CanonicalAddressesColumns.ADDRESS))
        }
      } catch(exception: RuntimeException) {
        exception.printStackTrace()
        return@mapNotNull null
      }
    })
  }

  private fun handleGetMmsDataAction() {
    var sender: String? = null
    context.contentResolver.query(
            Telephony.Mms.CONTENT_URI.buildUpon().appendPath(messageId.toString()).appendPath("addr").build(), arrayOf(Telephony.Mms.Addr.ADDRESS),
            "type=137 AND msg_id=$messageId", null, null, null).use { cursor ->
      if(cursor == null || !cursor.moveToFirst()) return
      var rawVal: String
      if (cursor.moveToFirst()) {
        do {
          rawVal = cursor.getString(cursor.getColumnIndexOrThrow("address"))
          if (rawVal != null) {
            sender = rawVal
            // Use the first one found if more than one
            break
          }
        } while (cursor.moveToNext())
      }
      cursor.close()
    }
    val messageTextSB = StringBuilder()
    val messageAttachments = ArrayList<HashMap<String, Any?>>()
    context.contentResolver.query(ContentUri.MMS_DATA.uri, DEFAULT_MMS_DATA_PROJECTION, Telephony.Mms.Part.MSG_ID + " = ?", arrayOf(messageId.toString()), null).use { cursorMMSData ->
      if(cursorMMSData == null || !cursorMMSData.moveToFirst()) return
      do {
        //Reading the part data
        val partID = cursorMMSData.getLong(cursorMMSData.getColumnIndexOrThrow(Telephony.Mms.Part._ID))
        val contentType = cursorMMSData.getString(cursorMMSData.getColumnIndexOrThrow(Telephony.Mms.Part.CONTENT_TYPE))
        var fileName = cursorMMSData.getString(cursorMMSData.getColumnIndexOrThrow(Telephony.Mms.Part.NAME))
        fileName = fileName?.replace('\u0000', '?')?.replace('/', '-') ?: "unnamed_attachment"

        // Checking if the part is text
        if ("text/plain" == contentType) {
          //Reading the text
          val data = cursorMMSData.getString(cursorMMSData.getColumnIndexOrThrow(Telephony.Mms.Part._DATA))
          val body: String? = if (data != null) {
            try {
              context.contentResolver.openInputStream(ContentUris.withAppendedId(ContentUri.MMS_DATA.uri, partID)).use { inputStream ->
                //Throwing an exception if the stream couldn't be opened
                if(inputStream == null) throw IOException("Failed to open stream")
                inputStream.bufferedReader().readLines().joinToString("\n")
              }
            } catch(exception: IOException) {
              exception.printStackTrace()
              null
            }
          } else {
            cursorMMSData.getString(cursorMMSData.getColumnIndexOrThrow(Telephony.Mms.Part.TEXT))
          }

          //Appending the text
          if (body != null) messageTextSB.append(body)
        } else if("application/smil" != contentType) {
          val attachmentData = HashMap<String, Any?>()
          try {
            context.contentResolver.openInputStream(ContentUris.withAppendedId(ContentUri.MMS_DATA.uri, partID)).use { inputStream ->
              //Throwing an exception if the stream couldn't be opened
              if(inputStream == null) throw IOException("Failed to open stream")
              attachmentData["name"] = fileName
              attachmentData["data"] = inputStream.readBytes()
              attachmentData["mimeType"] = contentType
              messageAttachments.add(attachmentData)
            }
          } catch(exception: IOException) {
            exception.printStackTrace()
            continue
          }
        }
      } while(cursorMMSData.moveToNext())
    }
    val finalData = HashMap<String, Any?>()
    finalData["sender"] = sender
    finalData["text"] = messageTextSB.toString()
    finalData["attachments"] = messageAttachments
    result.success(finalData)
  }

  private fun handleSendSmsActions(smsAction: SmsAction) {
    if (listenStatus) {
      val intentFilter = IntentFilter().apply {
        addAction(Constants.ACTION_SMS_SENT)
        addAction(Constants.ACTION_SMS_DELIVERED)
      }
      context.applicationContext.registerReceiver(this, intentFilter)
    }
    when (smsAction) {
      SmsAction.SEND_SMS -> smsController.sendSms(address!!, messageBody!!, listenStatus, transactionId!!)
      SmsAction.SEND_MULTIPART_SMS -> smsController.sendMultipartSms(address!!, messageBody!!, listenStatus, transactionId!!)
      SmsAction.SEND_SMS_INTENT -> smsController.sendSmsIntent(address!!, messageBody!!)
      else -> throw IllegalArgumentException()
    }
    result.success(null)
  }

  private fun handleSendMmsAction() {
    if (listenStatus) {
      val intentFilter = IntentFilter().apply {
        addAction(Constants.ACTION_MMS_SENT)
      }
      context.applicationContext.registerReceiver(this, intentFilter)
    }
    smsController.sendMms(addresses!!, threadId!!.toLong(), messageBody, messageSubject, attachments!!, listenStatus, transactionId!!)
    result.success(null)
  }

  private fun handleBackgroundActions(smsAction: SmsAction) {
    when (smsAction) {
      SmsAction.START_BACKGROUND_SERVICE -> {
        val preferences = context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE)
        preferences.edit().putBoolean(SHARED_PREFS_DISABLE_BACKGROUND_EXE, false).apply()
        IncomingSmsHandler.setBackgroundSetupHandle(context, setupHandle)
        IncomingSmsHandler.setBackgroundMessageHandle(context, backgroundHandle)
      }
      SmsAction.BACKGROUND_SERVICE_INITIALIZED -> {
        IncomingSmsHandler.onChannelInitialized()
      }
      SmsAction.DISABLE_BACKGROUND_SERVICE -> {
        val preferences = context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE)
        preferences.edit().putBoolean(SHARED_PREFS_DISABLE_BACKGROUND_EXE, true).apply()
      }
      else -> throw IllegalArgumentException()
    }
  }

  @SuppressLint("MissingPermission")
  private fun handleGetActions(smsAction: SmsAction) {
    smsController.apply {
      val value: Any = when (smsAction) {
        SmsAction.IS_SMS_CAPABLE -> isSmsCapable()
        SmsAction.GET_CELLULAR_DATA_STATE -> getCellularDataState()
        SmsAction.GET_CALL_STATE -> getCallState()
        SmsAction.GET_DATA_ACTIVITY -> getDataActivity()
        SmsAction.GET_NETWORK_OPERATOR -> getNetworkOperator()
        SmsAction.GET_NETWORK_OPERATOR_NAME -> getNetworkOperatorName()
        SmsAction.GET_DATA_NETWORK_TYPE -> getDataNetworkType()
        SmsAction.GET_PHONE_TYPE -> getPhoneType()
        SmsAction.GET_SIM_OPERATOR -> getSimOperator()
        SmsAction.GET_SIM_OPERATOR_NAME -> getSimOperatorName()
        SmsAction.GET_SIM_STATE -> getSimState()
        SmsAction.IS_NETWORK_ROAMING -> isNetworkRoaming()
        SmsAction.GET_SIGNAL_STRENGTH -> {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSignalStrength()
                ?: result.error("SERVICE_STATE_NULL", "Error getting service state", null)

          } else {
            result.error("INCORRECT_SDK_VERSION", "getServiceState() can only be called on Android Q and above", null)
          }
        }
        SmsAction.GET_SERVICE_STATE -> {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getServiceState()
                ?: result.error("SERVICE_STATE_NULL", "Error getting service state", null)
          } else {
            result.error("INCORRECT_SDK_VERSION", "getServiceState() can only be called on Android O and above", null)
          }
        }
        else -> throw IllegalArgumentException()
      }
      result.success(value)
    }
  }

  @SuppressLint("MissingPermission")
  private fun handleCallActions(smsAction: SmsAction) {
    when (smsAction) {
      SmsAction.OPEN_DIALER -> smsController.openDialer(phoneNumber)
      SmsAction.DIAL_PHONE_NUMBER -> smsController.dialPhoneNumber(phoneNumber)
      else -> throw IllegalArgumentException()
    }
  }


  /**
   * Calls the [execute] method after checking if the necessary permissions are granted.
   *
   * If not granted then it will request the permission from the user.
   */
  private fun handleMethod(smsAction: SmsAction, requestCode: Int) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || checkOrRequestPermission(smsAction, requestCode)) {
      execute(smsAction)
    }
  }

  /**
   * Check and request if necessary for all the SMS permissions listed in the manifest
   */
  @RequiresApi(Build.VERSION_CODES.M)
  fun checkOrRequestPermission(smsAction: SmsAction, requestCode: Int): Boolean {
    this.action = smsAction
    this.requestCode = requestCode
    when (smsAction) {
      SmsAction.GET_INBOX,
      SmsAction.GET_SENT,
      SmsAction.GET_DRAFT,
      SmsAction.GET_CONVERSATIONS,
      SmsAction.GET_RECIPIENT_ADDRESSES,
      SmsAction.GET_CONVERSATION_MESSAGES,
      SmsAction.GET_MMS_DATA,
      SmsAction.SEND_SMS,
      SmsAction.SEND_MULTIPART_SMS,
      SmsAction.SEND_SMS_INTENT,
      SmsAction.SEND_MMS,
      SmsAction.START_BACKGROUND_SERVICE,
      SmsAction.BACKGROUND_SERVICE_INITIALIZED,
      SmsAction.DISABLE_BACKGROUND_SERVICE,
      SmsAction.REQUEST_SMS_PERMISSIONS -> {
        val permissions = permissionsController.getSmsPermissions()
        return checkOrRequestPermission(permissions, requestCode)
      }
      SmsAction.GET_DATA_NETWORK_TYPE,
      SmsAction.OPEN_DIALER,
      SmsAction.DIAL_PHONE_NUMBER,
      SmsAction.REQUEST_PHONE_PERMISSIONS -> {
        val permissions = permissionsController.getPhonePermissions()
        return checkOrRequestPermission(permissions, requestCode)
      }
      SmsAction.GET_SERVICE_STATE -> {
        val permissions = permissionsController.getServiceStatePermissions()
        return checkOrRequestPermission(permissions, requestCode)
      }
      SmsAction.REQUEST_PHONE_AND_SMS_PERMISSIONS -> {
        val permissions = listOf(permissionsController.getSmsPermissions(), permissionsController.getPhonePermissions()).flatten()
        return checkOrRequestPermission(permissions, requestCode)
      }
      SmsAction.IS_SMS_CAPABLE,
      SmsAction.GET_CELLULAR_DATA_STATE,
      SmsAction.GET_CALL_STATE,
      SmsAction.GET_DATA_ACTIVITY,
      SmsAction.GET_NETWORK_OPERATOR,
      SmsAction.GET_NETWORK_OPERATOR_NAME,
      SmsAction.GET_PHONE_TYPE,
      SmsAction.GET_SIM_OPERATOR,
      SmsAction.GET_SIM_OPERATOR_NAME,
      SmsAction.GET_SIM_STATE,
      SmsAction.IS_NETWORK_ROAMING,
      SmsAction.GET_SIGNAL_STRENGTH,
      SmsAction.NO_SUCH_METHOD -> return true
      else -> return false
    }
  }

  fun setActivity(activity: Activity) {
    this.activity = activity
  }

  @RequiresApi(Build.VERSION_CODES.M)
  private fun checkOrRequestPermission(permissions: List<String>, requestCode: Int): Boolean {
    permissionsController.apply {
      
      if (!::activity.isInitialized) {
        return hasRequiredPermissions(permissions)
      }
      
      if (!hasRequiredPermissions(permissions)) {
        requestPermissions(activity, permissions, requestCode)
        return false
      }
      return true
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {

    permissionsController.isRequestingPermission = false

    val deniedPermissions = mutableListOf<String>()
    if (requestCode != this.requestCode && !this::action.isInitialized) {
      return false
    }

    val allPermissionGranted = grantResults?.foldIndexed(true) { i, acc, result ->
      if (result == PackageManager.PERMISSION_DENIED) {
        permissions?.let { deniedPermissions.add(it[i]) }
      }
      return@foldIndexed acc && result == PackageManager.PERMISSION_GRANTED
    } ?: false

    return if (allPermissionGranted) {
      execute(action)
      true
    } else {
      onPermissionDenied(deniedPermissions)
      false
    }
  }

  private fun onPermissionDenied(deniedPermissions: List<String>) {
    result.error(PERMISSION_DENIED, PERMISSION_DENIED_MESSAGE, deniedPermissions)
  }

  fun setForegroundChannel(channel: MethodChannel) {
    foregroundChannel = channel
  }

  override fun onReceive(ctx: Context?, intent: Intent?) {
    if (intent != null) {
      val args = HashMap<String, String?>()
      args["transactionId"] = intent.getStringExtra("transactionId")
      when (intent.action) {
        Constants.ACTION_SMS_SENT -> foregroundChannel.invokeMethod(SMS_SENT, args)
        Constants.ACTION_SMS_DELIVERED -> {
          foregroundChannel.invokeMethod(SMS_DELIVERED, args)
          context.unregisterReceiver(this)
        }
        Constants.ACTION_MMS_SENT -> {
          foregroundChannel.invokeMethod(MMS_SENT, args)
          context.unregisterReceiver(this)
        }
      }
    }
  }
}
