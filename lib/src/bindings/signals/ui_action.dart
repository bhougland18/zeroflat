// ignore_for_file: type=lint, type=warning
part of 'signals.dart';

/// Signal from Dart to Rust carrying a UiActionEnvelope FlatBuffer.
@immutable
class UiAction {
  const UiAction(
  );

  static UiAction deserialize(BinaryDeserializer deserializer) {
    deserializer.increaseContainerDepth();
    final instance = UiAction(
    );
    deserializer.decreaseContainerDepth();
    return instance;
  }

  static UiAction bincodeDeserialize(Uint8List input) {
    final deserializer = BincodeDeserializer(input);
    final value = UiAction.deserialize(deserializer);
    if (deserializer.offset < input.length) {
      throw Exception('Some input bytes were not read');
    }
    return value;
  }

  void serialize(BinarySerializer serializer) {
    serializer.increaseContainerDepth();
    serializer.decreaseContainerDepth();
  }

  Uint8List bincodeSerialize() {
      final serializer = BincodeSerializer();
      serialize(serializer);
      return serializer.bytes;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;

    return other is UiAction;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    String? fullString;

    assert(() {
      fullString = '$runtimeType('
        ')';
      return true;
    }());

    return fullString ?? 'UiAction';
  }
}

extension UiActionDartSignalExt on UiAction {
  /// Sends the signal to Rust with separate binary data.
  /// Passing data from Rust to Dart involves a memory copy
  /// because Rust cannot own data managed by Dart's garbage collector.
  void sendSignalToRust(Uint8List binary) {
    final messageBytes = bincodeSerialize();
    sendDartSignal(
      'rinf_send_dart_signal_ui_action',
      messageBytes,
      binary,
    );
  }
}
