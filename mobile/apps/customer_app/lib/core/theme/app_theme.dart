import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const grapBrand = Color(0xff08a665);
const grapGreen = Color(0xff087f50);
const grapInk = Color(0xff172c24);
const grapMuted = Color(0xff65776e);
const grapWarning = Color(0xff8a4b10);
const grapDanger = Color(0xffb3261e);
String vnd(int amount) =>
    '${NumberFormat.decimalPattern('vi_VN').format(amount)} ₫';
String serviceLabel(String code) =>
    const {
      'BIKE': 'GrapBike',
      'CAR_4': 'GrapCar 4 chỗ',
      'CAR_7': 'GrapCar 7 chỗ',
    }[code] ??
    code;
String stateLabel(String code) =>
    const {
      'SEARCHING': 'Đang tìm tài xế',
      'ASSIGNED': 'Tài xế đang đến đón',
      'DRIVER_ARRIVED': 'Đã đến điểm đón',
      'IN_PROGRESS': 'Đang di chuyển',
      'COMPLETED': 'Hoàn thành',
      'CANCELED': 'Đã hủy',
      'NO_DRIVER': 'Chưa tìm được tài xế',
      'EXPIRED': 'Đã hết hạn',
      'PENDING': 'Chưa thu đủ',
      'SUCCEEDED': 'Đã thu đủ',
    }[code] ??
    code;
ThemeData grapTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: grapBrand, surface: Colors.white)
      .copyWith(
        primary: grapGreen,
        onPrimary: Colors.white,
        surfaceTint: Colors.transparent,
      ),
  scaffoldBackgroundColor: const Color(0xfff7f9f8),
  fontFamily: 'Roboto',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 16, color: grapInk, height: 1.4),
    bodyMedium: TextStyle(fontSize: 14, color: grapInk, height: 1.4),
    bodySmall: TextStyle(fontSize: 14, color: grapMuted, height: 1.4),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: grapInk,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: grapGreen,
      letterSpacing: -1,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 72,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    indicatorColor: const Color(0xffe6f5ed),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
        color: states.contains(WidgetState.selected) ? grapGreen : grapMuted,
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? grapGreen : grapMuted,
      ),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xffe7ebe8)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xfff7f9f8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffe2ebe5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffe2ebe5)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: Color(0xffdce8df)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xffedf1ee),
    thickness: 1,
    space: 24,
  ),
);
