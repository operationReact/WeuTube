import 'dart:async';
import 'dart:typed_data';

/// Sequential, bounded-memory reader for FilePicker's streaming file handle.
/// The video stays on the device; reads never load the entire file into RAM.
/// To resume after process death, the creator reselects the original file.
class UploadChunkReader {
  UploadChunkReader(Stream<List<int>> source) : _source = StreamIterator(source);
  final StreamIterator<List<int>> _source;
  List<int> _current = const [];
  int _cursor = 0;
  int position = 0;
  bool _closed = false;

  Future<bool> _ensureAvailable() async {
    if (_closed) return false;
    while (_cursor >= _current.length) {
      if (!await _source.moveNext()) return false;
      _current = _source.current;
      _cursor = 0;
    }
    return true;
  }

  Future<void> skip(int count) async {
    if (count < 0) throw ArgumentError.value(count, 'count');
    var remaining = count;
    while (remaining > 0) {
      if (!await _ensureAvailable()) {
        throw StateError('Selected video ended before the acknowledged byte offset');
      }
      final copied = (remaining < _current.length - _cursor)
        ? remaining : _current.length - _cursor;
      _cursor += copied;
      position += copied;
      remaining -= copied;
    }
  }

  Future<Uint8List> readExact(int count) async {
    if (count < 0 || count > 8 * 1024 * 1024) {
      throw ArgumentError.value(count, 'count', 'One chunk must be <= 8 MiB');
    }
    final builder = BytesBuilder(copy: false);
    var remaining = count;
    while (remaining > 0) {
      if (!await _ensureAvailable()) {
        throw StateError('Selected video is shorter than the reported length');
      }
      final copied = (remaining < _current.length - _cursor)
        ? remaining : _current.length - _cursor;
      builder.add(Uint8List.fromList(
        _current.getRange(_cursor, _cursor + copied).toList()));
      _cursor += copied;
      position += copied;
      remaining -= copied;
    }
    return builder.takeBytes();
  }

  Future<void> close() async {
    _closed = true;
    await _source.cancel();
  }
}
