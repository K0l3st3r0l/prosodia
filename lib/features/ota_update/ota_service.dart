import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants.dart';
import '../../core/log_service.dart';

class OtaService {
  final Dio _dio;

  OtaService(this._dio);

  Future<void> checkAndUpdate({
    void Function(double progress)? onProgress,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(packageInfo.buildNumber) ?? kAppBuild;

      LogService.instance.info('OTA: Checking for updates...');
      final versionRes = await _dio.get(kOtaVersionUrl);
      final serverBuild = versionRes.data['build'] as int? ?? 0;
      final apkUrl = versionRes.data['url'] as String? ?? kOtaApkUrl;
      LogService.instance.info('OTA: Server build=$serverBuild, local build=$localBuild');

      if (serverBuild <= localBuild) {
        LogService.instance.info('OTA: No update needed (installed=$localBuild, server=$serverBuild)');
        return;
      }

      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/prosodia-update.apk';
      LogService.instance.info('OTA: Downloading to $apkPath');

      await _dio.download(
        apkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final apkFile = File(apkPath);
      final fileSize = await apkFile.length();
      LogService.instance.info('OTA: Downloaded APK, size=$fileSize bytes');

      if (fileSize == 0) {
        throw Exception('APK file is empty');
      }

      LogService.instance.info('OTA: Starting installation...');
      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      LogService.instance.info('OTA: OpenFilex result: ${result.type} — ${result.message}');
    } catch (e, st) {
      LogService.instance.error('OTA: Update failed: $e', st);
    }
  }
}
