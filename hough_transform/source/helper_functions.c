#include "helper_functions.h"

// Read BMP file to extract offset value from the header
int read_bmp_until_image_size(FILE* f, unsigned char* header_until_image_size, int *offset, int *bits_per_pixel, int *height, int *width){

   printf("Reading BMP file...\n");
   // read the first 38 bytes into the header
   if (fread(header_until_image_size, sizeof(unsigned char), 38, f) != 38)
   {
      printf("Error reading BMP header for offset value\n");
      return -1;
   }   

   // get height and width of image
   int w = (int)(header_until_image_size[21] << 24) | header_until_image_size[20] << 16 | header_until_image_size[19] << 8 | header_until_image_size[18];
   int h = (int)(header_until_image_size[25] << 24) | header_until_image_size[24] << 16 | header_until_image_size[23] << 8 | header_until_image_size[22];

   // Making sure that the image dimensions are positive
   if (w < 0)
      *width = -w;
   else
      *width = w;
    if (h < 0)
      *height = -h;
   else
      *height = h;
    
   // get bits per pixel value
   *bits_per_pixel = (int)(header_until_image_size[29] << 8) | header_until_image_size[28];

   // To get offset, we get the image size (only the pixel bytes), and subtract that from the file size which includes the header data
   // Doing this because sometimes the "offset" value in the header is actually not the right size and this causes problems when re-writing the image in BMP format
   int image_size = (int)(header_until_image_size[37] << 24) | header_until_image_size[36] << 16 | header_until_image_size[35] << 8 | header_until_image_size[34];
   int file_size = (int)(header_until_image_size[5] << 24) | header_until_image_size[4] << 16 | header_until_image_size[3] << 8 | header_until_image_size[2];

   *offset = file_size - image_size;

   printf("Header length is %d bytes\n", *offset);

   return 0;
}

// Read the rest of the header and the data for pixel24
int read_bmp_data24(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel24* data) 
{
	// read offset - 38 bytes into header_remaining
   if (fread(header_remaining, sizeof(unsigned char), offset-38, f) != offset-38)
   {
		printf("Error reading the remaining BMP header (24-bits)\n");
		return -1;
   }   

   printf("BMP Image dimensions: width = %d, height = %d\n", *width, *height);

   // Read in the image
   int size = *width * *height;

   if (fread(data, sizeof(struct pixel24), size, f) != size){
		printf("Error reading BMP image data (24-bits)\n");
		return -1;
   }   

   return 0;
}


// Read the rest of the header and the data for pixel32
int read_bmp_data32(FILE *f, unsigned char* header_remaining, int offset, int *height, int *width, struct pixel32* data) 
{
	// read offset - 38 bytes into header_remaining
   if (fread(header_remaining, sizeof(unsigned char), offset-38, f) != offset-38)
   {
		printf("Error reading the remaining BMP header (32-bits)\n");
		return -1;
   }   

   printf("BMP Image dimensions: width = %d, height = %d\n", *width, *height);

   // Read in the image
   int size = *width * *height;

   if (fread(data, sizeof(struct pixel32), size, f) != size){
		printf("Error reading BMP image data (32-bits)\n");
		return -1;
   } 

   return 0;
}

// Reading entire mask image for pixel24
int read_entire_bmp24(FILE *f, unsigned char* header, struct pixel24* data, int offset, int height, int width){
   
   // read the first offset bytes into the header
   if (fread(header, sizeof(unsigned char), offset, f) != offset)
   {
      printf("Error reading BMP header for mask image\n");
      return -1;
   }   
    
   // Read in the image
   int size = width * height;

   if (fread(data, sizeof(struct pixel24), size, f) != size){
      printf("Error reading mask image data\n");
      return -1;
   }   

   return 0;

}

// Reading entire mask image for pixel32
int read_entire_bmp32(FILE *f, unsigned char* header, struct pixel32* data, int offset, int height, int width){
   
   // read the first offset bytes into the header
   if (fread(header, sizeof(unsigned char), offset, f) != offset)
   {
      printf("Error reading BMP header for mask image\n");
      return -1;
   }   
    
   // Read in the image
   int size = width * height;

   if (fread(data, sizeof(struct pixel32), size, f) != size){
      printf("Error reading mask image data\n");
      return -1;
   }   

   return 0;

}

