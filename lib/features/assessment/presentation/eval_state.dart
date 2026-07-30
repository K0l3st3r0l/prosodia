/// Etapas de una sesión de evaluación.
///
/// Vive en su propio archivo para que los widgets de presentación puedan
/// tiparse contra él sin importar la pantalla completa.
enum EvalState { idle, recording, analyzing, reviewing }
