import 'package:flutter/material.dart';
import 'package:cartesian_plane/cartesianPlane.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cartesian Plane',
      home: CartesianPlaneScreen(),
    );
  }
}

class CartesianPlaneScreen extends StatelessWidget {
  const CartesianPlaneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plano Cartesiano')),
      body: Container(
        width: 400,
        height: 300,
        child: CartesianCanvas(
          title: 'Ejemplo Básico',
          items: [
            FunctionItem(
              equation: "x^2",
              color: Colors.red,
              lineWidth: 2.0,
              name: "Parábola",
            ),
            PointItem(x: 2.0, y: 4.0, color: Colors.blue, label: 'P(2, 4)'),
            SegmentItem(
              x1: -3.0,
              y1: 1.0,
              x2: 3.0,
              y2: 1.0,
              color: Colors.green,
              arrow: true,
            ),
            PointItem(x: 200.0, y: 40.0, color: Colors.blue, label: 'P(2, 4)'),
          ],
        ),
      ),
    );
  }
}
