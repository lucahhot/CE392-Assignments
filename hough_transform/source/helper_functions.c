#include "helper_functions.h"

// Read BMP file to extract offset value from the header
int read_offset(FILE* f, unsigned char* header_until_offset, int *offset){

   printf("Reading BMP file...\n");
   // read the first 14 bytes into the header
   if (fread(header_until_offset, sizeof(unsigned char), 14, f) != 14)
   {
      printf("Error reading BMP header for offset value\n");
      return -1;
   }   

   // get offset value
   *offset = (int)(header_until_offset[13] << 24) | header_until_offset[12] << 16 | header_until_offset[11] << 8 | header_until_offset[10];

   return 0;
}

// Read BMP file to extract bits per pixel value from the header (to determine our struct pixel )
int read_bits_per_pixel(FILE* f, unsigned char* header_until_bits_per_pixel, int *bits_per_pixel, int *height, int *width){

   // read the next 16 bytes into the header
   if (fread(header_until_bits_per_pixel, sizeof(unsigned char), 16, f) != 16)
   {
      printf("Error reading BMP header for bits per pixel value\n");
      return -1;
   }   

   // get height and width of image
   *width = (int)(header_until_bits_per_pixel[7] << 24) | header_until_bits_per_pixel[6] << 16 | header_until_bits_per_pixel[5] << 8 | header_until_bits_per_pixel[4];
   *height = (int)(header_until_bits_per_pixel[11] << 24) | header_until_bits_per_pixel[10] << 16 | header_until_bits_per_pixel[9] << 8 | header_until_bits_per_pixel[8];

   // get bits per pixel value
   *bits_per_pixel = (int)(header_until_bits_per_pixel[15] << 8) | header_until_bits_per_pixel[14];
   return 0;
}


// Read the rest of the header and the data for pixel24
int read_bmp_data24(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel24* data) 
{
	// read offset - 14 - 16 bytes into header_remaining
   if (fread(header_remaining, sizeof(unsigned char), offset-14-16, f) != offset-14-16)
   {
		printf("Error reading the remaining BMP header\n");
		return -1;
   }   

   printf("BMP Image dimensions: width = %d, height = %d\n", *width, *height);

   // Read in the image
   int size = *width * *height;

   if (fread(data, sizeof(struct pixel24), size, f) != size){
		printf("Error reading BMP image data\n");
		return -1;
   }   

   return 0;
}


// Read the rest of the header and the data for pixel32
int read_bmp_data32(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel32* data) 
{
	// read offset - 14 - 16 bytes into header_remaining
   if (fread(header_remaining, sizeof(unsigned char), offset-14-16, f) != offset-14-16)
   {
		printf("Error reading the remaining BMP header\n");
		return -1;
   }   

   printf("BMP Image dimensions: width = %d, height = %d\n", *width, *height);

   // Read in the image
   int size = *width * *height;

   if (fread(data, sizeof(struct pixel32), size, f) != size){
		printf("Error reading BMP image data\n");
		return -1;
   }   

   return 0;
}

// Write the grayscale image to disk for pixel24
void write_bmp24(const char *filename, unsigned char* header, int offset, struct pixel24* data) 
{
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;
   
   // write the offset-byte header
   fwrite(header, sizeof(unsigned char), offset, file); 
   fwrite(data, sizeof(struct pixel24), size, file); 
   
   fclose(file);
}

// Write the grayscale image to disk for pixel32
void write_bmp32(const char *filename, unsigned char* header, int offset, struct pixel32* data) 
{
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;
   
   // write the offset-byte header
   fwrite(header, sizeof(unsigned char), offset, file); 
   fwrite(data, sizeof(struct pixel32), size, file); 
   
   fclose(file);
}

// Write the grayscale image to disk for pixel24
void write_grayscale_bmp24(const char *filename, unsigned char* header, int offset, unsigned char* data) {
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;

   // printf("Writing an image of dimensions: width = %d, height = %d\n", width, height);

   struct pixel24 * data_temp = (struct pixel24 *)malloc(size*sizeof(struct pixel24)); 
   
   // write the offset-byte header
   fwrite(header, sizeof(unsigned char), offset, file); 
   int y, x;
   
   // the r field of the pixel has the grayscale value. copy to g and b.
   for (y = 0; y < height; y++) {
      for (x = 0; x < width; x++) {
            (*(data_temp + y*width + x)).b = (*(data + y*width + x));
            (*(data_temp + y*width + x)).g = (*(data + y*width + x));
            (*(data_temp + y*width + x)).r = (*(data + y*width + x));
      }
   }

   size = width * height;
   fwrite(data_temp, sizeof(struct pixel24), size, file); 
   
   free(data_temp);
   fclose(file);
}

