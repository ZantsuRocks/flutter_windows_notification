import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';

import 'windows_notification_platform_interface.dart';

/// An implementation of [WindowsNotificationPlatform] that uses method channels.
class MethodChannelWindowsNotification extends WindowsNotificationPlatform {
  static OnTapNotification? tapCallBack;
  static Map<String, String> templates = {
    "show_notification_image": '''
<?xml version="1.0" encoding="utf-8"?>
<toast activationType="protocol">
  <visual>
    <binding template="ToastGeneric">
      <text id="1">Test message</text>
         <text id="2">Test message</text>
          <image placement="appLogoOverride" hint-crop="circle" id="1"/>
          <image src='#1#'/>
    </binding>
  </visual>
</toast>
''',
    "show_notification": '''
<?xml version="1.0" encoding="utf-8"?>
<toast activationType="protocol">
  <visual>
    <binding template="ToastGeneric">
      <text id="1">Test message</text>
         <text id="2">Test message</text>
            <image src='#1#'/>
    </binding>
  </visual>
</toast>
'''
  };

  @visibleForTesting
  final methodChannel = const MethodChannel('windows_notification');

  @override
  Future<void> showNotification(final NotificationMessage notification,
      final String applicationId) async {
    final data = notification.toJson;
    data["application_id"] = applicationId;
    String? templateXml = templates[notification.methodNmae]?.trim();

    if (notification.largeImage != null) {
      templateXml = templateXml?.replaceFirst("#1#", notification.largeImage!);
    } else {
      templateXml = templateXml?.replaceFirst("#1#", '');
    }

    data["template"] = templateXml;
    await methodChannel.invokeMethod(notification.methodNmae, data);
  }

  @override
  Future<void> showNotificationCustomTemplate(
      final NotificationMessage notification,
      final String applicationId,
      final String template) async {
    assert(notification.temolateType == TemplateType.custom,
        "Use NotificationMessage.fromCustomTemplate to create notification object");
    final data = notification.toJson;
    data["application_id"] = applicationId;
    data["template"] = template;
    await methodChannel.invokeMethod(notification.methodNmae, data);
  }

  @override
  Future<void> clearNotificationHistory(final String applicationId) async {
    await methodChannel
        .invokeMethod("clear_history", {"application_id": applicationId});
  }

  @override
  Future<void> removeNotification(
      String id, final String group, final String applicationId) async {
    await methodChannel.invokeMethod("remove_notification",
        {"tag": id, "group": group, "application_id": applicationId});
  }

  @override
  Future<void> removeNotificationGroup(
      String group, final String applicationId) async {
    await methodChannel.invokeMethod(
        "remove_group", {"group": group, "application_id": applicationId});
  }

  @override
  Future<void> initNotificationCallBack(OnTapNotification? callback) async {
    tapCallBack = callback;
    methodChannel.setMethodCallHandler((MethodCall call) async {
      try {
        final Map<String, dynamic> payload =
            json.decode(call.arguments["launch"]);
        final NotificationMessage msg = NotificationMessage.fromJson(
          payload,
        );
        EventType type = EventType.values
            .firstWhere((element) => element.name == call.method);
        tapCallBack?.call(msg, type, call.arguments["arguments"]);
        // ignore: empty_catches
      } catch (e) {
        throw Exception("OnTapNotification arguments error $e");
      }
    });
  }
}
