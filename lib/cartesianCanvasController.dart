import 'dart:ui' as ui;
import 'package:flutter/material.dart';

abstract class CartesianCanvasDelegate {
  void resetView();
  void zoomFromCenter(double factor);
  void fitToContent();
  void goToPoint(double x, double y);
  Future<ui.Image?> captureImage();
  bool get drawingMode;
  void setDrawingMode(bool val);
  void clearFreehand();
  void undoFreehand();
  void redoFreehand();
  bool get gridVisible;
  void setGridVisible(bool val);
}

class CartesianCanvasController extends ChangeNotifier {
  CartesianCanvasDelegate? canvasDelegate;

  void attach(CartesianCanvasDelegate newDelegate) =>
      canvasDelegate = newDelegate;

  void detach() => canvasDelegate = null;

  void resetView() => canvasDelegate?.resetView();

  void zoomIn() => canvasDelegate?.zoomFromCenter(1.3);

  void zoomOut() => canvasDelegate?.zoomFromCenter(0.77);

  void fitToContent() => canvasDelegate?.fitToContent();

  void goToPoint(double x, double y) => canvasDelegate?.goToPoint(x, y);

  Future<ui.Image?> captureImage() async =>
      await canvasDelegate?.captureImage();

  bool get drawingMode => canvasDelegate?.drawingMode ?? false;

  set drawingMode(bool isEnabled) => canvasDelegate?.setDrawingMode(isEnabled);

  void setDrawingMode(bool isEnabled) =>
      canvasDelegate?.setDrawingMode(isEnabled);

  void clearFreehand() => canvasDelegate?.clearFreehand();

  void undoFreehand() => canvasDelegate?.undoFreehand();

  void redoFreehand() => canvasDelegate?.redoFreehand();

  bool get gridVisible => canvasDelegate?.gridVisible ?? true;

  set gridVisible(bool isVisible) => canvasDelegate?.setGridVisible(isVisible);

  void setGridVisible(bool isVisible) =>
      canvasDelegate?.setGridVisible(isVisible);
}
