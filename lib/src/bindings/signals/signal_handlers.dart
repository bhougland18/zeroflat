part of 'signals.dart';

final assignRustSignal = <String, void Function(Uint8List, Uint8List)>{
  'UiUpdate': (Uint8List messageBytes, Uint8List binary) {
    final message = UiUpdate.bincodeDeserialize(messageBytes);
    final rustSignal = RustSignalPack(
      message,
      binary,
    );
    _uiUpdateStreamController.add(rustSignal);
    UiUpdate.latestRustSignal = rustSignal;
  },
};
