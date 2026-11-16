import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/upload_chunk_reader.dart';

void main() {
  test('reads exact chunks and skips accepted bytes without full buffering', () async {
    final input = Stream<List<int>>.fromIterable([
      [0,1,2], [3,4,5,6], [7,8,9]
    ]);
    final reader = UploadChunkReader(input);
    await reader.skip(4);
    expect(reader.position, 4);
    expect(await reader.readExact(4), Uint8List.fromList([4,5,6,7]));
    expect(reader.position, 8);
    expect(await reader.readExact(2), Uint8List.fromList([8,9]));
    await reader.close();
  });
  test('can start a new stream at YouTube confirmed offset', () async {
    Stream<List<int>> file() =>
      Stream<List<int>>.fromIterable([[0,1,2],[3,4,5]]);
    final first = UploadChunkReader(file());
    expect(await first.readExact(4), Uint8List.fromList([0,1,2,3]));
    await first.close();
    final resumed = UploadChunkReader(file());
    await resumed.skip(3);
    expect(await resumed.readExact(3), Uint8List.fromList([3,4,5]));
    await resumed.close();
  });
  test('rejects impossible length and out-of-range seek', () async {
    final reader = UploadChunkReader(
      Stream<List<int>>.fromIterable([[1,2]]));
    await expectLater(reader.skip(5),throwsStateError);
    await reader.close();
    final next=UploadChunkReader(Stream<List<int>>.fromIterable([[1]]));
    await expectLater(next.readExact(2),throwsStateError);
    expect(() => next.readExact(8*1024*1024+1),throwsArgumentError);
    await next.close();
  });
}