// Write the grayscale image to disk for pixel32
void write_grayscale_bmp32(const char *filename, unsigned char* header, int offset, unsigned char* data) {
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;

   // printf("Writing an image of dimensions: width = %d, height = %d\n", width, height);

   struct pixel32 * data_temp = (struct pixel32 *)malloc(size*sizeof(struct pixel32)); 
   
   // write the offset-byte header
   fwrite(header, sizeof(unsigned char), offset, file); 
   int y, x;
   
   // the r field of the pixel has the grayscale value. copy to g and b.
   for (y = 0; y < height; y++) {
      for (x = 0; x < width; x++) {
            (*(data_temp + y*width + x)).b = (*(data + y*width + x));
            (*(data_temp + y*width + x)).g = (*(data + y*width + x));
            (*(data_temp + y*width + x)).r = (*(data + y*width + x));
            (*(data_temp + y*width + x)).a = 0xFF;
      }
   }

   size = width * height;
   fwrite(data_temp, sizeof(struct pixel32), size, file); 
   
   free(data_temp);
   fclose(file);
}

// Determine the grayscale 8 bit value by averaging the r, g, and b channel values for pixel24
void convert_to_grayscale24(struct pixel24 * data, int height, int width, unsigned char *grayscale_data) 
{
   for (int i = 0; i < width*height; i++) {
	   grayscale_data[i] = (data[i].r + data[i].g + data[i].b) / 3;
      //  printf("%3d: %02x %02x %02x  ->  %02x\n", i,data[i].r, data[i].g, data[i].b, grayscale_data[i]);
   }
}

// Determine the grayscale 8 bit value by averaging the r, g, and b channel values for pixel32
void convert_to_grayscale32(struct pixel32 * data, int height, int width, unsigned char *grayscale_data) 
{
   for (int i = 0; i < width*height; i++) {
	   grayscale_data[i] = (data[i].r + data[i].g + data[i].b) / 3; // We ignore the data[i].a channel 
      //  printf("%3d: %02x %02x %02x  ->  %02x\n", i,data[i].r, data[i].g, data[i].b, grayscale_data[i]);
   }
}

void print_header_info(unsigned char* header){
   // Prints out header category and value to compare headers across BMP images
   printf("\nHeader info (for 24-bit bitmaps): \n");
   printf("ID Field: %02x %02x\n", header[0], header[1]);
   int file_size =  (int)(header[5] << 24) | header[4] << 16 | header[3] << 8 | header[2];
   printf("File Size: %02x %02x %02x %02x (%d)\n", header[2], header[3], header[4], header[5], file_size);
   printf("Reserved 1: %02x %02x\n", header[6], header[7]);
   printf("Reserved 2: %02x %02x\n", header[8], header[9]);
   int offset = (int)(header[13] << 24) | header[12] << 16 | header[11] << 8 | header[10];
   printf("Offset: %02x %02x %02x %02x (%d)\n", header[10], header[11], header[12], header[13], offset);
   int header_size = (int)(header[17] << 24) | header[16] << 16 | header[15] << 8 | header[14];
   printf("Header Size: %02x %02x %02x %02x (%d)\n", header[14], header[15], header[16], header[17], header_size);
   int width = (int)(header[19] << 8) | header[18];
   printf("Width: %02x %02x (%d)\n", header[18], header[19], width);
   int height = (int)(header[23] << 8) | header[22];
   printf("Height: %02x %02x (%d)\n", header[22], header[23], height);
   int planes = (int)(header[25] << 8) | header[24];
   printf("Planes: %02x %02x (%d)\n", header[24], header[25], planes);
   int bits_per_pixel = (int)(header[29] << 8) | header[28];
   printf("Bits per Pixel: %02x %02x (%d)\n", header[28], header[29], bits_per_pixel);
   int compression = (int)(header[33] << 24) | header[32] << 16 | header[31] << 8 | header[30];
   printf("Compression: %02x %02x %02x %02x (%d)\n", header[30], header[31], header[32], header[33], compression);
   int image_size = (int)(header[37] << 24) | header[36] << 16 | header[35] << 8 | header[34];
   printf("Image Size: %02x %02x %02x %02x (%d)\n", header[34], header[35], header[36], header[37], image_size);
   int x_pixels_per_meter = (int)(header[41] << 24) | header[40] << 16 | header[39] << 8 | header[38];
   printf("X Pixels per Meter: %02x %02x %02x %02x (%d)\n", header[38], header[39], header[40], header[41], x_pixels_per_meter);
   int y_pixels_per_meter = (int)(header[45] << 24) | header[44] << 16 | header[43] << 8 | header[42];
   printf("Y Pixels per Meter: %02x %02x %02x %02x (%d)\n", header[42], header[43], header[44], header[45], y_pixels_per_meter);
   int total_colors = (int)(header[49] << 24) | header[48] << 16 | header[47] << 8 | header[46];
   printf("Total Colors: %02x %02x %02x %02x (%d)\n", header[46], header[47], header[48], header[49], total_colors);
   int important_colors = (int)(header[53] << 24) | header[52] << 16 | header[51] << 8 | header[50];
   printf("Important Colors: %02x %02x %02x %02x (%d)\n", header[50], header[51], header[52], header[53], important_colors);
   printf("\n");
}