# Documentacion de la libreria `cartesian_plane`

Este documento describe los componentes principales de la libreria y como se usan. Esta pensado como referencia externa para README o wiki, manteniendo el codigo limpio.

## 1) Archivo: `cartesianPlane.dart`

Archivo de exportacion principal. Importa este archivo para acceder a todas las clases y funciones necesarias para renderizar y controlar el plano cartesiano.

## 2) Archivo: `cartesianCanvasWidget.dart`

### Clase `CartesianCanvas`

Widget principal que se inserta en el arbol de Flutter. Renderiza el plano, maneja gestos del usuario (paneo, zoom, toques) y administra el estado de dibujo.

**Propiedades principales**

- `items` (`List<CartesianItem>`): lista de elementos matematicos o graficos dibujados directamente sobre el lienzo.
- `widgetItems` (`List<WidgetItem>`): widgets nativos de Flutter posicionados sobre el plano usando coordenadas del mundo.
- `theme` (`CartesianCanvasTheme`): colores, grosores de linea y estilos visuales del plano.
- `controller` (`CartesianCanvasController`): opcional, permite manipular la vista desde eventos externos.
- `showControls` (`bool`): muestra u oculta la barra de herramientas flotante.
- `showLegend` (`bool`): muestra u oculta la leyenda generada por series y funciones.
- `title` (`String?`): titulo opcional en la esquina superior izquierda.
- `initialScale` (`double`): nivel de acercamiento inicial (pixeles por unidad matematica).
- `enableFreehandDrawing` (`bool`): habilita el modo de dibujo a mano alzada.

## 3) Archivo: `cartesianCanvasController.dart`

### Clase `CartesianCanvasController`

Control programatico sobre un `CartesianCanvas`. Instancialo y pasalo al widget mediante la propiedad `controller`.

**Metodos disponibles**

- `resetView()`: vuelve a la escala y posicion inicial (0,0).
- `zoomIn()`: aumenta la escala actual.
- `zoomOut()`: reduce la escala actual.
- `fitToContent()`: ajusta el encuadre para mostrar todos los elementos.
- `goToPoint(double x, double y)`: centra la camara en las coordenadas dadas.
- `captureImage()`: retorna un `ui.Image` con la captura actual del plano.
- `clearFreehand()`: elimina trazos del modo de dibujo libre.

## 4) Archivo: `cartesianItem.dart`

Define los objetos renderizables dentro del lienzo. Todas las clases heredan de `CartesianItem`.

### Clase `PointItem`

Dibuja un punto unico en el espacio.

- `x`, `y`: coordenadas logicas.
- `color`: color del circulo.
- `radius`: tamano del punto en pixeles.
- `label`: texto opcional asociado.

### Clase `SeriesItem`

Renderiza una coleccion de puntos (`SeriesPoint`), con opcion de unirlos por lineas.

- `name`: nombre de la serie (aparece en la leyenda).
- `points`: lista de datos a renderizar.
- `connectPoints`: si es `true`, traza una linea continua entre puntos.
- `showPoints`: si es `true`, dibuja cada punto individual.

### Clase `FunctionItem`

Evalua y dibuja una expresion matematica (por ejemplo `x^2 - 4` o `sin(x)`) a lo largo del ancho visible.

- `equation`: cadena con la ecuacion a parsear.
- `color`: color del trazo.
- `name`: identificador opcional para la leyenda.

### Clase `SegmentItem`

Dibuja una linea recta entre dos puntos.

- `x1`, `y1`: coordenadas de inicio.
- `x2`, `y2`: coordenadas de finalizacion.
- `arrow`: agrega punta de flecha direccional.
- `dashPattern`: lista de valores para linea discontinua (ej. `[6, 4]`).

### Clase `PolygonItem`

Genera una figura cerrada con multiples vertices.

- `vertices`: lista de tuplas `(double, double)` que definen el poligono.
- `fillColor`: color interno (soporta opacidad).
- `strokeColor`: color del contorno.

### Clase `TextItem`

Coloca una cadena de texto anclada a una coordenada matematica.

### Clase `ImageItem`

Incrusta una imagen `ui.Image` escalada segun unidades del mundo.

### Clase `WidgetItem` (independiente)

No hereda de `CartesianItem` porque se renderiza en una capa superior (`Stack`) con widgets nativos de Flutter. Permite botones, contenedores interactivos o animaciones ancladas a coordenadas logicas `(x, y)`.

## 5) Archivo: `cartesianCanvasTheme.dart`

### Clase `CartesianCanvasTheme`

Centraliza la configuracion estetica. Incluye dos constructores listos para usar: `CartesianCanvasTheme.light` y `CartesianCanvasTheme.dark`.

**Atributos de personalizacion**

