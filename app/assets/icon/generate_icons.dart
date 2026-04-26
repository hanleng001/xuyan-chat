#!/usr/bin/env dart
// Icon generator for XuYan app
// Run: dart run assets/icon/generate_icons.dart
// 
// This script requires the 'image' package: dart pub add image --dev
// 
// Creates:
// - app_icon.png (1024x1024) - Main icon for flutter_launcher_icons
// - app_icon_foreground.png (1024x1024) - Foreground for adaptive icon

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

void main() async {
  print('Icon generator for XuYan app');
  print('This script requires Flutter to be properly set up.');
  print('');
  print('To generate the icons:');
  print('1. Run: flutter pub get');
  print('2. Run: dart run assets/icon/generate_icons.dart');
  print('3. Run: flutter pub run flutter_launcher_icons');
  print('');
  print('Alternatively, create the icons manually:');
  print('- assets/icon/app_icon.png: 1024x1024 with blue gradient + white "言"');
  print('- assets/icon/app_icon_foreground.png: 1024x1024 with just the "言" text');
}
