import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Delegate interface used by [CartesianCanvasController] to communicate with the canvas.
/// This allows the controller to trigger actions inside the canvas state.
abstract class CartesianCanvasDelegate {
  /// Resets the canvas view to its initial origin and scale.
  void resetView();

  /// Zooms the canvas in or out from the center of the viewport by a given [factor].
  void zoomFromCenter(double factor);

  /// Automatically adjusts the view (scale and origin) to fit all items within the viewport.
  void fitToContent();

  /// Moves the center of the viewport to the specific [x] and [y] world coordinates.
  void goToPoint(double x, double y);

  /// Captures the current visible canvas as an image.
  /// Returns a [ui.Image] which can be used to save or share the graph.
  Future<ui.Image?> captureImage();

  /// Returns true if the freehand drawing mode is currently active.
  bool get drawingMode;

  /// Sets the freehand drawing mode to [val].
  void setDrawingMode(bool val);

  /// Returns true if the eraser mode is currently active.
  bool get eraserMode;

  /// Sets the eraser mode to [val].
  void setEraserMode(bool val);

  /// Clears all freehand strokes (including erasures) from the canvas.
  void clearFreehand();

  /// Undoes the last freehand stroke or erasure.
  void undoFreehand();

  /// Redoes the previously undone freehand stroke or erasure.
  void redoFreehand();

  /// Returns true if the background grid is currently visible.
  bool get gridVisible;

  /// Sets the visibility of the background grid to [val].
  void setGridVisible(bool val);
}

/// A controller for interacting programmatically with a CartesianPlane.
///
/// This controller can be passed to a CartesianPlane to allow external widgets
/// to trigger view resets, zoom, freehand drawing modes, and more.
class CartesianCanvasController extends ChangeNotifier {
  /// The attached delegate, usually provided by the CartesianPlane's state.
  CartesianCanvasDelegate? canvasDelegate;

  /// Attaches a [newDelegate] to this controller. Called automatically by CartesianPlane.
  void attach(CartesianCanvasDelegate newDelegate) =>
      canvasDelegate = newDelegate;

  /// Detaches the current delegate from this controller.
  void detach() => canvasDelegate = null;

  /// Resets the CartesianPlane view to the initial scale and origin.
  void resetView() => canvasDelegate?.resetView();

  /// Zooms the canvas in by a fixed multiplier.
  void zoomIn() => canvasDelegate?.zoomFromCenter(1.3);

  /// Zooms the canvas out by a fixed multiplier.
  void zoomOut() => canvasDelegate?.zoomFromCenter(0.77);

  /// Adjusts the scale and origin to fit all elements currently on the plane.
  void fitToContent() => canvasDelegate?.fitToContent();

  /// Moves the center of the camera to the specified world coordinates [x] and [y].
  void goToPoint(double x, double y) => canvasDelegate?.goToPoint(x, y);

  /// Captures and returns an image of the current canvas viewport.
  Future<ui.Image?> captureImage() async =>
      await canvasDelegate?.captureImage();

  /// Whether the drawing mode is active.
  bool get drawingMode => canvasDelegate?.drawingMode ?? false;

  /// Sets whether the drawing mode is active.
  set drawingMode(bool isEnabled) => canvasDelegate?.setDrawingMode(isEnabled);

  /// Helper method to toggle or set drawing mode.
  void setDrawingMode(bool isEnabled) =>
      canvasDelegate?.setDrawingMode(isEnabled);

  /// Whether the eraser mode is active.
  bool get eraserMode => canvasDelegate?.eraserMode ?? false;

  /// Sets whether the eraser mode is active.
  set eraserMode(bool isEnabled) => canvasDelegate?.setEraserMode(isEnabled);

  /// Helper method to toggle or set eraser mode.
  void setEraserMode(bool isEnabled) =>
      canvasDelegate?.setEraserMode(isEnabled);

  /// Deletes all freehand strokes drawn on the canvas.
  void clearFreehand() => canvasDelegate?.clearFreehand();

  /// Undoes the last freehand drawing or erase action.
  void undoFreehand() => canvasDelegate?.undoFreehand();

  /// Redoes the last undone freehand drawing or erase action.
  void redoFreehand() => canvasDelegate?.redoFreehand();

  /// Whether the grid is currently visible.
  bool get gridVisible => canvasDelegate?.gridVisible ?? true;

  /// Toggles or sets grid visibility.
  set gridVisible(bool isVisible) => canvasDelegate?.setGridVisible(isVisible);

  /// Helper method to toggle or set grid visibility.
  void setGridVisible(bool isVisible) =>
      canvasDelegate?.setGridVisible(isVisible);
}
