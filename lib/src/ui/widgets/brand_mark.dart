import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The Daysteps logo: three steps up towards the sun.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  static const asset = 'assets/branding/logo.svg';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: 'Daysteps',
    );
  }
}
