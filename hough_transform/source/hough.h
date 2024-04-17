#ifndef HOUGH_H
#define HOUGH_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <math.h>

#define HOUGH_TRANSFORM_THRESHOLD 150
#define LINE_LENGTH 5000

#define high_threshold 48
#define low_threshold 12

struct pixel24 {
    unsigned char b;
    unsigned char g;
    unsigned char r;
};

struct pixel32 {
    unsigned char b;
    unsigned char g;
    unsigned char r;
    unsigned char a;
};

// Function declaration for houghline
void hough_transform24(unsigned char *hysteresis_data, struct pixel24 * mask, int height, int width, struct pixel24 *image_out);
void hough_transform32(unsigned char *hysteresis_data, struct pixel32 * mask, int height, int width, struct pixel32 *image_out);

#endif // HOUGH_H