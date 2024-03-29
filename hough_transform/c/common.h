#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define THRESHOLD 50

struct pixel {
   unsigned char b;
   unsigned char g;
   unsigned char r;
};

int read_bmp(FILE *f, unsigned char* header, int *height, int *width, struct pixel** data);

void write_bmp(const char *filename, unsigned char* header, struct pixel* data);

#endif
