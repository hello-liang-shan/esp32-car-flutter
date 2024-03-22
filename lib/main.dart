import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  [
    Permission.location,
    Permission.storage,
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
  ].request().then((status) {
      
    FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);

    runApp(const MaterialApp(
      home: ControllerApp()
    ));

  });
}

class ControllerApp extends StatefulWidget {
  const ControllerApp({ Key? key}) : super(key: key);

  @override
  State<ControllerApp> createState() {
    return ControllerState();
  }
}

class ControllerState extends State<ControllerApp> {
  String indicator = "Search";
  BluetoothCharacteristic? control;
  List<int> previous = [0, 0];

  void onConnectButtonPressed() async {
    setState(() {
      indicator = "Connecting...";
    });

    try {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("~~~~~ ble turnOn & stopScan error ~~~~~");
    }

    try {

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));

      for (var device in await FlutterBluePlus.systemDevices) {
        await device.disconnect();
      }

      var result = await FlutterBluePlus.scanResults
        .expand((element) => element)
        .firstWhere((result) => result.device.platformName == "car-car-car");

      await FlutterBluePlus.stopScan();

      await result.device.connect();
      await result.device.discoverServices();

      var service = result.device.servicesList.firstWhere((service) => service.serviceUuid == Guid("00000000-0000-0000-0000-000000000000"));

      setState(() {
        control = service.characteristics.firstWhere((characteristics) => characteristics.uuid == Guid("00000000-0000-0000-0000-000000000001"));
        indicator = result.device.platformName;
      });

    } catch (e) {
      debugPrint("~~~~~ ble error ~~~~~");
    }
  }

  Joystick buildJoystick() {
    return Joystick(
      mode: JoystickMode.horizontalAndVertical,
      listener: onPositionUpdated,
    );
  }

  ElevatedButton buildConnectButton() {
    return ElevatedButton(
      onPressed: onConnectButtonPressed,
      child: Text(indicator),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, 0.8),
              child: buildJoystick(),
            ),
            Align(
              alignment: const Alignment(0, 0),
              child: buildConnectButton(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> onPositionUpdated(StickDragDetails details) async {
    if (control == null) {
      return;
    }

    var px = (details.x * 127).clamp(-127, 127).toInt();
    var py = (details.y * 127).clamp(-127, 127).toInt();

    if (px > 0) {
      px = 1 << 0;
    }

    if (px < 0) {
      px = 1 << 1;
    }

    if (py > 0) {
      py = 1 << 0;
    }

    if (py < 0) {
      py = 1 << 1;
    }

    var payload = [px, py];

    if (listEquals(previous, payload)) {
      return;
    }

    setState(() {
      previous = payload;
    });
      
    control?.write(payload, withoutResponse: true);

    debugPrint("~~~~~ ble payload $payload ~~~~~");
  }
}
