#ifndef HOUGH_H
#define HOUGH_H

#include <math.h>
#include <stdio.h>

#define HOUGH_TRANSFORM_THRESHOLD 50
#define LINE_LENGTH 500

struct pixel {
   unsigned char b;
   unsigned char g;
   unsigned char r;
};

// Function declaration for houghline
void hough_transform(unsigned char *hysteresis_data, struct pixel *image_in, int height, int width, struct pixel *image_out);

#endif // HOUGH_H