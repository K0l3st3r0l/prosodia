import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({
    super.key,
    this.prefix = 'Versión ',
    this.style,
    this.textAlign,
  });

  final String prefix;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final Future<String> _versionFuture = _loadVersionText();

  static Future<String> _loadVersionText() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'v${packageInfo.version}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _versionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return Text(
          '$prefix${snapshot.data!}',
          textAlign: textAlign,
          style: style,
        );
      },
    );
  }
}
