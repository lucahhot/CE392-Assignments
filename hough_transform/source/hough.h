#ifndef HOUGH_H
#define HOUGH_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <math.h>

#define HOUGH_TRANSFORM_THRESHOLD 175
// These parameters are used to transform rho and theta into cartesian coordinates (x,y)
// so it goes from the leftmost x coordinate of the mask to the rightmost x coordinate.
// The 0.1 and 0.9 factors are determined inside the mask.py script that creates the mask
#define X_START 1280 * 0.1
#define X_END 1280 * 0.9 

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