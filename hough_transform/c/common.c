#include "common.h"

int read_bmp(FILE *f, unsigned char* header, int *height, int *width, struct pixel** data) 
{
	printf("reading file...\n");
	// read the first 54 bytes into the header
   if (fread(header, sizeof(unsigned char), 54, f) != 54)
   {
		printf("Error reading BMP header\n");
		return -1;
   }   

	// printf("finish reading header...\n");
   // get height and width of image
   int w = (int)(header[19] << 8) | header[18];
   int h = (int)(header[23] << 8) | header[22];


   *data = (struct pixel *)malloc(w*h*sizeof(struct pixel));
   printf("%d, %d\n", w, h);

   // Read in the image
   int size = w * h;
   // printf("%d\n", fread(*data, sizeof(struct pixel), size, f));
   if (fread(*data, sizeof(struct pixel), size, f) != size){
		printf("Error reading BMP image\n");
		return -1;
   }   

   *width = w;
   *height = h;

	printf("finish reading file...\n");

   return 0;
}

void write_bmp(const char *filename, unsigned char* header, struct pixel* data) 
{
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;
   
   // write the 54-byte header
   fwrite(header, sizeof(unsigned char), 54, file); 
   fwrite(data, sizeof(struct pixel), size, file); 
   
   fclose(file);
}
