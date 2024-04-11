#ifndef HELP_FUNCTIONS_H
#define HELP_FUNCTIONS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <math.h>
#include "hough.h"

// Helper function definitions
int read_offset(FILE* f, unsigned char* header_until_offset, int *offset);
int read_bits_per_pixel(FILE* f, unsigned char* header_until_bits_per_pixel, int *bits_per_pixel, int *height, int *width);
int read_bmp_data24(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel24* data);
int read_bmp_data32(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel32* data); 
void write_bmp24(const char *filename, unsigned char* header, int offset, struct pixel24* data);
void write_bmp32(const char *filename, unsigned char* header, int offset, struct pixel32* data);
void write_grayscale_bmp24(const char *filename, unsigned char* header, int offset, unsigned char* data);
void write_grayscale_bmp32(const char *filename, unsigned char* header, int offset, unsigned char* data);
void convert_to_grayscale24(struct pixel24 * data, int height, int width, unsigned char *grayscale_data);
void convert_to_grayscale32(struct pixel32 * data, int height, int width, unsigned char *grayscale_data);
void print_header_info(unsigned char* header);

#endif // HOUGH_H