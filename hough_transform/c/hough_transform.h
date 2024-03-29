#ifndef HOUGH_TRANSFORM_H
#define HOUGH_TRANSFORM_H

#include "common.h"
#include <math.h>

#define Theta_range 180
#define PI 3.1415926
#define HOUGH_TRANSFORM_THRESHOLD 300

int is_edge(struct pixel point);

// int on_the_line(int rho, double sin_theta, double cos_theta, int x, int y);

void draw_a_line(int height, int width, int rho, double sin_theta, double cos_theta, struct pixel* edge, struct pixel* origin_image);

void hough_transform(int height, int width, struct pixel* edge, struct pixel* origin_image);

#endif
