package com.shounakmulay.telephony.sms

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.*
import androidx.annotation.RequiresApi
import androidx.annotation.RequiresPermission
import com.klinker.android.send_message.BroadcastUtils
import com.klinker.android.send_message.Message
import com.klinker.android.send_message.Settings
import com.klinker.android.send_message.Transaction
import com.shounakmulay.telephony.utils.Constants
import com.shounakmulay.telephony.utils.Constants.ACTION_SMS_DELIVERED
import com.shounakmulay.telephony.utils.Constants.ACTION_SMS_SENT
import com.shounakmulay.telephony.utils.Constants.SMS_BODY
import com.shounakmulay.telephony.utils.Constants.SMS_DELIVERED_BROADCAST_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.SMS_SENT_BROADCAST_REQUEST_CODE
import com.shounakmulay.telephony.utils.Constants.SMS_TO
import java.util.*
import kotlin.collections.ArrayList


class SmsController(private val context: Context) {

  // FETCH SMS
  fun getMessages(
      contentUri: Uri,
      projection: List<String>,
      selection: String?,
      selectionArgs: List<String>?,
      sortOrder: String?
  ): List<HashMap<String, String?>> {
    val messages = mutableListOf<HashMap<String, String?>>()

    val cursor = context.contentResolver.query(
        contentUri,
        projection.toTypedArray(),
        selection,
        selectionArgs?.toTypedArray(),
        sortOrder
    )

    while (cursor != null && cursor.moveToNext()) {
      val dataObject = HashMap<String, String?>(projection.size)
      for (columnName in cursor.columnNames) {
        val value = cursor.getString(cursor.getColumnIndexOrThrow(columnName))
        dataObject[columnName] = value
      }
      messages.add(dataObject)
    }

    cursor?.close()

    return messages

  }

  // SEND SMS
  fun sendSms(destinationAddress: String, messageBody: String, listenStatus: Boolean, transactionId: String) {
    val smsManager = getSmsManager()
    if (listenStatus) {
      val pendingIntents = getPendingIntents(transactionId)
      smsManager.sendTextMessage(destinationAddress, null, messageBody, pendingIntents.first, pendingIntents.second)
    } else {
      smsManager.sendTextMessage(destinationAddress, null, messageBody, null, null)
    }
  }

  fun sendMultipartSms(destinationAddress: String, messageBody: String, listenStatus: Boolean, transactionId: String) {
    val smsManager = getSmsManager()
    val messageParts = smsManager.divideMessage(messageBody)
    if (listenStatus) {
      val pendingIntents = getMultiplePendingIntents(messageParts.size, transactionId)
      smsManager.sendMultipartTextMessage(destinationAddress, null, messageParts, pendingIntents.first, pendingIntents.second)
    } else {
      smsManager.sendMultipartTextMessage(destinationAddress, null, messageParts, null, null)
    }
  }

  fun sendMms(destinationAddress: Array<String>, threadId: Long, messageBody: String?, messageSubject: String?, attachments: List<HashMap<String, Any>>, listenStatus: Boolean, transactionId: String) {
    val settings = Settings()
    settings.useSystemSending = true
    val transaction = Transaction(context.applicationContext, settings)
    val message = Message(messageBody, destinationAddress, messageSubject)
    if (attachments.isNotEmpty()) {
      for (attachment in attachments) {
        message.addMedia(attachment["data"] as ByteArray?, attachment["mimeType"] as String?, attachment["name"] as String?)
      }
    }
    if (listenStatus) {
      val intent = Intent(Constants.ACTION_MMS_SENT)
      intent.putExtra("transactionId", transactionId)
      transaction.setExplicitBroadcastForSentMms(intent)
    }
    transaction.sendNewMessage(message, threadId)
  }

  private fun getMultiplePendingIntents(size: Int, transactionId: String): Pair<ArrayList<PendingIntent>, ArrayList<PendingIntent>> {
    val sentPendingIntents = arrayListOf<PendingIntent>()
    val deliveredPendingIntents = arrayListOf<PendingIntent>()
    for (i in 1..size) {
      val pendingIntents = getPendingIntents(transactionId)
      sentPendingIntents.add(pendingIntents.first)
      deliveredPendingIntents.add(pendingIntents.second)
    }
    return Pair(sentPendingIntents, deliveredPendingIntents)
  }

