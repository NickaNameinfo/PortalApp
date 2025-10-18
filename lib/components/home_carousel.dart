import 'package:carousel_slider/carousel_slider.dart' as carousel_slider;
import 'package:flutter/material.dart';

var slides = [
  'assets/images/slides/slide_1.jpg',
  'assets/images/slides/slide_2.jpg',
  'assets/images/slides/slide_4.jpg',
  'assets/images/slides/slide_3.jpg',
  'assets/images/slides/slide_5.jpg',
  'assets/images/slides/slide_6.jpg',
  'assets/images/slides/slide_7.jpg',
  'assets/images/slides/slide_8.jpg',
  'assets/images/slides/slide_9.jpg',
  'assets/images/slides/slide_10.jpg',
  'assets/images/slides/slide_11.jpg',
  'assets/images/slides/slide_12.jpg',
  'assets/images/slides/slide_13.jpg',
  'assets/images/slides/slide_14.jpg',
];

Widget kSlideContainer(String imgUrl) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.asset(
      imgUrl,
      fit: BoxFit.cover,
    ),
  );
}

carousel_slider.CarouselSlider buildCarouselSlider() {
  return carousel_slider.CarouselSlider.builder(
    options: carousel_slider.CarouselOptions(
      viewportFraction: 0.5,
      aspectRatio: 2.0,
      height: 250,
      enlargeStrategy: carousel_slider.CenterPageEnlargeStrategy.scale,
      enlargeCenterPage: true,
      autoPlay: true,
    ),
    itemCount: slides.length,
    itemBuilder: (context, index, i) => kSlideContainer(slides[index]),
  );
}
