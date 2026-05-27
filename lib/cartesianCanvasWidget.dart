import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'cartesianItem.dart';
import 'cartesianCanvasTheme.dart';
import 'cartesianCanvasController.dart';

class CartesianCanvas extends StatefulWidget {
  final List<CartesianItem> items;
  final List<WidgetItem> widgetItems;
  final CartesianCanvasTheme theme;
  final CartesianCanvasController? controller;
  final bool showControls;
  final bool showLegend;
  final String? title;
  final double initialScale;
  final bool initialShowGrid;
  final bool enableFreehandDrawing;
  final Color freehandColor;
  final double freehandWidth;
  final bool isFullScreen;
  final void Function(List<Offset> worldPoints)? onFreehandStroke;
  final void Function(double x, double y)? onTap;
  final void Function(double x, double y)? onLongPress;

  const CartesianCanvas({
    super.key,
    this.items = const [],
    this.widgetItems = const [],
    this.theme = CartesianCanvasTheme.light,
    this.controller,
    this.showControls = true,
    this.showLegend = true,
    this.title,
    this.initialScale = 1.0,
    this.initialShowGrid = true,
    this.enableFreehandDrawing = false,
    this.freehandColor = Colors.black,
    this.freehandWidth = 2.0,
    this.isFullScreen = false,
    this.onFreehandStroke,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<CartesianCanvas> createState() => CartesianCanvasState();
}

class CartesianCanvasState extends State<CartesianCanvas> implements CartesianCanvasDelegate {
  Offset currentOrigin = Offset.zero;
  double currentScale = 60.0;
  bool isInitialized = false;
  Offset? previousFocalPoint;
  double? previousScaleGesture;
  TooltipData? activeTooltip;
  List<Offset>? activeStroke;
  bool isDrawingModeActive = false;
  bool isGridVisible = true;
  final List<FreehandItem> recordedStrokes = [];
  final GlobalKey boundaryRepaintKey = GlobalKey();

  @override
  bool get drawingMode => isDrawingModeActive;

  @override
  void setDrawingMode(bool isEnabled) {
    setState(() => isDrawingModeActive = isEnabled);
  }

  @override
  bool get gridVisible => isGridVisible;

  @override
  void setGridVisible(bool isVisible) {
    setState(() => isGridVisible = isVisible);
  }

  @override
  void clearFreehand() {
    setState(() => recordedStrokes.clear());
  }

  @override
  void initState() {
    super.initState();
    final initialScaleFactor = widget.initialScale <= 0 ? 1.0 : widget.initialScale;
    currentScale = initialScaleFactor * 60.0;
    isDrawingModeActive = widget.enableFreehandDrawing;
    isGridVisible = widget.initialShowGrid;
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(CartesianCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(this);
    }
    if (oldWidget.enableFreehandDrawing != widget.enableFreehandDrawing) {
      isDrawingModeActive = widget.enableFreehandDrawing;
    }
    if (oldWidget.initialScale != widget.initialScale) {
      final initialScaleFactor = widget.initialScale <= 0 ? 1.0 : widget.initialScale;
      setState(() {
        currentScale = initialScaleFactor * 60.0;
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  Offset transformWorldToScreen(double x, double y) => Offset(currentOrigin.dx + x * currentScale, currentOrigin.dy - y * currentScale);

  Offset transformScreenToWorld(double px, double py) => Offset((px - currentOrigin.dx) / currentScale, (currentOrigin.dy - py) / currentScale);

  @override
  void resetView() {
    if (!mounted) return;
    final canvasSize = context.size;
    if (canvasSize == null) return;
    final initialScaleFactor = widget.initialScale <= 0 ? 1.0 : widget.initialScale;
    setState(() {
      currentOrigin = Offset(canvasSize.width / 2, canvasSize.height / 2);
      currentScale = initialScaleFactor * 60.0;
    });
  }

  @override
  void zoomFromCenter(double zoomFactor) {
    if (!mounted) return;
    final canvasSize = context.size;
    if (canvasSize == null) return;
    applyZoomAtPoint(Offset(canvasSize.width / 2, canvasSize.height / 2), zoomFactor);
  }

  @override
  void goToPoint(double x, double y) {
    if (!mounted) return;
    final canvasSize = context.size;
    if (canvasSize == null) return;
    setState(() {
      currentOrigin = Offset(canvasSize.width / 2 - x * currentScale, canvasSize.height / 2 + y * currentScale);
    });
  }

  @override
  void fitToContent() {
    if (!mounted) return;
    final canvasSize = context.size;
    if (canvasSize == null) return;

    final boundaryPoints = <Offset>[];
    for (final item in widget.items) {
      if (item is SeriesItem) {
        for (final p in item.points) {
          boundaryPoints.add(Offset(p.x, p.y));
        }
      } else if (item is PointItem) {
        boundaryPoints.add(Offset(item.x, item.y));
      } else if (item is PolygonItem) {
        for (final v in item.vertices) {
          boundaryPoints.add(Offset(v.$1, v.$2));
        }
      }
    }
    for (final widgetItem in widget.widgetItems) {
      boundaryPoints.add(Offset(widgetItem.x, widgetItem.y));
    }

    if (boundaryPoints.isEmpty) {
      resetView();
      return;
    }

    final xValues = boundaryPoints.map((p) => p.dx);
    final yValues = boundaryPoints.map((p) => p.dy);
    final minimumX = xValues.reduce(min);
    final maximumX = xValues.reduce(max);
    final minimumY = yValues.reduce(min);
    final maximumY = yValues.reduce(max);

    final rangeX = maximumX - minimumX;
    final rangeY = maximumY - minimumY;
    const marginRatio = 0.18;

    final computedScaleX = rangeX > 1e-10 ? (canvasSize.width * (1 - 2 * marginRatio)) / rangeX : double.infinity;
    final computedScaleY = rangeY > 1e-10 ? (canvasSize.height * (1 - 2 * marginRatio)) / rangeY : double.infinity;

    final calculatedNewScale = min(computedScaleX, computedScaleY).clamp(1.0, 2000.0);
    final centerX = (minimumX + maximumX) / 2;
    final centerY = (minimumY + maximumY) / 2;

    setState(() {
      currentScale = calculatedNewScale;
      currentOrigin = Offset(canvasSize.width / 2 - centerX * calculatedNewScale, canvasSize.height / 2 + centerY * calculatedNewScale);
    });
  }

  @override
  Future<ui.Image?> captureImage() async {
    try {
      final imageBoundary = boundaryRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (imageBoundary == null) return null;
      return imageBoundary.toImage(pixelRatio: 2.0);
    } catch (_) {
      return null;
    }
  }

  void applyZoomAtPoint(Offset focalPoint, double zoomFactor) {
    setState(() {
      currentOrigin = focalPoint + (currentOrigin - focalPoint) * zoomFactor;
      currentScale = (currentScale * zoomFactor).clamp(1.0, 3000.0);
    });
  }

  void toggleFullScreen() {
    if (widget.isFullScreen) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: CartesianCanvas(
                items: widget.items,
                widgetItems: widget.widgetItems,
                theme: widget.theme,
                controller: widget.controller,
                showControls: widget.showControls,
                showLegend: widget.showLegend,
                title: widget.title,
                initialScale: currentScale / 60.0,
                initialShowGrid: isGridVisible,
                enableFreehandDrawing: isDrawingModeActive,
                freehandColor: widget.freehandColor,
                freehandWidth: widget.freehandWidth,
                isFullScreen: true,
                onFreehandStroke: widget.onFreehandStroke,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
              ),
            ),
          ),
        ),
      );
    }
  }

  void detectTooltipIntersection(Offset screenCoordinates) {
    const intersectionThreshold = 20.0;
    for (final item in widget.items) {
      if (item is SeriesItem) {
        for (final dataPoint in item.points) {
          final mappedScreenPoint = transformWorldToScreen(dataPoint.x, dataPoint.y);
          if ((mappedScreenPoint - screenCoordinates).distance < intersectionThreshold) {
            setState(() {
              activeTooltip = TooltipData(
                screenPosition: screenCoordinates,
                x: dataPoint.x,
                y: dataPoint.y,
                label: dataPoint.label,
                color: dataPoint.color ?? item.color,
              );
            });
            return;
          }
        }
      } else if (item is PointItem) {
        final mappedScreenPoint = transformWorldToScreen(item.x, item.y);
        if ((mappedScreenPoint - screenCoordinates).distance < intersectionThreshold) {
          setState(() {
            activeTooltip = TooltipData(
              screenPosition: screenCoordinates,
              x: item.x,
              y: item.y,
              label: item.label,
              color: item.color,
            );
          });
          return;
        }
      }
    }
    if (activeTooltip != null) setState(() => activeTooltip = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (layoutContext, constraints) {
      final availableSize = Size(constraints.maxWidth, constraints.maxHeight);

      if (!isInitialized) {
        currentOrigin = Offset(availableSize.width / 2, availableSize.height / 2);
        isInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final containsVisualPoints = widget.items.any((i) => i is SeriesItem || i is PointItem || i is PolygonItem);
          final initialScaleFactor = widget.initialScale <= 0 ? 1.0 : widget.initialScale;
          if (containsVisualPoints && initialScaleFactor == 1.0) {
            fitToContent();
          } else {
            setState(() {
              currentScale = initialScaleFactor * 60.0;
            });
          }
        });
      }

      return Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.axisColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular((widget.title != null || widget.isFullScreen) ? 0 : 12),
                  child: renderCanvasLayer(availableSize),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget renderCanvasLayer(Size availableSize) {
    return RepaintBoundary(
      key: boundaryRepaintKey,
      child: Container(
        color: widget.theme.background,
        child: Listener(
          onPointerSignal: (pointerEvent) {
            if (pointerEvent is PointerScrollEvent) {
              applyZoomAtPoint(pointerEvent.localPosition, pointerEvent.scrollDelta.dy < 0 ? 1.15 : 0.87);
            }
          },
          onPointerHover: (pointerEvent) => detectTooltipIntersection(pointerEvent.localPosition),
          child: GestureDetector(
            onScaleStart: (gestureDetails) {
              if (isDrawingModeActive && gestureDetails.pointerCount == 1) {
                final worldCoordinates = transformScreenToWorld(gestureDetails.localFocalPoint.dx, gestureDetails.localFocalPoint.dy);
                setState(() => activeStroke = [worldCoordinates]);
              } else {
                previousFocalPoint = gestureDetails.localFocalPoint;
                previousScaleGesture = 1.0;
              }
            },
            onScaleUpdate: (gestureDetails) {
              if (isDrawingModeActive && gestureDetails.pointerCount == 1 && activeStroke != null) {
                final worldCoordinates = transformScreenToWorld(gestureDetails.localFocalPoint.dx, gestureDetails.localFocalPoint.dy);
                setState(() => activeStroke = [...activeStroke!, worldCoordinates]);
              } else {
                setState(() {
                  if (gestureDetails.pointerCount >= 2 && previousScaleGesture != null) {
                    final dynamicFactor = gestureDetails.scale / previousScaleGesture!;
                    currentOrigin = gestureDetails.localFocalPoint + (currentOrigin - gestureDetails.localFocalPoint) * dynamicFactor;
                    currentScale = (currentScale * dynamicFactor).clamp(1.0, 3000.0);
                    previousScaleGesture = gestureDetails.scale;
                  } else if (previousFocalPoint != null) {
                    currentOrigin += gestureDetails.localFocalPoint - previousFocalPoint!;
                  }
                  previousFocalPoint = gestureDetails.localFocalPoint;
                });
              }
            },
            onScaleEnd: (gestureDetails) {
              if (isDrawingModeActive && activeStroke != null && activeStroke!.length > 1) {
                final finalizedStroke = FreehandItem(
                  worldPoints: List.from(activeStroke!),
                  color: widget.freehandColor,
                  strokeWidth: widget.freehandWidth,
                );
                setState(() {
                  recordedStrokes.add(finalizedStroke);
                });
                widget.onFreehandStroke?.call(List.from(activeStroke!));
              }
              setState(() => activeStroke = null);
              previousFocalPoint = null;
              previousScaleGesture = null;
            },
            onTapUp: (gestureDetails) {
              detectTooltipIntersection(gestureDetails.localPosition);
              if (widget.onTap != null) {
                final worldCoordinates = transformScreenToWorld(gestureDetails.localPosition.dx, gestureDetails.localPosition.dy);
                widget.onTap!(worldCoordinates.dx, worldCoordinates.dy);
              }
            },
            onLongPressStart: (gestureDetails) {
              if (widget.onLongPress != null) {
                final worldCoordinates = transformScreenToWorld(gestureDetails.localPosition.dx, gestureDetails.localPosition.dy);
                widget.onLongPress!(worldCoordinates.dx, worldCoordinates.dy);
              }
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: availableSize,
                  painter: CanvasRenderer(
                    origin: currentOrigin,
                    scale: currentScale,
                    items: widget.items,
                    freehandItems: recordedStrokes,
                    currentStroke: activeStroke,
                    showGrid: isGridVisible,
                    freehandColor: widget.freehandColor,
                    freehandWidth: widget.freehandWidth,
                    theme: widget.theme,
                    worldToScreen: transformWorldToScreen,
                    screenToWorld: transformScreenToWorld,
                  ),
                ),
                ...widget.widgetItems.map((widgetItem) {
                  final mappedScreenPoint = transformWorldToScreen(widgetItem.x, widgetItem.y);
                  return Positioned(
                    left: mappedScreenPoint.dx - 50 * (widgetItem.alignment.x + 1) / 2,
                    top: mappedScreenPoint.dy - 50 * (widgetItem.alignment.y + 1) / 2,
                    child: widgetItem.child,
                  );
                }),
                if (widget.showLegend) LegendWidget(items: widget.items, theme: widget.theme),
                if (activeTooltip != null) TooltipWidget(tooltipData: activeTooltip!, size: availableSize, theme: widget.theme),
                if (widget.showControls && widget.isFullScreen)
                  FloatingToolbar(
                    theme: widget.theme,
                    drawingMode: isDrawingModeActive,
                    gridVisible: isGridVisible,
                    isFullScreen: widget.isFullScreen,
                    onFitToContent: fitToContent,
                    onResetView: resetView,
                    onZoomIn: () => zoomFromCenter(1.3),
                    onZoomOut: () => zoomFromCenter(0.77),
                    onToggleGrid: () => setState(() => isGridVisible = !isGridVisible),
                    onToggleDrawing: () => setState(() => isDrawingModeActive = !isDrawingModeActive),
                    onClearFreehand: clearFreehand,
                    onToggleFullScreen: toggleFullScreen,
                  ),
                if (widget.showControls && activeTooltip != null && widget.isFullScreen)
                  FloatingCoordinates(tooltipData: activeTooltip!, theme: widget.theme),
                if (widget.showControls && !widget.isFullScreen)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.theme.background.withOpacity(0.75),
                            border: Border.all(color: widget.theme.axisColor.withOpacity(0.1), width: 1),
                          ),
                          child: ControlIconButton(
                            iconData: Icons.fullscreen_rounded,
                            tooltipText: 'Pantalla Completa',
                            onTapCallback: toggleFullScreen,
                            activeTheme: widget.theme,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CanvasRenderer extends CustomPainter {
  final Offset origin;
  final double scale;
  final List<CartesianItem> items;
  final List<FreehandItem> freehandItems;
  final List<Offset>? currentStroke;
  final bool showGrid;
  final Color freehandColor;
  final double freehandWidth;
  final CartesianCanvasTheme theme;
  final WorldToScreen worldToScreen;
  final ScreenToWorld screenToWorld;

  const CanvasRenderer({
    required this.origin,
    required this.scale,
    required this.items,
    required this.freehandItems,
    required this.currentStroke,
    required this.showGrid,
    required this.freehandColor,
    required this.freehandWidth,
    required this.theme,
    required this.worldToScreen,
    required this.screenToWorld,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      drawGridLines(canvas, size);
      drawAxisLabels(canvas, size);
      drawOriginDot(canvas);
    }

    for (final item in items) {
      item.paint(canvas, size, worldToScreen, screenToWorld, scale);
    }

    for (final stroke in freehandItems) {
      stroke.paint(canvas, size, worldToScreen, screenToWorld, scale);
    }

    if (currentStroke != null && currentStroke!.length > 1) {
      final activeStrokePaint = Paint()
        ..color = freehandColor
        ..strokeWidth = freehandWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final activePath = Path()
        ..moveTo(worldToScreen(currentStroke![0].dx, currentStroke![0].dy).dx, worldToScreen(currentStroke![0].dx, currentStroke![0].dy).dy);
      for (int i = 1; i < currentStroke!.length; i++) {
        final mappedScreenPoint = worldToScreen(currentStroke![i].dx, currentStroke![i].dy);
        activePath.lineTo(mappedScreenPoint.dx, mappedScreenPoint.dy);
      }
      canvas.drawPath(activePath, activeStrokePaint);
    }
  }

  void drawGridLines(Canvas canvas, Size size) {
    final adaptiveStep = calculateAdaptiveStep(scale);
    final gridLinePaint = Paint()
      ..strokeWidth = theme.gridWidth
      ..color = theme.gridColor;
    final primaryAxisPaint = Paint()
      ..strokeWidth = theme.axisWidth
      ..color = theme.axisColor;

    final startXBound = ((-origin.dx) / scale / adaptiveStep).floor() * adaptiveStep;
    final endXBound = ((size.width - origin.dx) / scale / adaptiveStep).ceil() * adaptiveStep;
    final startYBound = (-(size.height - origin.dy) / scale / adaptiveStep).floor() * adaptiveStep;
    final endYBound = (origin.dy / scale / adaptiveStep).ceil() * adaptiveStep;

    for (double xValue = startXBound; xValue <= endXBound + adaptiveStep; xValue += adaptiveStep) {
      final pixelX = origin.dx + xValue * scale;
      canvas.drawLine(Offset(pixelX, 0), Offset(pixelX, size.height), xValue.abs() < 1e-9 ? primaryAxisPaint : gridLinePaint);
    }
    for (double yValue = startYBound; yValue <= endYBound + adaptiveStep; yValue += adaptiveStep) {
      final pixelY = origin.dy - yValue * scale;
      canvas.drawLine(Offset(0, pixelY), Offset(size.width, pixelY), yValue.abs() < 1e-9 ? primaryAxisPaint : gridLinePaint);
    }
  }

  void drawAxisLabels(Canvas canvas, Size size) {
    final adaptiveStep = calculateAdaptiveStep(scale);
    final textConfiguration = TextStyle(fontSize: theme.labelFontSize, color: theme.labelColor, fontWeight: FontWeight.w500);
    final activeTextPainter = TextPainter(textDirection: TextDirection.ltr);

    final startXBound = ((-origin.dx) / scale / adaptiveStep).floor() * adaptiveStep;
    final endXBound = ((size.width - origin.dx) / scale / adaptiveStep).ceil() * adaptiveStep;
    final startYBound = (-(size.height - origin.dy) / scale / adaptiveStep).floor() * adaptiveStep;
    final endYBound = (origin.dy / scale / adaptiveStep).ceil() * adaptiveStep;

    for (double xValue = startXBound; xValue <= endXBound + adaptiveStep; xValue += adaptiveStep) {
      if (xValue.abs() < 1e-9) continue;
      final pixelX = origin.dx + xValue * scale;
      final labelYPosition = (origin.dy + 8).clamp(8.0, size.height - 20.0);
      renderTextSpan(canvas, activeTextPainter, formatNumber(xValue), Offset(pixelX, labelYPosition), textConfiguration, centerAlignment: true);
    }
    for (double yValue = startYBound; yValue <= endYBound + adaptiveStep; yValue += adaptiveStep) {
      if (yValue.abs() < 1e-9) continue;
      final pixelY = origin.dy - yValue * scale;
      final labelXPosition = (origin.dx - 8).clamp(8.0, size.width - 8.0);
      renderTextSpan(canvas, activeTextPainter, formatNumber(yValue), Offset(labelXPosition, pixelY), textConfiguration, rightAlignment: true);
    }
    
    final axisLabelStyle = textConfiguration.copyWith(fontWeight: FontWeight.w700, color: theme.axisColor);
    renderTextSpan(canvas, activeTextPainter, 'X', Offset(size.width - 16, (origin.dy - 20).clamp(4.0, size.height - 20.0)), axisLabelStyle);
    renderTextSpan(canvas, activeTextPainter, 'Y', Offset((origin.dx + 12).clamp(4.0, size.width - 16.0), 12), axisLabelStyle);
    renderTextSpan(canvas, activeTextPainter, '0', Offset(origin.dx - 8, origin.dy + 8), textConfiguration, rightAlignment: true);
  }

  void drawOriginDot(Canvas canvas) {
    canvas.drawCircle(origin, 4.5, Paint()..color = theme.originDotColor);
    canvas.drawCircle(origin, 4.5, Paint()..color = theme.background..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  double calculateAdaptiveStep(double currentScaleValue) {
    final rawStep = 80 / currentScaleValue;
    final magnitude = pow(10, (log(rawStep) / ln10).floor()).toDouble();
    final remainder = rawStep / magnitude;
    if (remainder < 1.5) return magnitude;
    if (remainder < 3.5) return 2 * magnitude;
    if (remainder < 7.5) return 5 * magnitude;
    return 10 * magnitude;
  }

  String formatNumber(double numericValue) {
    if (numericValue == numericValue.truncateToDouble()) return numericValue.toInt().toString();
    if (numericValue.abs() < 0.01 || numericValue.abs() >= 10000) return numericValue.toStringAsExponential(1);
    return numericValue.toStringAsFixed(2);
  }

  void renderTextSpan(Canvas canvas, TextPainter painter, String textualContent, Offset pos, TextStyle style, {bool centerAlignment = false, bool rightAlignment = false}) {
    painter.text = TextSpan(text: textualContent, style: style);
    painter.layout();
    final offsetX = rightAlignment ? -painter.width : (centerAlignment ? -painter.width / 2 : 0.0);
    painter.paint(canvas, pos + Offset(offsetX, -painter.height / 2));
  }

  @override
  bool shouldRepaint(CanvasRenderer oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.scale != scale ||
      oldDelegate.items != items ||
      oldDelegate.freehandItems.length != freehandItems.length ||
      oldDelegate.currentStroke != currentStroke ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.theme != theme;
}

class TooltipData {
  final Offset screenPosition;
  final double x, y;
  final String? label;
  final Color color;
  const TooltipData({required this.screenPosition, required this.x, required this.y, this.label, required this.color});
}

class LegendWidget extends StatelessWidget {
  final List<CartesianItem> items;
  final CartesianCanvasTheme theme;

  const LegendWidget({required this.items, required this.theme});

  @override
  Widget build(BuildContext context) {
    final seriesItemsCollection = items.whereType<SeriesItem>().toList();
    final functionItemsCollection = items.whereType<FunctionItem>().toList();

    if (seriesItemsCollection.isEmpty && functionItemsCollection.every((f) => f.name == null)) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.background.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.axisColor.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in seriesItemsCollection) LegendRow(color: s.color, name: s.name, isLine: s.connectPoints, theme: theme),
                for (final f in functionItemsCollection.where((f) => f.name != null)) LegendRow(color: f.color, name: f.name!, isLine: true, theme: theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TooltipWidget extends StatelessWidget {
  final TooltipData tooltipData;
  final Size size;
  final CartesianCanvasTheme theme;

  const TooltipWidget({required this.tooltipData, required this.size, required this.theme});

  @override
  Widget build(BuildContext context) {
    const tooltipWidth = 180.0;
    const tooltipHeight = 60.0;
    const boundaryMargin = 16.0;

    double positionLeft = tooltipData.screenPosition.dx + 16;
    double positionTop = tooltipData.screenPosition.dy - tooltipHeight - 12;
    if (positionLeft + tooltipWidth > size.width - boundaryMargin) positionLeft = tooltipData.screenPosition.dx - tooltipWidth - 16;
    if (positionTop < boundaryMargin) positionTop = tooltipData.screenPosition.dy + 16;

    final tooltipLabel = tooltipData.label ?? 'X: ${tooltipData.x.toStringAsFixed(4)}\nY: ${tooltipData.y.toStringAsFixed(4)}';

    return Positioned(
      left: positionLeft,
      top: positionTop,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: tooltipWidth),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.tooltipBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 10),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: tooltipData.color, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(
                    tooltipLabel,
                    style: TextStyle(fontSize: 12, color: theme.tooltipTextColor, fontFamily: 'monospace', fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingToolbar extends StatelessWidget {
  final CartesianCanvasTheme theme;
  final bool drawingMode;
  final bool gridVisible;
  final bool isFullScreen;
  final VoidCallback onFitToContent;
  final VoidCallback onResetView;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleDrawing;
  final VoidCallback onClearFreehand;
  final VoidCallback onToggleFullScreen;

  const FloatingToolbar({
    required this.theme,
    required this.drawingMode,
    required this.gridVisible,
    required this.isFullScreen,
    required this.onFitToContent,
    required this.onResetView,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleGrid,
    required this.onToggleDrawing,
    required this.onClearFreehand,
    required this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.background.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.axisColor.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ControlIconButton(
                  iconData: isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  tooltipText: isFullScreen ? 'Salir de pantalla completa' : 'Pantalla completa',
                  onTapCallback: onToggleFullScreen,
                  activeTheme: theme,
                ),
                Container(
                  height: 1,
                  width: 24,
                  color: theme.axisColor.withOpacity(0.15),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                ),
                ControlIconButton(iconData: Icons.center_focus_strong_rounded, tooltipText: 'Ajustar al contenido', onTapCallback: onFitToContent, activeTheme: theme),
                const SizedBox(height: 8),
                ControlIconButton(iconData: Icons.refresh_rounded, tooltipText: 'Restablecer vista', onTapCallback: onResetView, activeTheme: theme),
                const SizedBox(height: 8),
                ControlIconButton(iconData: Icons.add_rounded, tooltipText: 'Acercar', onTapCallback: onZoomIn, activeTheme: theme),
                const SizedBox(height: 8),
                ControlIconButton(iconData: Icons.remove_rounded, tooltipText: 'Alejar', onTapCallback: onZoomOut, activeTheme: theme),
                Container(
                  height: 1,
                  width: 24,
                  color: theme.axisColor.withOpacity(0.15),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                ),
                ControlIconButton(
                  iconData: gridVisible ? Icons.grid_on_rounded : Icons.grid_off_rounded, 
                  tooltipText: gridVisible ? 'Ocultar cuadrícula' : 'Mostrar cuadrícula', 
                  onTapCallback: onToggleGrid, 
                  activeTheme: theme, 
                  isActiveState: gridVisible
                ),
                const SizedBox(height: 8),
                ControlIconButton(iconData: drawingMode ? Icons.brush_rounded : Icons.brush_outlined, tooltipText: 'Modo dibujo', onTapCallback: onToggleDrawing, activeTheme: theme, isActiveState: drawingMode),
                const SizedBox(height: 8),
                ControlIconButton(iconData: Icons.delete_sweep_rounded, tooltipText: 'Borrar dibujos', onTapCallback: onClearFreehand, activeTheme: theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingCoordinates extends StatelessWidget {
  final TooltipData tooltipData;
  final CartesianCanvasTheme theme;

  const FloatingCoordinates({required this.tooltipData, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.background.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.axisColor.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_searching_rounded, size: 14, color: theme.originDotColor),
                const SizedBox(width: 8),
                Text(
                  'X: ${tooltipData.x.toStringAsFixed(3)}   Y: ${tooltipData.y.toStringAsFixed(3)}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.labelColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LegendRow extends StatelessWidget {
  final Color color;
  final String name;
  final bool isLine;
  final CartesianCanvasTheme theme;

  const LegendRow({required this.color, required this.name, required this.isLine, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isLine
              ? Container(
                  width: 16, 
                  height: 3, 
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))
                )
              : Container(
                  width: 10, 
                  height: 10, 
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)
                ),
          const SizedBox(width: 10),
          Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: theme.axisColor.withOpacity(0.85))),
        ],
      ),
    );
  }
}

class ControlIconButton extends StatelessWidget {
  final IconData iconData;
  final String tooltipText;
  final VoidCallback onTapCallback;
  final CartesianCanvasTheme activeTheme;
  final bool isActiveState;

  const ControlIconButton({required this.iconData, required this.tooltipText, required this.onTapCallback, required this.activeTheme, this.isActiveState = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltipText,
      preferBelow: false,
      verticalOffset: 24,
      decoration: BoxDecoration(
        color: activeTheme.tooltipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(fontSize: 11, color: activeTheme.tooltipTextColor),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTapCallback,
          hoverColor: activeTheme.axisColor.withOpacity(0.05),
          splashColor: activeTheme.originDotColor.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActiveState ? activeTheme.originDotColor.withOpacity(0.15) : Colors.transparent,
              border: Border.all(
                color: isActiveState ? activeTheme.originDotColor.withOpacity(0.6) : Colors.transparent, 
                width: 1.5
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              iconData, 
              size: 20, 
              color: isActiveState ? activeTheme.originDotColor : activeTheme.axisColor.withOpacity(0.7)
            ),
          ),
        ),
      ),
    );
  }
}