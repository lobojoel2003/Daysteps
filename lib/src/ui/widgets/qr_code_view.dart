import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

/// Draws [data] as a QR code with a quiet zone.
class QrCodeView extends StatelessWidget {
  QrCodeView({super.key, required this.data, this.size = 280})
    : _image = QrImage(
        QrCode(
          payload: QrPayload.fromString(data),
          errorCorrectLevel: QrErrorCorrectLevel.low,
        ),
      );

  final String data;
  final double size;
  final QrImage _image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'QR code',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _QrPainter(_image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    const quiet = 4; // modules of white border, as the standard asks
    final count = image.moduleCount;
    final cell = size.shortestSide / (count + quiet * 2);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final dark = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    final path = Path();
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (image.isDark(row, col)) {
          path.addRect(
            Rect.fromLTWH(
              (col + quiet) * cell,
              (row + quiet) * cell,
              cell + 0.5,
              cell + 0.5,
            ),
          );
        }
      }
    }
    canvas.drawPath(path, dark);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
