const String kBaseUrl = 'https://anahuac.laravas.com/api';
const String kOtaUrl = 'https://ota.laravas.com';
// El manifiesto vive en /prosodia-version.json, no en la raíz. Hasta el build 37
// esta constante apuntaba a '$kOtaUrl/version.json', que nunca existió en el
// nginx del OTA: el chequeo de actualización fallaba en silencio (el 404
// devuelve HTML, `data['build']` revienta y OtaService solo lo escribe al log).
// Hay un shim en el servidor sirviendo también la raíz para que las tablets con
// build <= 37 puedan actualizarse; se elimina cuando toda la flota esté en >= 38.
// Ver wiki/projects/prosodia/bugs/ota-version-json-404.md
const String kOtaVersionUrl = '$kOtaUrl/prosodia-version.json';
const String kOtaApkUrl = '$kOtaUrl/prosodia-latest.apk';
const String kAppVersion = '1.0.0';
const int kAppBuild = 1;

const String kWhisperBase = 'https://whisper.laravas.com';
const String kWhisperUrl = '$kWhisperBase/transcribe';

// Colegios de prueba (correo + PIN). Viven en el servicio Whisper y no en
// anahuac: son alumnos de otros colegios. Ver whisper/trial.py.
const String kTrialUrl = '$kWhisperBase/trial';
const String kWhisperApiKey = 'prosodia-wh-9Km2PxRt4vYzQ8wB';
