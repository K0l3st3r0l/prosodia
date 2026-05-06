import 'package:drift/drift.dart' show Value;

import 'database/app_database.dart';

// Textos originales para evaluación de fluidez lectora con progresión por nivel.
// 1°-2°: narraciones breves y vocabulario cotidiano.
// 3°-4°: secuencias más extensas y primeras lecturas informativas.
// 5°-6°: textos narrativos e informativos con mayor densidad conceptual.
// 7°-8°: textos expositivos, históricos y reflexivos de mayor complejidad.
// El nivel se asigna extrayendo el dígito inicial del campo "curso" (ej: "2°A" → "2").

const _textos = [
  // 1° básico
  (
    nivel: '1',
    titulo: 'El perro y la pelota',
    texto:
        'Tito es un perro pequeño y alegre.\n'
        'Tiene el pelo café y las orejas largas.\n'
        'Su juguete favorito es una pelota roja.\n\n'
        'Un día la pelota cayó al río.\n'
        'Tito corrió hasta la orilla y la miró.\n'
        'El agua era fría, pero él no tuvo miedo.\n'
        'Saltó al río y nadó con fuerza.\n\n'
        'Volvió a la orilla con la pelota en la boca.\n'
        'Su dueño lo abrazó y le dio un premio.\n'
        'Tito movió la cola muy contento.',
  ),
  (
    nivel: '1',
    titulo: 'La mochila azul',
    texto:
        'Martina tiene una mochila azul.\n'
        'Cada mañana guarda su cuaderno,\n'
        'su estuche y una colación.\n\n'
        'Un día la mochila quedó abierta.\n'
        'Un lápiz cayó al suelo del patio.\n'
        'Su amigo Diego lo vio primero.\n\n'
        'Diego tomó el lápiz y corrió.\n'
        'Martina sonrió al recibirlo.\n'
        'Después cerró bien su mochila.\n'
        'Desde ese día siempre revisa el cierre.',
  ),
  (
    nivel: '1',
    titulo: 'Las nubes de algodón',
    texto:
        'Sofía miró el cielo desde la ventana.\n'
        'Había nubes blancas y suaves.\n'
        'Parecían grandes bolas de algodón.\n\n'
        'Una nube tenía forma de conejo.\n'
        'Otra parecía un barco lento.\n'
        'Sofía llamó a su hermano Tomás.\n\n'
        'Los dos jugaron a descubrir figuras.\n'
        'Rieron cuando vieron una nube con forma de pez.\n'
        'Luego empezó a soplar el viento\n'
        'y todas las figuras cambiaron de lugar.',
  ),

  // 2° básico
  (
    nivel: '2',
    titulo: 'La semilla mágica',
    texto:
        'Ana encontró una semilla en el patio de su casa.\n'
        'Era pequeña, redonda y de color café oscuro.\n'
        'La guardó en su bolsillo y la llevó a la cocina.\n\n'
        'Su abuela le dijo que era una semilla de girasol.\n'
        'Juntas buscaron una maceta, tierra y agua.\n'
        'Ana plantó la semilla con mucho cuidado.\n'
        'La regó todos los días antes de ir al colegio.\n\n'
        'Pasaron tres semanas y apareció un tallo verde.\n'
        'Ana gritó de alegría cuando vio las primeras hojas.\n'
        'Al mes, un girasol amarillo miraba hacia el sol.\n'
        'Desde ese día, Ana supo que con paciencia todo crece.',
  ),
  (
    nivel: '2',
    titulo: 'El cuaderno viajero',
    texto:
        'En el curso de Benjamín había un cuaderno especial.\n'
        'Cada viernes viajaba a una casa distinta.\n'
        'El niño o la niña que lo llevaba\n'
        'debía escribir algo sobre su fin de semana.\n\n'
        'Ese viernes el cuaderno llegó a manos de Benjamín.\n'
        'Él escribió sobre la sopaipilla que cocinó con su abuelo\n'
        'y sobre el paseo que dieron por la plaza.\n\n'
        'El lunes leyó su texto en voz alta.\n'
        'Sus compañeros escucharon atentos\n'
        'y después hicieron preguntas.\n'
        'Benjamín descubrió que una historia sencilla\n'
        'también podía interesar a todo el curso.',
  ),
  (
    nivel: '2',
    titulo: 'La feria del barrio',
    texto:
        'Los sábados, la calle de Camila cambia por completo.\n'
        'Muy temprano llegan camiones con cajones de frutas,\n'
        'verduras, pan y flores.\n\n'
        'Camila acompaña a su padre a la feria.\n'
        'Le gusta escuchar las voces de los vendedores\n'
        'y mirar los colores de las manzanas,\n'
        'los tomates y los limones.\n\n'
        'Un feriante le regaló una rama de albahaca.\n'
        'Camila la olió con curiosidad.\n'
        'El aroma era fresco y fuerte a la vez.\n'
        'Cuando volvió a casa, su madre la puso en la ensalada\n'
        'y toda la mesa olió a verano.',
  ),

  // 3° básico
  (
    nivel: '3',
    titulo: 'El faro del cabo',
    texto:
        'En lo alto de un acantilado vivía don Héctor, el farero.\n'
        'Cada noche encendía la gran lámpara del faro\n'
        'para que los barcos no chocaran contra las rocas.\n\n'
        'Una noche de tormenta, la lámpara se apagó de repente.\n'
        'El viento soplaba tan fuerte que las ventanas temblaban.\n'
        'Don Héctor tomó su linterna y subió los cien escalones.\n\n'
        'Con sus manos frías revisó cada pieza de la lámpara.\n'
        'Encontró un cable suelto y lo arregló en la oscuridad.\n'
        'La luz volvió a girar y a iluminar el mar.\n\n'
        'A lo lejos, el capitán de un barco vio el destello.\n'
        'Cambió el rumbo justo a tiempo y salvó a su tripulación.\n'
        'Don Héctor nunca supo que esa noche había salvado veinte vidas.',
  ),
  (
    nivel: '3',
    titulo: 'La carta para el abuelo',
    texto:
        'Amparo aprendió a escribir cartas en la escuela.\n'
        'Ese mismo día decidió enviar una al abuelo Ernesto,\n'
        'que vivía en otra ciudad.\n\n'
        'Se sentó en la mesa de la cocina\n'
        'y escribió con letra muy clara.\n'
        'Le contó que ya podía andar en bicicleta sin ayuda,\n'
        'que su perro había aprendido a dar la pata\n'
        'y que en primavera floreció el limonero del patio.\n\n'
        'También le hizo un dibujo de la casa\n'
        'con humo saliendo por la chimenea.\n'
        'Cuando terminó, metió la carta en un sobre amarillo\n'
        'y la llevó al buzón junto a su madre.\n\n'
        'Dos semanas después llegó la respuesta.\n'
        'El abuelo decía que había leído la carta tres veces\n'
        'y que el dibujo ya estaba pegado en su refrigerador.',
  ),
  (
    nivel: '3',
    titulo: 'El puente de madera',
    texto:
        'En el camino a la escuela había un puente de madera\n'
        'que cruzaba un estero angosto.\n'
        'Todos los niños pasaban por allí cada mañana.\n\n'
        'Después de varios días de lluvia,\n'
        'Matías notó que una tabla estaba suelta.\n'
        'La pisó con cuidado y escuchó un crujido.\n'
        'Entonces decidió avisar de inmediato.\n\n'
        'Fue corriendo donde la directora\n'
        'y le explicó lo que había visto.\n'
        'La directora llamó al encargado de mantención\n'
        'y puso una cinta para que nadie pasara.\n\n'
        'Esa misma tarde arreglaron el puente.\n'
        'Al día siguiente todos pudieron cruzar seguros.\n'
        'Matías entendió que observar y avisar a tiempo\n'
        'también es una forma de cuidar a los demás.',
  ),

  // 4° básico
  (
    nivel: '4',
    titulo: 'El mercado de los sabores',
    texto:
        'Cada sábado, Valentina acompañaba a su madre al mercado.\n'
        'Le gustaba el ruido de la gente, los colores de las frutas\n'
        'y el olor a especias que llenaba el aire.\n\n'
        'Un sábado encontró un puesto que nunca había visto.\n'
        'Una señora mayor vendía mermeladas de sabores extraños:\n'
        'de zapallo con canela, de tomate con albahaca\n'
        'y de frambuesa con pimienta rosada.\n\n'
        'Valentina probó la de frambuesa y abrió los ojos de par en par.\n'
        'Era dulce y picante al mismo tiempo, como una sorpresa en la boca.\n'
        'Le preguntó a la señora cómo la preparaba.\n\n'
        'La mujer sonrió y le contó que su secreto era añadir\n'
        'un ingrediente inesperado a cada receta.\n'
        '"La cocina es como la vida", le dijo.\n'
        '"Lo mejor siempre aparece cuando no lo esperas."',
  ),
  (
    nivel: '4',
    titulo: 'El taller de volantines',
    texto:
        'En septiembre, la biblioteca del barrio organizó un taller\n'
        'para aprender a construir volantines.\n'
        'Asistieron niños, niñas y también varios abuelos.\n\n'
        'La monitora explicó que primero había que elegir\n'
        'varillas livianas y papel resistente.\n'
        'Después mostró cómo pegar las esquinas\n'
        'y cómo medir la cola para que el volantín subiera derecho.\n\n'
        'A Elisa le costó amarrar el hilo central.\n'
        'Un señor que estaba a su lado le enseñó un truco:\n'
        'hacer un nudo pequeño antes de tensar la cuerda.\n'
        'Con eso el volantín quedó firme.\n\n'
        'El domingo fueron a probarlos a una cancha.\n'
        'Cuando el de Elisa levantó vuelo,\n'
        'ella sintió que todo el trabajo de la tarde anterior\n'
        'se convertía en una pequeña fiesta sobre el cielo.',
  ),
  (
    nivel: '4',
    titulo: 'La isla de los pingüinos',
    texto:
        'Frente a algunas costas de Chile existen islas pequeñas\n'
        'donde viven aves marinas, lobos marinos y pingüinos.\n'
        'En esos lugares la presencia humana debe ser muy cuidadosa.\n\n'
        'Los pingüinos necesitan espacios tranquilos para anidar.\n'
        'Si hay ruido excesivo o basura en la playa,\n'
        'muchos abandonan sus nidos antes de tiempo.\n'
        'Por eso los guardaparques marcan senderos\n'
        'y piden a los visitantes caminar sólo por rutas permitidas.\n\n'
        'También es importante no alimentar a los animales.\n'
        'Aunque parezca un gesto amable,\n'
        'puede cambiar su conducta y afectar su salud.\n\n'
        'Cuidar una isla no significa mirarla de lejos,\n'
        'sino visitarla con respeto.\n'
        'Cuando las personas siguen las normas,\n'
        'la naturaleza puede continuar su ciclo sin interrupciones.',
  ),

  // 5° básico
  (
    nivel: '5',
    titulo: 'El río que olvidó su camino',
    texto:
        'Cuentan los habitantes del valle que hubo un tiempo\n'
        'en que el río Claro perdió su camino.\n'
        'Nadie sabe con certeza cómo ocurrió.\n'
        'Algunos dicen que un terremoto movió las piedras del fondo;\n'
        'otros aseguran que fue la sequía la que lo confundió.\n\n'
        'El caso es que el río comenzó a desviarse hacia el este,\n'
        'alejándose de los campos que siempre había regado.\n'
        'Los agricultores vieron secarse sus huertas\n'
        'y los animales buscaron agua en otros lugares.\n\n'
        'Fue una niña de doce años, llamada Isidora, quien tuvo la idea.\n'
        'Propuso abrir un canal pequeño con palas y picos\n'
        'para recordarle al río su antiguo camino.\n'
        'Los vecinos trabajaron durante semanas bajo el sol.\n\n'
        'Cuando el canal estuvo listo, el agua siguió la nueva ruta\n'
        'y poco a poco volvió a los campos.\n'
        'Ese año la cosecha fue la mejor en mucho tiempo,\n'
        'y todos recordaron que los grandes problemas\n'
        'a veces tienen soluciones sencillas.',
  ),
  (
    nivel: '5',
    titulo: 'La fotógrafa del humedal',
    texto:
        'Cada invierno, Amanda visitaba el humedal que quedaba\n'
        'a unos kilómetros de su ciudad.\n'
        'Iba con una libreta, una cámara antigua\n'
        'y mucha paciencia para esperar el momento preciso.\n\n'
        'Le gustaba fotografiar aves que casi nunca se dejaban ver.\n'
        'Primero anotaba la hora, la dirección del viento\n'
        'y el lugar exacto donde se escondía.\n'
        'Después permanecía en silencio durante largos minutos.\n\n'
        'Una mañana observó una garza pequeña\n'
        'caminando entre los juncos.\n'
        'No se movió ni un centímetro hasta que el ave extendió las alas.\n'
        'Entonces tomó la fotografía más nítida de toda la temporada.\n\n'
        'Al revelar la imagen descubrió reflejos dorados en el agua\n'
        'y pequeñas gotas suspendidas en el aire.\n'
        'Entendió que una buena fotografía no sólo muestra un animal,\n'
        'sino también el paisaje que lo hace posible.',
  ),
  (
    nivel: '5',
    titulo: 'La ruta del agua',
    texto:
        'El agua que llega a una casa recorre un camino mucho más largo\n'
        'de lo que muchas personas imaginan.\n'
        'Primero puede acumularse en un embalse, un río o un pozo profundo.\n'
        'Luego pasa por plantas de tratamiento\n'
        'donde se limpia y se analiza.\n\n'
        'En esas plantas se retiran hojas, tierra y otras partículas.\n'
        'Después se aplican procesos para eliminar microbios\n'
        'y asegurar que el agua sea apta para el consumo.\n'
        'Cuando ya cumple las normas sanitarias,\n'
        'viaja por una red de tuberías hasta las ciudades y los pueblos.\n\n'
        'Ese trayecto requiere bombas, estanques y mantención constante.\n'
        'Si una cañería se rompe, el suministro puede disminuir\n'
        'o perder presión en algunos sectores.\n\n'
        'Por eso abrir una llave parece un gesto simple,\n'
        'pero detrás de él existe un trabajo coordinado\n'
        'entre especialistas, operarios y sistemas de control.\n'
        'Conocer esa ruta ayuda a valorar más cada litro que usamos.',
  ),

  // 6° básico
  (
    nivel: '6',
    titulo: 'La biblioteca de las estrellas',
    texto:
        'En el desierto de Atacama, donde el cielo es tan limpio\n'
        'que parece un espejo de obsidiana, existe un observatorio\n'
        'que los astrónomos llaman "la biblioteca de las estrellas".\n\n'
        'Allí trabaja la doctora Renata Fuentes, quien lleva veinte años\n'
        'estudiando galaxias que están a millones de años luz de la Tierra.\n'
        'Su trabajo consiste en analizar la luz que llega desde esas galaxias\n'
        'para descubrir de qué elementos están compuestas.\n\n'
        'Una noche, mientras revisaba los datos del telescopio,\n'
        'notó una señal que no coincidía con ningún patrón conocido.\n'
        'Era una frecuencia de luz que oscilaba de forma regular,\n'
        'como si alguien estuviera enviando un mensaje en código.\n\n'
        'Durante meses compartió sus hallazgos con científicos de todo el mundo.\n'
        'Algunos pensaron que era un error en el instrumento;\n'
        'otros, que podría tratarse de un tipo de estrella desconocido.\n\n'
        'La doctora Fuentes no llegó a una conclusión definitiva,\n'
        'pero eso no la desanimó.\n'
        '"La ciencia avanza a través de las preguntas que no podemos responder",\n'
        'decía a sus estudiantes.\n'
        '"Cada misterio sin resolver es una invitación a seguir explorando."',
  ),
  (
    nivel: '6',
    titulo: 'La brigada del cerro',
    texto:
        'Todos los inviernos, el cerro cercano a la escuela cambiaba de color.\n'
        'Después de las primeras lluvias aparecían flores pequeñas,\n'
        'insectos y aves que casi no se veían en verano.\n'
        'Sin embargo, también llegaban bolsas plásticas, latas y botellas.\n\n'
        'Por eso un grupo de estudiantes decidió formar\n'
        'la Brigada del Cerro.\n'
        'Su idea no era sólo limpiar una vez,\n'
        'sino observar qué zonas se ensuciaban más\n'
        'y por qué ocurría eso.\n\n'
        'Durante un mes registraron recorridos, horarios y tipos de residuos.\n'
        'Descubrieron que la mayor parte de la basura\n'
        'aparecía cerca de una parada de buses\n'
        'donde no había contenedores.\n\n'
        'Con esa información pidieron apoyo a la municipalidad,\n'
        'instalaron letreros y organizaron jornadas con las familias.\n'
        'Al final del semestre el cerro seguía teniendo visitantes,\n'
        'pero había menos basura y más personas dispuestas a cuidarlo.\n'
        'La brigada entendió que observar con atención\n'
        'puede ser el primer paso para cambiar un problema real.',
  ),
  (
    nivel: '6',
    titulo: 'El viaje de la quínoa',
    texto:
        'La quínoa es una semilla cultivada desde hace siglos\n'
        'en distintas zonas de los Andes.\n'
        'Aunque durante mucho tiempo se consumió sobre todo en comunidades rurales,\n'
        'hoy se conoce en muchos países.\n\n'
        'Su resistencia a climas extremos la hace especial.\n'
        'Puede crecer en suelos salinos, soportar noches frías\n'
        'y desarrollarse con menos agua que otros cultivos.\n'
        'Eso ha despertado el interés de investigadores y agricultores.\n\n'
        'Además, la quínoa contiene proteínas, fibra y minerales.\n'
        'Por esa razón aparece en recetas dulces y saladas:\n'
        'ensaladas, guisos, hamburguesas vegetales\n'
        'e incluso panes mezclados con otras harinas.\n\n'
        'Sin embargo, su valor no depende sólo de la nutrición.\n'
        'También representa conocimientos agrícolas transmitidos\n'
        'de generación en generación.\n'
        'Cuando una semilla viaja desde un cultivo local\n'
        'hasta una mesa lejana, lleva consigo clima, historia y trabajo humano.',
  ),

  // 7° básico
  (
    nivel: '7',
    titulo: 'Cuando la ciudad escucha',
    texto:
        'Un grupo de estudiantes decidió investigar cómo cambia el sonido\n'
        'en distintos puntos de su ciudad.\n'
        'No querían limitarse a decir que algunos lugares eran ruidosos\n'
        'y otros tranquilos; buscaban medir, comparar y comprender.\n\n'
        'Durante dos semanas recorrieron ferias, plazas, avenidas y pasajes.\n'
        'En cada sitio anotaron la hora, el clima,\n'
        'la cantidad de personas y el tipo de actividad predominante.\n'
        'También grabaron fragmentos breves para reconocer patrones.\n\n'
        'Los resultados fueron más complejos de lo esperado.\n'
        'La feria tenía un nivel alto de ruido,\n'
        'pero la mayoría lo asociaba a un ambiente activo y seguro.\n'
        'En cambio, una avenida con tráfico constante\n'
        'generaba cansancio porque el sonido era uniforme y persistente.\n\n'
        'El estudio concluyó que no todo volumen molesto se explica sólo por decibeles.\n'
        'Influyen también la duración, la diversidad de sonidos\n'
        'y la posibilidad de anticiparlos.\n\n'
        'Comprender esa diferencia ayudó al curso a pensar la ciudad\n'
        'como un espacio que no sólo se mira,\n'
        'sino que también se escucha.\n'
        'Y escuchar con atención puede cambiar la manera en que habitamos un lugar.',
  ),
  (
    nivel: '7',
    titulo: 'La bitácora del canal',
    texto:
        'A fines del siglo diecinueve, varios pueblos del norte chileno\n'
        'dependían de canales para conducir agua hacia zonas de cultivo.\n'
        'Uno de esos canales quedó registrado en la bitácora de un capataz\n'
        'que anotaba avances, problemas y acuerdos con las comunidades cercanas.\n\n'
        'En sus páginas no sólo aparecían medidas y materiales.\n'
        'También se describían derrumbes, jornadas suspendidas por tormenta\n'
        'y discusiones sobre cómo repartir el agua en épocas secas.\n'
        'La bitácora mostraba que una obra de ingeniería\n'
        'nunca es solamente técnica.\n\n'
        'Construir el canal exigió calcular pendientes,\n'
        'mover piedras enormes y reforzar taludes.\n'
        'Pero además fue necesario negociar horarios de trabajo,\n'
        'resolver conflictos y coordinar a personas con oficios distintos.\n\n'
        'Décadas después, historiadores encontraron ese cuaderno\n'
        'en un archivo municipal.\n'
        'Gracias a él pudieron reconstruir no sólo el trazado del canal,\n'
        'sino también la vida cotidiana de quienes lo hicieron posible.\n\n'
        'A veces un documento pequeño conserva información enorme.\n'
        'No porque diga todo, sino porque permite unir detalles\n'
        'que, juntos, devuelven la forma de una época.',
  ),
  (
    nivel: '7',
    titulo: 'La discusión del huerto',
    texto:
        'En la escuela de Antonia existía un huerto cuidado por distintos cursos.\n'
        'Cuando llegó el invierno, surgió una discusión inesperada.\n'
        'Algunos querían usar el espacio libre para plantar sólo verduras rápidas,\n'
        'como lechugas y rabanitos.\n'
        'Otros proponían reservar una parte para hierbas y flores nativas.\n\n'
        'El primer grupo argumentaba que el huerto debía producir alimentos\n'
        'para la cocina del establecimiento.\n'
        'El segundo respondía que la diversidad atraía insectos polinizadores\n'
        'y mejoraba el suelo a largo plazo.\n'
        'Ambas posturas parecían razonables.\n\n'
        'En vez de votar de inmediato, la profesora pidió reunir evidencia.\n'
        'Cada equipo investigó, entrevistó a un agricultor de la zona\n'
        'y observó el comportamiento del huerto durante varias semanas.\n\n'
        'Finalmente acordaron una solución intermedia:\n'
        'destinar canteros distintos a objetivos complementarios.\n'
        'Así pudieron cosechar alimentos y, al mismo tiempo,\n'
        'fortalecer el equilibrio del espacio.\n\n'
        'La experiencia enseñó algo más valioso que una respuesta única.\n'
        'Mostró que discutir con argumentos, datos y disposición a escuchar\n'
        'puede conducir a decisiones mejores que la simple improvisación.',
  ),

  // 8° básico
  (
    nivel: '8',
    titulo: 'El archivo bajo la lluvia',
    texto:
        'La lluvia comenzó justo cuando Emilia entró al antiguo edificio municipal.\n'
        'Había ido a entrevistar a la encargada del archivo histórico\n'
        'para un trabajo escolar sobre la memoria local.\n'
        'Imaginaba filas de papeles amarillentos y silencio absoluto,\n'
        'pero encontró un lugar mucho más vivo de lo esperado.\n\n'
        'La archivista le explicó que conservar documentos\n'
        'no consiste sólo en guardarlos dentro de cajas.\n'
        'Primero hay que limpiarlos, identificar su origen,\n'
        'registrar fechas y revisar si existen copias.\n'
        'Luego se controlan la humedad, la luz y la temperatura,\n'
        'porque cualquier descuido puede borrar información irrepetible.\n\n'
        'Mientras hablaban, Emilia observó planos de calles antiguas,\n'
        'actas de sesiones vecinales y cartas enviadas durante inundaciones.\n'
        'Comprendió que la historia de una ciudad\n'
        'no vive sólo en monumentos o fechas célebres.\n'
        'También permanece en registros cotidianos\n'
        'que revelan cómo las personas resolvían problemas comunes.\n\n'
        'Cuando salió del edificio, la lluvia seguía cayendo.\n'
        'Sin embargo, ahora le parecía distinta.\n'
        'Pensó que, si ese día quedaba anotado en algún informe municipal,\n'
        'algún lector futuro podría usarlo para entender otra época.\n'
        'Esa idea convirtió una tarde gris en una pregunta sobre el tiempo.',
  ),
  (
    nivel: '8',
    titulo: 'Energía para el invierno',
    texto:
        'Cada invierno aumenta el consumo energético en muchas ciudades del sur.\n'
        'La calefacción se vuelve indispensable,\n'
        'pero no todas las viviendas conservan el calor de la misma manera.\n'
        'Cuando una casa pierde temperatura con rapidez,\n'
        'sus habitantes necesitan gastar más combustible o electricidad\n'
        'para mantener una sensación térmica aceptable.\n\n'
        'Por eso varios municipios han impulsado programas de mejoramiento térmico.\n'
        'Estas iniciativas incluyen sellado de filtraciones,\n'
        'aislamiento en techumbres y reemplazo de ventanas simples\n'
        'por sistemas más eficientes.\n'
        'El objetivo no es sólo ahorrar dinero,\n'
        'sino también reducir emisiones contaminantes.\n\n'
        'A veces se piensa que la solución depende exclusivamente\n'
        'de tecnologías complejas o costosas.\n'
        'Sin embargo, estudios recientes muestran que medidas básicas,\n'
        'bien aplicadas, producen mejoras significativas.\n'
        'Cerrar filtraciones o instalar cortinas adecuadas\n'
        'puede modificar bastante el comportamiento térmico de un hogar.\n\n'
        'Discutir sobre energía, entonces, no significa hablar sólo de centrales o tarifas.\n'
        'También implica pensar en diseño urbano, salud respiratoria\n'
        'y calidad de vida cotidiana.\n'
        'Esa mirada amplia permite entender por qué una decisión doméstica\n'
        'puede tener efectos colectivos.',
  ),
  (
    nivel: '8',
    titulo: 'La última entrevista',
    texto:
        'El periodista escolar llegó temprano al taller de don Esteban,\n'
        'un inventor aficionado conocido por reparar objetos\n'
        'que casi todos daban por perdidos.\n'
        'Sobre una mesa había radios abiertas, relojes antiguos\n'
        'y piezas de metal ordenadas con precisión.\n\n'
        'La entrevista comenzó con una pregunta simple:\n'
        'por qué seguía arreglando aparatos en lugar de reemplazarlos.\n'
        'Don Esteban respondió que reparar era una forma de pensar.\n'
        'Obligaba a observar con detalle, probar hipótesis\n'
        'y aceptar que una falla visible no siempre es la causa real del problema.\n\n'
        'Luego contó que, cuando era joven,\n'
        'aprendió electricidad leyendo manuales prestados\n'
        'y desarmando equipos en desuso.\n'
        'No siempre lograba recomponerlos,\n'
        'pero cada intento le enseñaba algo sobre materiales, circuitos y paciencia.\n\n'
        'Antes de despedirse, el periodista le preguntó\n'
        'qué consejo daría a quienes quieren crear cosas nuevas.\n'
        'Don Esteban miró una radio a medio armar y dijo:\n'
        '"Primero aprendan a escuchar cómo fallan las cosas.\n'
        'A veces una invención nace justamente ahí,\n'
        'en el punto donde alguien decide no rendirse ante una avería."\n\n'
        'Esa frase terminó siendo el título de la entrevista\n'
        'y también la idea que más tiempo quedó resonando en el taller.',
  ),
];

Future<void> seedReadingTexts(AppDatabase db) async {
  final existing = await db.select(db.readingTexts).get();
  final existingByKey = {
    for (final text in existing) _textKey(text.nivel, text.titulo): text,
  };

  await db.transaction(() async {
    for (final t in _textos) {
      final key = _textKey(t.nivel, t.titulo);
      final words = _countWords(t.texto);
      final current = existingByKey[key];

      if (current == null) {
        await db
            .into(db.readingTexts)
            .insert(
              ReadingTextsCompanion.insert(
                nivel: t.nivel,
                titulo: t.titulo,
                contenido: t.texto,
                totalPalabras: words,
              ),
            );
        continue;
      }

      if (current.contenido != t.texto || current.totalPalabras != words) {
        await (db.update(
          db.readingTexts,
        )..where((row) => row.id.equals(current.id))).write(
          ReadingTextsCompanion(
            contenido: Value(t.texto),
            totalPalabras: Value(words),
          ),
        );
      }
    }
  });
}

String _textKey(String nivel, String titulo) => '$nivel::$titulo';

int _countWords(String text) => RegExp(r'\S+').allMatches(text).length;
