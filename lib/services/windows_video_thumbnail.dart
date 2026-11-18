import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Uses the installed Windows thumbnail provider for the media format.
Future<Uint8List?> videoThumbnail(File file) {
  if (!Platform.isWindows) return Future.value();
  final path = file.absolute.path;
  return Isolate.run(() => _windowsThumbnail(path));
}

final class _Size extends Struct {
  @Int32()
  external int width;
  @Int32()
  external int height;
}

final class _Bitmap extends Struct {
  @Int32()
  external int type;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int widthBytes;
  @Uint16()
  external int planes;
  @Uint16()
  external int bitsPerPixel;
  external Pointer<Void> bits;
}

typedef _CreateItemNative = Int32 Function(
    Pointer<Utf16>, Pointer<Void>, Pointer<Uint8>, Pointer<Pointer<Void>>);
typedef _CreateItem = int Function(
    Pointer<Utf16>, Pointer<Void>, Pointer<Uint8>, Pointer<Pointer<Void>>);
typedef _GetImageNative = Int32 Function(
    Pointer<Void>, _Size, Uint32, Pointer<Pointer<Void>>);
typedef _GetImage = int Function(
    Pointer<Void>, _Size, int, Pointer<Pointer<Void>>);
typedef _GetBitsNative = Int32 Function(Pointer<Void>, Pointer<Void>, Uint32,
    Uint32, Pointer<Uint8>, Pointer<Uint8>, Uint32);
typedef _GetBits = int Function(Pointer<Void>, Pointer<Void>, int, int,
    Pointer<Uint8>, Pointer<Uint8>, int);

Uint8List? _windowsThumbnail(String path) {
  final ole = DynamicLibrary.open('ole32.dll');
  final initialize = ole.lookupFunction<Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)>('CoInitializeEx');
  final uninitialize =
      ole.lookupFunction<Void Function(), void Function()>('CoUninitialize');
  final result = initialize(nullptr, 2); // COINIT_APARTMENTTHREADED
  if (result < 0) return null;
  try {
    return using((arena) {
      final create = DynamicLibrary.open('shell32.dll')
          .lookupFunction<_CreateItemNative, _CreateItem>(
              'SHCreateItemFromParsingName');
      // IID_IShellItemImageFactory, bcc18b79-ba16-442f-80c4-8a59c30c463b.
      final iid = arena<Uint8>(16);
      iid.asTypedList(16).setAll(0, const [
        0x79,
        0x8b,
        0xc1,
        0xbc,
        0x16,
        0xba,
        0x2f,
        0x44,
        0x80,
        0xc4,
        0x8a,
        0x59,
        0xc3,
        0x0c,
        0x46,
        0x3b,
      ]);
      final item = arena<Pointer<Void>>();
      if (create(path.toNativeUtf16(allocator: arena), nullptr, iid, item) <
          0) {
        return null;
      }

      final vtable = item.value.cast<Pointer<Pointer<Void>>>().value;
      final release = vtable[2]
          .cast<NativeFunction<Uint32 Function(Pointer<Void>)>>()
          .asFunction<int Function(Pointer<Void>)>();
      try {
        final getImage = vtable[3]
            .cast<NativeFunction<_GetImageNative>>()
            .asFunction<_GetImage>();
        final size = arena<_Size>()..ref.width = 256;
        size.ref.height = 160;
        final bitmap = arena<Pointer<Void>>();
        // SIIGBF_THUMBNAILONLY prevents returning a generic file icon.
        if (getImage(item.value, size.ref, 0x8, bitmap) < 0 ||
            bitmap.value == nullptr) {
          return null;
        }
        return _bitmapBytes(bitmap.value, arena);
      } finally {
        release(item.value);
      }
    });
  } finally {
    uninitialize();
  }
}

Uint8List? _bitmapBytes(Pointer<Void> bitmap, Arena arena) {
  final gdi = DynamicLibrary.open('gdi32.dll');
  final deleteObject = gdi.lookupFunction<Int32 Function(Pointer<Void>),
      int Function(Pointer<Void>)>('DeleteObject');
  try {
    final getObject = gdi.lookupFunction<
        Int32 Function(Pointer<Void>, Int32, Pointer<Void>),
        int Function(Pointer<Void>, int, Pointer<Void>)>('GetObjectW');
    final details = arena<_Bitmap>();
    if (getObject(bitmap, sizeOf<_Bitmap>(), details.cast()) == 0) return null;
    final width = details.ref.width, height = details.ref.height;
    if (width < 1 || width > 512 || height < 1 || height > 512) return null;

    final createDc = gdi.lookupFunction<Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)>('CreateCompatibleDC');
    final deleteDc = gdi.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('DeleteDC');
    final dc = createDc(nullptr);
    if (dc == nullptr) return null;
    try {
      final getBits = gdi.lookupFunction<_GetBitsNative, _GetBits>('GetDIBits');
      final stride = (width * 3 + 3) & ~3;
      final size = stride * height;
      final info = arena<Uint8>(40);
      final header = ByteData.sublistView(info.asTypedList(40))
        ..setUint32(0, 40, Endian.little)
        ..setInt32(4, width, Endian.little)
        ..setInt32(8, height, Endian.little)
        ..setUint16(12, 1, Endian.little)
        ..setUint16(14, 24, Endian.little)
        ..setUint32(20, size, Endian.little);
      final pixels = arena<Uint8>(size);
      if (getBits(dc, bitmap, 0, height, pixels, info, 0) != height) {
        return null;
      }

      final bytes = Uint8List(54 + size);
      ByteData.sublistView(bytes)
        ..setUint16(0, 0x4d42, Endian.little)
        ..setUint32(2, bytes.length, Endian.little)
        ..setUint32(10, 54, Endian.little);
      bytes.setRange(14, 54, header.buffer.asUint8List());
      bytes.setRange(54, bytes.length, pixels.asTypedList(size));
      return bytes;
    } finally {
      deleteDc(dc);
    }
  } finally {
    deleteObject(bitmap);
  }
}