- `background`: color de fondo.
- `axisColor` / `axisWidth`: apariencia de ejes X e Y.
- `gridColor` / `gridWidth`: apariencia de la cuadricula secundaria.
- `labelColor` / `labelFontSize`: estilo tipografico de los numeros.
- `originDotColor`: color del punto que marca el origen (0,0).
- `tooltipBackground` / `tooltipTextColor`: colores del tooltip al tocar un punto.

## 6) Eventos y callbacks

Estos callbacks permiten integrar interacciones del usuario con tu logica.

- `onTap(double x, double y)`: se dispara al tocar el plano; entrega coordenadas del mundo.
- `onLongPress(double x, double y)`: se dispara al mantener presionado; entrega coordenadas del mundo.
- `onFreehandStroke(List<Offset> worldPoints)`: se dispara al finalizar un trazo en modo dibujo libre; entrega la lista de puntos en coordenadas del mundo.

Propiedades relacionadas con el modo libre:

- `enableFreehandDrawing`: habilita o deshabilita el modo dibujo.
- `freehandColor`: color del trazo libre.
- `freehandWidth`: grosor del trazo libre.

## 7) Detalles internos (render y gestos)

Notas clave de funcionamiento para entender el comportamiento del widget:

- **Transformaciones:** el plano mantiene un `currentOrigin` (origen de pantalla) y `currentScale` (pixeles por unidad). Las conversiones se realizan con `transformWorldToScreen()` y `transformScreenToWorld()`.
- **Gestos:** el zoom y paneo usan `GestureDetector` con `onScaleStart/Update/End`. El zoom se aplica respecto al punto focal.
- **Dibujo libre:** al activar el modo, los trazos se guardan como `FreehandItem` y se pintan en la misma capa del lienzo.
- **Tooltips:** se detecta cercania a puntos/series al mover el mouse o hacer tap y se muestra un tooltip con `x` e `y`.
- **Leyenda:** se genera automaticamente con `SeriesItem` y `FunctionItem` que tengan `name`.
- **Cuadricula adaptativa:** el paso de la cuadricula se ajusta segun la escala para mantener una densidad legible.

## 8) Guia de integracion

Recomendaciones para uso en apps reales:

- Usa `CartesianCanvasController` cuando necesites botones externos para `zoomIn()`, `zoomOut()`, `fitToContent()` o `captureImage()`.
- Para datos dinamicos, actualiza `items` y llama a `setState()` en tu widget padre.
- Si necesitas mantener el estado de zoom entre pantallas, guarda `initialScale` y controla el encuadre con `goToPoint()` al reabrir.
- Evita pasar listas muy grandes sin paginar o simplificar; para miles de puntos considera decimacion previa.

## 9) Ejemplos avanzados

### 9.1) Callbacks de toque y presion

```dart
CartesianCanvas(
	onTap: (x, y) {
		debugPrint('Tap en: $x, $y');
	},
	onLongPress: (x, y) {
		debugPrint('Long press en: $x, $y');
	},
)
```

### 9.2) Dibujo libre y captura de trazos

```dart
CartesianCanvas(
	enableFreehandDrawing: true,
	freehandColor: Colors.deepPurple,
	freehandWidth: 3,
	onFreehandStroke: (worldPoints) {
		debugPrint('Puntos del trazo: ${worldPoints.length}');
	},
)
```

### 9.3) Serie desde mapas

```dart
final rows = [
	{'x': 0, 'y': 1},
	{'x': 1, 'y': 2},
	{'x': 2, 'y': 1.5},
];

final serie = SeriesItem.fromMaps(
	rows,
	name: 'Muestras',
	color: Colors.teal,
	connectPoints: true,
);

CartesianCanvas(items: [serie]);
```

### 9.4) Captura de imagen y guardado

```dart
final controller = CartesianCanvasController();

Future<void> saveCapture() async {
	final image = await controller.captureImage();
	if (image == null) return;
	// Convierte a PNG con ui.ImageByteFormat.png y guardalo en disco.
}

CartesianCanvas(controller: controller);
```

## Ejemplo de uso basico

```dart
final controller = CartesianCanvasController();

CartesianCanvas(
	controller: controller,
	title: 'Plano cartesiano',
	initialScale: 40,
	theme: CartesianCanvasTheme.light,
	items: [
		PointItem(x: 0, y: 0, color: Colors.red, radius: 4),
		SegmentItem(x1: -2, y1: -1, x2: 3, y2: 2, arrow: true),
		FunctionItem(equation: 'sin(x)', color: Colors.blue, name: 'seno'),
	],
	widgetItems: [
		WidgetItem(
			x: 1,
			y: 1,
			child: ElevatedButton(onPressed: () {}, child: const Text('Hola')),
		),
	],
);
```

---


