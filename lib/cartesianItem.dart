import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;

typedef WorldToScreen = Offset Function(double x, double y);
typedef ScreenToWorld = Offset Function(double px, double py);

abstract class CartesianItem {
  const CartesianItem();

  void paint(
    Canvas canvas,
    Size size,
    WorldToScreen worldToScreen,
    ScreenToWorld screenToWorld,
    double scale,
  );
}

class PointItem extends CartesianItem {
  final double x;
  final double y;
  final Color color;
  final double radius;
  final String? label;
  final TextStyle? labelStyle;
  final Offset labelOffset;

  const PointItem({
    required this.x,
    required this.y,
    this.color = Colors.blue,
    this.radius = 6.0,
    this.label,
    this.labelStyle,
    this.labelOffset = const Offset(10, -18),
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    final position = worldToScreen(x, y);

    canvas.drawCircle(
      position + const Offset(0, 2),
      radius + 1,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    canvas.drawCircle(position, radius, Paint()..color = color);
    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (label != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: labelStyle ?? TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      final labelPos = position + labelOffset;
      
      textPainter.paint(canvas, labelPos);
    }
  }
}

class SeriesPoint {
  final double x;
  final double y;
  final String? label;
  final Color? color;
  final double? radius;

  const SeriesPoint({
    required this.x,
    required this.y,
    this.label,
    this.color,
    this.radius,
  });

  factory SeriesPoint.fromMap(
    Map<String, dynamic> map, {
    String mapXKey = 'x',
    String mapYKey = 'y',
    String? mapLabelKey,
  }) {
    return SeriesPoint(
      x: (map[mapXKey] as num).toDouble(),
      y: (map[mapYKey] as num).toDouble(),
      label: mapLabelKey != null ? map[mapLabelKey]?.toString() : null,
    );
  }
}

class SeriesItem extends CartesianItem {
  final String name;
  final List<SeriesPoint> points;
  final Color color;
  final double pointRadius;
  final bool connectPoints;
  final double lineWidth;
  final bool showPoints;
  final StrokeCap lineCap;

  const SeriesItem({
    required this.name,
    required this.points,
    required this.color,
    this.pointRadius = 5.0,
    this.connectPoints = false,
    this.lineWidth = 2.0,
    this.showPoints = true,
    this.lineCap = StrokeCap.round,
  });

  factory SeriesItem.fromMaps(
    List<Map<String, dynamic>> rows, {
    required String name,
    required Color color,
    String mapXKey = 'x',
    String mapYKey = 'y',
    String? mapLabelKey,
    double pointRadius = 5.0,
    bool connectPoints = false,
    double lineWidth = 2.0,
    bool showPoints = true,
  }) {
    return SeriesItem(
      name: name,
      color: color,
      pointRadius: pointRadius,
      connectPoints: connectPoints,
      lineWidth: lineWidth,
      showPoints: showPoints,
      points: rows
          .where((r) => r[mapXKey] != null && r[mapYKey] != null)
          .map((r) => SeriesPoint.fromMap(r, mapXKey: mapXKey, mapYKey: mapYKey, mapLabelKey: mapLabelKey))
          .toList(),
    );
  }

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    if (points.isEmpty) return;

    final screenPoints = points.map((p) => worldToScreen(p.x, p.y)).toList();

    if (connectPoints && screenPoints.length > 1) {
      final path = Path()..moveTo(screenPoints[0].dx, screenPoints[0].dy);
      for (int i = 1; i < screenPoints.length; i++) {
        path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      }
      
      canvas.drawPath(
        path.shift(const Offset(0, 2)),
        Paint()
          ..color = color.withOpacity(0.2)
          ..strokeWidth = lineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = lineCap
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = lineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = lineCap
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (showPoints) {
      for (int i = 0; i < points.length; i++) {
        final currentPoint = points[i];
        final currentScreenPoint = screenPoints[i];
        final currentRadius = currentPoint.radius ?? pointRadius;
        final currentColor = currentPoint.color ?? color;
        
        canvas.drawCircle(currentScreenPoint, currentRadius, Paint()..color = currentColor);
        canvas.drawCircle(
          currentScreenPoint,
          currentRadius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        
        if (currentPoint.label != null) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: currentPoint.label,
              style: TextStyle(fontSize: 11, color: currentColor, fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, currentScreenPoint + const Offset(8, -14));
        }
      }
    }
  }
}

class FunctionItem extends CartesianItem {
  final String equation;
  final Color color;
  final double lineWidth;
  final String? name;

  const FunctionItem({
    required this.equation,
    this.color = Colors.red,
    this.lineWidth = 2.5,
    this.name,
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    if (equation.trim().isEmpty) return;

    final shadowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final basePaint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    try {
      final expressionParser = Parser();
      final mathExpression = expressionParser.parse(equation);
      final contextModel = ContextModel();
      final functionPath = Path();
      bool isFirstPoint = true;

      for (double pixelX = 0; pixelX <= size.width; pixelX += 2) {
        final worldCoordinates = screenToWorld(pixelX, 0);
        contextModel.bindVariable(Variable('x'), Number(worldCoordinates.dx));
        final logicalY = mathExpression.evaluate(EvaluationType.REAL, contextModel) as double;
        final screenCoordinates = worldToScreen(worldCoordinates.dx, logicalY);

        if (screenCoordinates.dy.isInfinite || screenCoordinates.dy.isNaN || screenCoordinates.dy < -size.height * 2 || screenCoordinates.dy > size.height * 3) {
          isFirstPoint = true;
          continue;
        }

        if (isFirstPoint) {
          functionPath.moveTo(pixelX, screenCoordinates.dy);
          isFirstPoint = false;
        } else {
          functionPath.lineTo(pixelX, screenCoordinates.dy);
        }
      }
      
      canvas.drawPath(functionPath.shift(const Offset(0, 2)), shadowPaint);
      canvas.drawPath(functionPath, basePaint);
    } catch (_) {}
  }
}

class TextItem extends CartesianItem {
  final double x;
  final double y;
  final String text;
  final TextStyle style;
  final Offset offset;

  const TextItem({
    required this.x,
    required this.y,
    required this.text,
    this.style = const TextStyle(fontSize: 14, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
    this.offset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    final position = worldToScreen(x, y) + offset;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }
}

class SegmentItem extends CartesianItem {
  final double x1, y1, x2, y2;
  final Color color;
  final double strokeWidth;
  final bool arrow;
  final double arrowSize;
  final List<double>? dashPattern;

  const SegmentItem({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.color = const Color(0xFF374151),
    this.strokeWidth = 2.0,
    this.arrow = false,
    this.arrowSize = 12.0,
    this.dashPattern,
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    final point1 = worldToScreen(x1, y1);
    final point2 = worldToScreen(x2, y2);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (dashPattern != null) {
      drawDashedLine(canvas, point1, point2, linePaint);
    } else {
      canvas.drawLine(point1, point2, linePaint);
    }

    if (arrow) {
      drawArrowHead(canvas, point1, point2, linePaint);
    }
  }

  void drawDashedLine(Canvas canvas, Offset point1, Offset point2, Paint linePaint) {
    final patternArray = dashPattern!;
    final deltaX = point2.dx - point1.dx;
    final deltaY = point2.dy - point1.dy;
    final totalDistance = Offset(deltaX, deltaY).distance;
    final unitVectorX = deltaX / totalDistance;
    final unitVectorY = deltaY / totalDistance;
    double accumulatedDistance = 0;
    int patternIndex = 0;
    bool isDrawingSegment = true;
    while (accumulatedDistance < totalDistance) {
      final currentSegmentLength = patternArray[patternIndex % patternArray.length];
      final endDistance = (accumulatedDistance + currentSegmentLength).clamp(0, totalDistance);
      final segmentStart = Offset(point1.dx + unitVectorX * accumulatedDistance, point1.dy + unitVectorY * accumulatedDistance);
      final segmentEnd = Offset(point1.dx + unitVectorX * endDistance, point1.dy + unitVectorY * endDistance);
      if (isDrawingSegment) canvas.drawLine(segmentStart, segmentEnd, linePaint);
      accumulatedDistance += currentSegmentLength;
      patternIndex++;
      isDrawingSegment = !isDrawingSegment;
    }
  }

  void drawArrowHead(Canvas canvas, Offset point1, Offset point2, Paint linePaint) {
    final deltaX = point2.dx - point1.dx;
    final deltaY = point2.dy - point1.dy;
    final totalDistance = Offset(deltaX, deltaY).distance;
    if (totalDistance == 0) return;
    final unitVectorX = deltaX / totalDistance;
    final unitVectorY = deltaY / totalDistance;
    final rotationAngle = 0.4;
    
    final arrowPaint = Paint()
      ..color = linePaint.color
      ..style = PaintingStyle.fill;

    final arrowWing1 = Offset(
      point2.dx - arrowSize * (unitVectorX * calculateCos(rotationAngle) + unitVectorY * calculateSin(rotationAngle)),
      point2.dy - arrowSize * (unitVectorY * calculateCos(rotationAngle) - unitVectorX * calculateSin(rotationAngle)),
    );
    final arrowWing2 = Offset(
      point2.dx - arrowSize * (unitVectorX * calculateCos(rotationAngle) - unitVectorY * calculateSin(rotationAngle)),
      point2.dy - arrowSize * (unitVectorY * calculateCos(rotationAngle) + unitVectorX * calculateSin(rotationAngle)),
    );
    
    final arrowPath = Path()
      ..moveTo(point2.dx, point2.dy)
      ..lineTo(arrowWing1.dx, arrowWing1.dy)
      ..lineTo(arrowWing2.dx, arrowWing2.dy)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  double calculateCos(double angleValue) => Offset(angleValue, 0).dx == 0 ? 1 : (1 - angleValue * angleValue / 2);
  double calculateSin(double angleValue) => angleValue;
}

class PolygonItem extends CartesianItem {
  final List<(double, double)> vertices;
  final Color? fillColor;
  final Color strokeColor;
  final double strokeWidth;

  const PolygonItem({
    required this.vertices,
    this.fillColor,
    this.strokeColor = const Color(0xFF374151),
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    if (vertices.length < 2) return;
    final mappedPoints = vertices.map((v) => worldToScreen(v.$1, v.$2)).toList();
    final polygonPath = Path()..moveTo(mappedPoints[0].dx, mappedPoints[0].dy);
    for (int i = 1; i < mappedPoints.length; i++) {
      polygonPath.lineTo(mappedPoints[i].dx, mappedPoints[i].dy);
    }
    polygonPath.close();

    if (fillColor != null) {
      canvas.drawPath(polygonPath, Paint()..color = fillColor!);
    }
    canvas.drawPath(
      polygonPath,
      Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

class ImageItem extends CartesianItem {
  final double x;
  final double y;
  final ui.Image image;
  final double worldWidth;
  final Alignment alignment;

  const ImageItem({
    required this.x,
    required this.y,
    required this.image,
    required this.worldWidth,
    this.alignment = Alignment.center,
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    final anchorPoint = worldToScreen(x, y);
    final targetWidth = worldWidth * scale;
    final targetHeight = targetWidth * image.height / image.width;

    final leftPosition = anchorPoint.dx - targetWidth * (alignment.x + 1) / 2;
    final topPosition = anchorPoint.dy - targetHeight * (alignment.y + 1) / 2;

    final sourceRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destinationRect = Rect.fromLTWH(leftPosition, topPosition, targetWidth, targetHeight);
    
    canvas.drawImageRect(
      image, 
      sourceRect, 
      destinationRect, 
      Paint()..filterQuality = FilterQuality.medium
    );
  }
}

class FreehandItem extends CartesianItem {
  final List<Offset> worldPoints;
  final Color color;
  final double strokeWidth;
  final StrokeCap cap;

  const FreehandItem({
    required this.worldPoints,
    this.color = const Color(0xFF1F2937),
    this.strokeWidth = 2.5,
    this.cap = StrokeCap.round,
  });

  @override
  void paint(Canvas canvas, Size size, WorldToScreen worldToScreen, ScreenToWorld screenToWorld, double scale) {
    if (worldPoints.length < 2) return;
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round;

    final strokePath = Path()
      ..moveTo(
        worldToScreen(worldPoints[0].dx, worldPoints[0].dy).dx,
        worldToScreen(worldPoints[0].dx, worldPoints[0].dy).dy,
      );
    for (int i = 1; i < worldPoints.length; i++) {
      final currentScreenPoint = worldToScreen(worldPoints[i].dx, worldPoints[i].dy);
      strokePath.lineTo(currentScreenPoint.dx, currentScreenPoint.dy);
    }
    canvas.drawPath(strokePath, strokePaint);
  }
}

class WidgetItem {
  final double x;
  final double y;
  final Widget child;
  final Alignment alignment;

  const WidgetItem({
    required this.x,
    required this.y,
    required this.child,
    this.alignment = Alignment.center,
  });
}