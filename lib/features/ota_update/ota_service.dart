import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_package_installer/android_package_installer.dart';
import '../../core/constants.dart';

class OtaService {
  final Dio _dio;

  OtaService(this._dio);

  Future<void> checkAndUpdate({
    void Function(double progress)? onProgress,
  }) async {
    try {
      final versionRes = await _dio.get(kOtaVersionUrl);
      final serverBuild = versionRes.data['build'] as int? ?? 0;
      if (serverBuild <= kAppBuild) return;

      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/prosodia-update.apk';

      await _dio.download(
        kOtaApkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      await AndroidPackageInstaller.installApk(apkFilePath: apkPath);
    } catch (_) {
      // Si falla (sin red, servidor caído) no bloqueamos la app
    }
  }
}
