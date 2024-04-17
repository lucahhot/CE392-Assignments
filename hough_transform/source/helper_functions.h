#ifndef HELP_FUNCTIONS_H
#define HELP_FUNCTIONS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <math.h>
#include "hough.h"

// Helper function definitions
int read_bmp_until_image_size(FILE* f, unsigned char* header_until_image_size, int *offset, int *bits_per_pixel, int *height, int *width);

int read_bmp_data24(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel24* data);

int read_bmp_data32(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel32* data); 

int read_entire_bmp24(FILE *f, unsigned char* header, struct pixel24* data, int offset, int height, int width);

int read_entire_bmp32(FILE *f, unsigned char* header, struct pixel32* data, int offset, int height, int width);

void write_bmp24(const char *filename, unsigned char* header, int offset, int height, int width, struct pixel24* data);

void write_bmp32(const char *filename, unsigned char* header, int offset, int height, int width, struct pixel32* data);

void write_grayscale_bmp24(const char *filename, unsigned char* header, int offset, int height, int width, unsigned char* data);

void write_grayscale_bmp32(const char *filename, unsigned char* header, int offset, int height, int width, unsigned char* data);

void convert_to_grayscale24(struct pixel24 * data, int height, int width, unsigned char *grayscale_data);

void convert_to_grayscale32(struct pixel32 * data, int height, int width, unsigned char *grayscale_data);

void print_header_info(unsigned char* header);

void mask_canny24(unsigned char *in_data, struct pixel24 * mask, int height, int width, unsigned char *out_data);

void mask_canny32(unsigned char *in_data, struct pixel32 * mask, int height, int width, unsigned char *out_data);

#endif // HOUGH_H