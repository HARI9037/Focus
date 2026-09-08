import 'dart:io';
import 'package:flutter/services.dart';

class DeviceBridge {
  static const channel = MethodChannel('com.personal.focus/device');
  bool get supported => Platform.isAndroid;
  Future<Map<String,dynamic>> status() async {
    if (!supported) return {'supported': false, 'state': 'unavailable', 'reason': 'Phone sync is not connected'};
    return Map<String,dynamic>.from(await channel.invokeMapMethod<String,dynamic>('status') ?? {});
  }
  Future<void> configure(Map<String,dynamic> settings) async {
    if (supported) await channel.invokeMethod<void>('configure', settings);
  }
  Future<void> permission(String kind) async {
    if (supported) await channel.invokeMethod<void>('permission', {'kind':kind});
  }
  Future<List<Map<String,dynamic>>> apps() async {
    if (!supported) return [];
    return (await channel.invokeListMethod<dynamic>('apps') ?? []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<List<Map<String,dynamic>>> usage(DateTime start, DateTime end) async {
    if (!supported) return [];
    return (await channel.invokeListMethod<dynamic>('usage', {'start':start.millisecondsSinceEpoch,'end':end.millisecondsSinceEpoch}) ?? [])
      .map((e) => Map<String,dynamic>.from(e as Map)).toList();
  }
  Future<void> emergency() async {
    if (supported) await channel.invokeMethod<void>('emergency');
  }
  Future<void> export(String content, String extension) async {
    await channel.invokeMethod<void>('export', {'content':content, 'extension':extension});
  }
}
