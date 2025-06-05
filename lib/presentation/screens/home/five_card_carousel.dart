import 'package:flutter/material.dart';

class FiveCardCarousel extends StatefulWidget {
  final List<Widget> items;
  final double height;
  final double centerScale;
  final double sideScale;
  final double sideOpacity;

  const FiveCardCarousel({
    Key? key,
    required this.items,
    this.height = 140,
    this.centerScale = 1.0,
    this.sideScale = 0.8,
    this.sideOpacity = 0.6,
  }) : super(key: key);

  @override
  State<FiveCardCarousel> createState() => _FiveCardCarouselState();
}

class _FiveCardCarouselState extends State<FiveCardCarousel> {
  static const int _infiniteScrollCount = 10000;
  late final int _initialPage;
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initialPage = _infiniteScrollCount ~/ 2;
    _currentPage = _initialPage;
    _controller = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.25, // 4 cards fit, but we scale for 5-peek effect
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length;
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _controller,
        itemCount: _infiniteScrollCount,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final realIndex = index % itemCount;
          double delta = (_controller.hasClients ? (_controller.page ?? _controller.initialPage).toDouble() : _controller.initialPage.toDouble()) - index.toDouble();
          double scale = widget.centerScale - (delta.abs() * (widget.centerScale - widget.sideScale) / 2);
          scale = scale.clamp(widget.sideScale, widget.centerScale).toDouble();
          double opacity = 1.0 - (delta.abs() * (1.0 - widget.sideOpacity) / 2);
          opacity = opacity.clamp(widget.sideOpacity, 1.0).toDouble();

          return Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: widget.items[realIndex],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 