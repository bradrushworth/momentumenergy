// A stand-in for the platform file picker, so tests can drive
// CsvState.importFile (and the screens that call it) without a platform
// channel: usePicker(PickedFile(name, text)) picks a file, usePicker(null)
// is the user cancelling.

import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the platform picker: returns [file] (null = the user
/// cancelled) without any platform channel.
class FakePicker extends FilePickerPlatform {
  final PlatformFile? file;

  FakePicker(this.file);

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      file;
}

/// A picked file whose bytes are [text], UTF-8 encoded.
final class PickedFile extends PlatformFile {
  @override
  final String name;
  final String text;

  PickedFile(this.name, this.text);

  @override
  Uri get uri => Uri.file(name);

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => utf8.encode(text).length;

  @override
  Future<int?> length() async => lengthSync();

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(utf8.encode(text));

  @override
  Stream<Uint8List> readAsByteStream() => Stream.fromFuture(readAsBytes());
}

/// Swaps in a fake picker for one test.
void usePicker(PlatformFile? file) {
  final original = FilePickerPlatform.instance;
  FilePickerPlatform.instance = FakePicker(file);
  addTearDown(() => FilePickerPlatform.instance = original);
}