// Write the grayscale image to disk for pixel24
void write_bmp24(const char *filename, unsigned char* header, int offset, int height, int width, struct pixel24* data) 
{
   FILE* file = fopen(filename, "wb");

   int size = width * height;
   
   // write the offset-byte header
   fwrite(header, sizeof(unsigned char), offset, file); 
   fwrite(data, sizeof(struct pixel24), size, file); 
   
   fclose(file);
}

// Write the grayscale image to disk for pixel32
void write_bmp32(const char *filename, unsigned char* header, int offset, int height, int width, struct pixel32* data) 
{
   FILE* file = fopen(filename, "wb");

   int size = width * height;
   
   // write the offset-byte header
   fwrite(header, sizeof(unsigned char), offset, file); 
   fwrite(data, sizeof(struct pixel32), size, file); 
   
   fclose(file);
}

// Write the grayscale image to disk for pixel24
void write_grayscale_bmp24(const char *filename, unsigned char* header, int offset, int height, int width, unsigned char* data) {
   FILE* file = fopen(filename, "wb");

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

   fwrite(data_temp, sizeof(struct pixel24), size, file); 
   
   free(data_temp);
   fclose(file);
}

// Write the grayscale image to disk for pixel32
void write_grayscale_bmp32(const char *filename, unsigned char* header, int offset, int height, int width, unsigned char* data) {
   FILE* file = fopen(filename, "wb");

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
   }
}

// Determine the grayscale 8 bit value by averaging the r, g, and b channel values for pixel32
void convert_to_grayscale32(struct pixel32 * data, int height, int width, unsigned char *grayscale_data) 
{
   for (int i = 0; i < width*height; i++) {
      grayscale_data[i] = (data[i].r + data[i].g + data[i].b) / 3;
   }
}

void print_header_info(unsigned char* header){
   // Prints out header category and value to compare headers across BMP images
   printf("\nHeader info: \n");
   printf("ID Field: %02x %02x\n", header[0], header[1]);
   int file_size =  (int)(header[5] << 24) | header[4] << 16 | header[3] << 8 | header[2];
   printf("File Size: %02x %02x %02x %02x (%d)\n", header[2], header[3], header[4], header[5], file_size);
   printf("Reserved 1: %02x %02x\n", header[6], header[7]);
   printf("Reserved 2: %02x %02x\n", header[8], header[9]);
   int offset = (int)(header[13] << 24) | header[12] << 16 | header[11] << 8 | header[10];
   printf("Offset: %02x %02x %02x %02x (%d)\n", header[10], header[11], header[12], header[13], offset);
   int header_size = (int)(header[17] << 24) | header[16] << 16 | header[15] << 8 | header[14];
   printf("Header Size: %02x %02x %02x %02x (%d)\n", header[14], header[15], header[16], header[17], header_size);
   int width = (int)(header[21] << 24) | header[20] << 16 | header[19] << 8 | header[18];
   printf("Width: %02x %02x %02x %02x (%d)\n", header[18], header[19], header[20], header[21], width);
   int height = (int)(header[25] << 24) | header[24] << 16 | header[23] << 8 | header[22];
   printf("Height: %02x %02x %02x %02x (%d)\n", header[22], header[23], header[24], header[25], height);
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
   // If there are more header values, print them out
   if (offset > 54){
      printf("\nAdditional header values: \n");
      printf("Red Mask: %02x %02x %02x %02x\n", header[54], header[55], header[56], header[57]);
      printf("Green Mask: %02x %02x %02x %02x\n", header[58], header[59], header[60], header[61]);
      printf("Blue Mask: %02x %02x %02x %02x\n", header[62], header[63], header[64], header[65]);
      printf("Alpha Mask: %02x %02x %02x %02x\n", header[66], header[67], header[68], header[69]);
      int color_space_type = (int)(header[73] << 24) | header[72] << 16 | header[71] << 8 | header[70];
      printf("Color Space Type: %02x %02x %02x %02x (%d)\n", header[70], header[71], header[72], header[73], color_space_type);
   }
   
}