  fun sendSmsIntent(destinationAddress: String, messageBody: String) {
    val intent = Intent(Intent.ACTION_SENDTO).apply {
      data = Uri.parse(SMS_TO + destinationAddress)
      putExtra(SMS_BODY, messageBody)
      flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }
    context.applicationContext.startActivity(intent)
  }

  private fun getPendingIntents(transactionId: String): Pair<PendingIntent, PendingIntent> {
    val sentIntent = Intent(ACTION_SMS_SENT).apply {
      `package` = context.applicationContext.packageName
      flags = Intent.FLAG_RECEIVER_REGISTERED_ONLY
    }
    sentIntent.putExtra("transactionId", transactionId)
    val sentPendingIntent = PendingIntent.getBroadcast(context, SMS_SENT_BROADCAST_REQUEST_CODE, sentIntent, PendingIntent.FLAG_MUTABLE)

    val deliveredIntent = Intent(ACTION_SMS_DELIVERED).apply {
      `package` = context.applicationContext.packageName
      flags = Intent.FLAG_RECEIVER_REGISTERED_ONLY
    }
    deliveredIntent.putExtra("transactionId", transactionId)
    val deliveredPendingIntent = PendingIntent.getBroadcast(context, SMS_DELIVERED_BROADCAST_REQUEST_CODE, deliveredIntent, PendingIntent.FLAG_MUTABLE)

    return Pair(sentPendingIntent, deliveredPendingIntent)
  }

  private fun getSmsManager(): SmsManager {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
      val subscriptionId = SmsManager.getDefaultSmsSubscriptionId()
      if (subscriptionId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
        return SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
      }
    }
    return SmsManager.getDefault()
  }

  // PHONE
  fun openDialer(phoneNumber: String) {
    val dialerIntent = Intent(Intent.ACTION_DIAL).apply {
      data = Uri.parse("tel:$phoneNumber")
      flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }

    context.startActivity(dialerIntent)
  }

  @RequiresPermission(allOf = [Manifest.permission.CALL_PHONE])
  fun dialPhoneNumber(phoneNumber: String) {
    val callIntent = Intent(Intent.ACTION_CALL).apply {
      data = Uri.parse("tel:$phoneNumber")
      flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }

    if (callIntent.resolveActivity(context.packageManager) != null) {
      context.applicationContext.startActivity(callIntent)
    }
  }

  // STATUS
  fun isSmsCapable(): Boolean {
    val telephonyManager = getTelephonyManager()
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      telephonyManager.isSmsCapable
    } else {
      val packageManager = context.packageManager
      if (packageManager != null) {
        return packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
      }
      return false
    }
  }

  fun getCellularDataState(): Int {
    return getTelephonyManager().dataState
  }

  fun getCallState(): Int {
    return getTelephonyManager().callState
  }

  fun getDataActivity(): Int {
    return getTelephonyManager().dataActivity
  }

  fun getNetworkOperator(): String {
    return getTelephonyManager().networkOperator
  }

  fun getNetworkOperatorName(): String {
    return getTelephonyManager().networkOperatorName
  }

  @SuppressLint("MissingPermission")
  fun getDataNetworkType(): Int {
    val telephonyManager = getTelephonyManager()
    return if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) {
      telephonyManager.dataNetworkType
    } else {
      telephonyManager.networkType
    }
  }

  fun getPhoneType(): Int {
    return getTelephonyManager().phoneType
  }

  fun getSimOperator(): String {
    return getTelephonyManager().simOperator
  }

  fun getSimOperatorName(): String {
    return getTelephonyManager().simOperatorName
  }

  fun getSimState(): Int {
    return getTelephonyManager().simState
  }

  fun isNetworkRoaming(): Boolean {
    return getTelephonyManager().isNetworkRoaming
  }

  @RequiresApi(Build.VERSION_CODES.O)
  @RequiresPermission(allOf = [Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.READ_PHONE_STATE])
  fun getServiceState(): Int? {
    val serviceState = getTelephonyManager().serviceState
    return serviceState?.state
  }

  @RequiresApi(Build.VERSION_CODES.Q)
  fun getSignalStrength(): List<Int>? {
    val signalStrength = getTelephonyManager().signalStrength
    return signalStrength?.cellSignalStrengths?.map {
      return@map it.level
    }
  }

  private fun getTelephonyManager(): TelephonyManager {
    return context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
  }
}