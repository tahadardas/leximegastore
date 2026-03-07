import 'dart:typed_data';

import 'pdf_file_saver_stub.dart'
    if (dart.library.html) 'pdf_file_saver_web.dart'
    as impl;

Future<bool> savePdfFile(Uint8List bytes, String fileName) {
  return impl.savePdfFile(bytes, fileName);
}
