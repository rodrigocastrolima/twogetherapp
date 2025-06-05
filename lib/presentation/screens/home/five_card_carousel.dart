import 'package:flutter/material.dart';

class FiveCardCarousel extends StatefulWidget {
  final List<Widget> items;
  final double size;
  final double centerScale;
  final double sideScale;
  final double sideOpacity;
  final double spacing;

  const FiveCardCarousel({
    Key? key,
    required this.items,
    this.size = 120,
    this.centerScale = 1.0,
    this.sideScale = 0.85,
    this.sideOpacity = 0.7,
    this.spacing = 28.0,
  }) : super(key: key);

  @override
  State<FiveCardCarousel> createState() => _FiveCardCarouselState();
}

class _FiveCardCarouselState extends State<FiveCardCarousel> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _currentPage,
      viewportFraction: (widget.size + widget.spacing) / MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.width,
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
    final double cardSize = widget.size;
    final double cardSpacing = widget.spacing;
    final double viewportFraction = (cardSize + cardSpacing) / MediaQuery.of(context).size.width;
    if (_controller.viewportFraction != viewportFraction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller = PageController(
          initialPage: _currentPage,
          viewportFraction: viewportFraction,
        );
        setState(() {});
      });
    }
    return SizedBox(
      height: cardSize,
      child: PageView.builder(
        controller: _controller,
        itemCount: itemCount,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          double delta = (_controller.hasClients ? (_controller.page ?? _controller.initialPage).toDouble() : _controller.initialPage.toDouble()) - index.toDouble();
          double scale = widget.centerScale - (delta.abs() * (widget.centerScale - widget.sideScale));
          scale = scale.clamp(widget.sideScale, widget.centerScale).toDouble();
          double opacity = 1.0 - (delta.abs() * (1.0 - widget.sideOpacity));
          opacity = opacity.clamp(widget.sideOpacity, 1.0).toDouble();

          return Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: cardSpacing / 2),
                  child: SizedBox(
                    width: cardSize,
                    height: cardSize,
                    child: widget.items[index],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 