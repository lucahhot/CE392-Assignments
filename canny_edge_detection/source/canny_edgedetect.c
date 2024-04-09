#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <math.h>

#define high_threshold 48
#define low_threshold 12
#define Theta_range 180
#define PI 3.1415926
#define HOUGH_TRANSFORM_THRESHOLD 150
#define LINE_LENGTH 3000


struct pixel {
   unsigned char b;
   unsigned char g;
   unsigned char r;
};

// Read BMP file and extract the pixel values (store in data) and header (store in header)
// data is data[0] = BLUE, data[1] = GREEN, data[2] = RED, etc...
int read_bmp(FILE *f, unsigned char* header, int *height, int *width, struct pixel* data) 
{
	printf("reading file...\n");
	// read the first 54 bytes into the header
   if (fread(header, sizeof(unsigned char), 54, f) != 54)
   {
		printf("Error reading BMP header\n");
		return -1;
   }   

   // get height and width of image
   int w = (int)(header[19] << 8) | header[18];
   int h = (int)(header[23] << 8) | header[22];

   // Read in the image
   int size = w * h;
   if (fread(data, sizeof(struct pixel), size, f) != size){
		printf("Error reading BMP image\n");
		return -1;
   }   

   *width = w;
   *height = h;
   return 0;
}

// Write the grayscale image to disk.
void write_grayscale_bmp(const char *filename, unsigned char* header, unsigned char* data) {
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;
   struct pixel * data_temp = (struct pixel *)malloc(size*sizeof(struct pixel)); 
   
   // write the 54-byte header
   fwrite(header, sizeof(unsigned char), 54, file); 
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
   fwrite(data_temp, sizeof(struct pixel), size, file); 
   
   free(data_temp);
   fclose(file);
}

// Determine the grayscale 8 bit value by averaging the r, g, and b channel values.
void convert_to_grayscale(struct pixel * data, int height, int width, unsigned char *grayscale_data) 
{
   for (int i = 0; i < width*height; i++) {
	   grayscale_data[i] = (data[i].r + data[i].g + data[i].b) / 3;
       //printf("%3d: %02x %02x %02x  ->  %02x\n", i,data[i].r, data[i].g, data[i].b, grayscale_data[i]);
   }
}

// Gaussian blur. 
void gaussian_blur(unsigned char *in_data, int height, int width, unsigned char *out_data) {
   unsigned int gaussian_filter[5][5] = {
      { 2, 4, 5, 4, 2 },
      { 4, 9,12, 9, 4 },
      { 5,12,15,12, 5 },
      { 4, 9,12, 9, 4 },
      { 2, 4, 5, 4, 2 }
   };
   int x, y, i, j;
   unsigned int numerator_r, denominator;

   FILE * test_inputs_file = fopen("test_inputs.txt", "w");
   if (test_inputs_file == NULL) {
      printf("Error opening file for writing.\n");
      return;
   }
  
   for (y = 0; y < height; y++) {
      for (x = 0; x < width; x++) {
         numerator_r = 0;
         denominator = 0;
         for (j = -2; j <= 2; j++) {
            for (i = -2; i <= 2; i++) {
               // Checking if the pixel +/- the 5x5 offset value is within the image coordinates and ignore if not
               if ( (x+i) >= 0 && (x+i) < width && (y+j) >= 0 && (y+j) < height) {
				   unsigned char d = in_data[(y+j)*width + (x+i)];
                   numerator_r += d * gaussian_filter[i+2][j+2];
                   if (y > 537 && x > 717) {
                     fprintf(test_inputs_file, "row: %d (%d) col: %d (%d) %d * %d = %d\n",y,j,x,i,d,gaussian_filter[i+2][j+2],d*gaussian_filter[i+2][j+2]);
                   }
                   denominator += gaussian_filter[i+2][j+2];
               }
            }
         }
		 out_data[y*width + x] = numerator_r / denominator;
       if (y > 537 && x > 717) {
         fprintf(test_inputs_file,"Numerator sum = %d\n",numerator_r);
         fprintf(test_inputs_file,"Gaussian blur value = %d\n",out_data[y*width + x]);
       }
      }
   }

   fclose(test_inputs_file);
}

void sobel(unsigned char in_data[3][3], unsigned char *out_data) 
{    
    // Definition of Sobel filter in horizontal direction
    const int horizontal_operator[3][3] = {
      { -1,  0,  1 },
      { -2,  0,  2 },
      { -1,  0,  1 }
    };
    const int vertical_operator[3][3] = {
      { -1,  -2,  -1 },
      {  0,   0,   0 },
      {  1,   2,   1 }
    };
                                
    int horizontal_gradient = 0;
    int vertical_gradient = 0;

    for (int j = 0; j < 3; j++) 
    {
        for (int i = 0; i < 3; i++) 
        {
            horizontal_gradient += in_data[j][i] * horizontal_operator[i][j];
            vertical_gradient += in_data[j][i] * vertical_operator[i][j];
            //printf("h: %d * %d\n", in_data[j][i], horizontal_operator[i][j] );
            //printf("v: %d * %d\n", in_data[j][i], vertical_operator[i][j] );
        }
    }

    // Check for overflow
    int v = (abs(horizontal_gradient) + abs(vertical_gradient)) / 2;
    //printf("grad: %d\n\n", v);
    *out_data = (unsigned char)(v > 255 ? 255 : v);
}

void sobel_filter(unsigned char *in_data, int height, int width, unsigned char *out_data) 
{
    unsigned char buffer[3][3];
    unsigned char data = 0;

    for (int y = 0; y < height; y++) 
    {
        for (int x = 0; x < width; x++) 
        {
            data = 0;

            // Along the boundaries, set to 0
            if (y != 0 && x != 0 && y != height-1 && x != width-1) 
            {
                for (int j = -1; j <= 1; j++) 
                {
                    for (int i = -1; i <= 1; i++) 
                    {
                        buffer[j+1][i+1] = in_data[(y+j)*width + (x+i)];
                    }
                }

                sobel( buffer, &data );
            }
            
            out_data[y*width + x] = data;
        }
    }
}
    
void non_maximum_suppressor(unsigned char *in_data, int height, int width, unsigned char *out_data) {
      
   for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
         // Along the boundaries, set to 0
         if (y == 0 || x == 0 || y == height-1 || x == width-1) {
            out_data[y*width + x] = 0;
            continue;
         }
         unsigned int north_south = 
            in_data[(y-1)*width + x] + in_data[(y+1)*width + x];
         unsigned int east_west = 
            in_data[y*width + x - 1] + in_data[y*width + x + 1];
         unsigned int north_west = 
            in_data[(y-1)*width + x - 1] + in_data[(y+1)*width + x + 1];
         unsigned int north_east = 
            in_data[(y+1)*width + x - 1] + in_data[(y-1)*width + x + 1];
         
         out_data[y*width + x] = 0;
         
         if (north_south >= east_west && north_south >= north_west && north_south >= north_east) {
            if (in_data[y*width + x] > in_data[y*width + x - 1] && 
               in_data[y*width + x] >= in_data[y*width + x + 1])
            {
               out_data[y*width + x] = in_data[y*width + x];
            }
         } else if (east_west >= north_west && east_west >= north_east) {
            if (in_data[y*width + x] > in_data[(y-1)*width + x] && 
               in_data[y*width + x] >= in_data[(y+1)*width + x])
            {
               out_data[y*width + x] = in_data[y*width + x];
            }
         } else if (north_west >= north_east) {
            if (in_data[y*width + x] > in_data[(y-1)*width + x + 1] && 
               in_data[y*width + x] >= in_data[(y+1)*width + x - 1])
            {
               out_data[y*width + x] = in_data[y*width + x];
            }
         } else {
            if (in_data[y*width + x] > in_data[(y-1)*width + x - 1] && 
               in_data[y*width + x] >= in_data[(y+1)*width + x + 1])
            {
               out_data[y*width + x] = in_data[y*width + x];
            }
         }
      }
   }
}

// Only keep pixels that are next to at least one strong pixel.
void hysteresis_filter(unsigned char *in_data, int height, int width, unsigned char *out_data) 
{
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			// Along the boundaries, set to 0
			if (y == 0 || x == 0 || y == height-1 || x == width-1) {
				out_data[y*width + x] = 0;
				continue;
			}
			
			// If pixel is strong or it is somewhat strong and at least one 
			// neighbouring pixel is strong, keep it. Otherwise zero it.
			if (in_data[y*width + x] > high_threshold || 
				 (in_data[y*width + x] > low_threshold &&
				  (in_data[(y-1)*width + x - 1] > high_threshold ||
				  in_data[(y-1)*width + x] > high_threshold ||
				  in_data[(y-1)*width + x + 1] > high_threshold ||
				  in_data[y*width + x - 1] > high_threshold ||
				  in_data[y*width + x + 1] > high_threshold ||
				  in_data[(y+1)*width + x - 1] > high_threshold ||
				  in_data[(y+1)*width + x] > high_threshold ||
				  in_data[(y+1)*width + x + 1] > high_threshold))
			){
				out_data[y*width + x] = in_data[y*width + x];
			} else {
				out_data[y*width + x] = 0;
			}
		}
	}
}

void draw_a_line(int height, int width, int rho, double sin_theta, double cos_theta, unsigned char *edge, struct pixel* origin_image){
   // printf("starting a line\n");
   double x0 = rho * cos_theta;
   double y0 = rho * sin_theta;
   for(int k=-LINE_LENGTH; k<LINE_LENGTH; k++){
      int x1 = (int)(x0 + k*(-sin_theta));
      int y1 = (int)(y0 + k *(cos_theta));

      // int index = y1*width + x1;
      if(x1>=0 && x1<width && y1>=0 && y1<height && edge[y1*width + x1] > 0) {
         // printf("%d, %d, %d\n", x1, y1, y1*width + x1);
         origin_image[y1*width + x1] = (struct pixel){0, 255, 0};
         if(x1+1<width)origin_image[y1*width + x1 + 1] = (struct pixel){0, 255, 0};
         if(x1+2<width)origin_image[y1*width + x1 + 2] = (struct pixel){0, 255, 0};
         if(x1-2>=0)origin_image[y1*width + x1 - 2] = (struct pixel){0, 255, 0};
         if(x1-1>=0)origin_image[y1*width + x1 - 1] = (struct pixel){0, 255, 0};
         if(y1-1>=0)origin_image[(y1-1)*width + x1] = (struct pixel){0, 255, 0};
         if(y1-2>=0)origin_image[(y1-2)*width + x1] = (struct pixel){0, 255, 0};
         if(y1+1<height)origin_image[(y1+1)*width + x1] = (struct pixel){0, 255, 0};
         if(y1+2<height)origin_image[(y1+2)*width + x1] = (struct pixel){0, 255, 0};
         if(y1+2<height && x1+2<width)origin_image[(y1+2)*width + x1+2] = (struct pixel){0, 255, 0};
         if(y1+1<height && x1+1<width)origin_image[(y1+1)*width + x1+1] = (struct pixel){0, 255, 0};
         if(y1+1<height && x1+2<width)origin_image[(y1+1)*width + x1+2] = (struct pixel){0, 255, 0};
         if(y1+2<height && x1+1<width)origin_image[(y1+2)*width + x1+1] = (struct pixel){0, 255, 0};

      }
      // if(x1>=0 && x1<width - 1 && y1>=0 && y1<height) {origin_image[y1*width + x1 +1 ] = (struct pixel){0, 255, 0};}
   }
}


void hough_transform(int height, int width, unsigned char *edge, struct pixel* origin_image){

   //pre-calculate the sin and cos
   double theta_base = -90.;
   double sin_theta[Theta_range];
   double cos_theta[Theta_range];
   for(int i=0; i<Theta_range; i++){
      double temp = (double)i + theta_base;
      double temp_radians = temp * PI /180;
      sin_theta[i] = sin(temp_radians);
      cos_theta[i] = cos(temp_radians);
   }

   // printf("precalculation finished\n");

   //init the accumulator
   int rho_max = (int)sqrt(height*height + width * width);
   int **accumulator = (int **)malloc(2*rho_max*sizeof(int*));
   for(int i=0; i<2*rho_max; i++){
      accumulator[i] = (int *)malloc(Theta_range*sizeof(int));
   }
   for(int i=0; i<2*rho_max; i++){
      for(int j=0; j<Theta_range; j++){
         accumulator[i][j] = 0;
      }
   }
   printf("init accumulator finished\n");

   //suppose the edges are white
   //process the accumulator
   for(int y=0; y<height; y++){
      for(int x = 0; x<width; x++){
         if(edge[y*width + x] > 0){
            for(int k=0; k<Theta_range; k++){
               int rho = (int)(x*cos_theta[k] + y*sin_theta[k]) + rho_max;
               accumulator[rho][k] += 1;
            }
         }
      }
   }

   printf("accumulate finished\n");

   //fliter the accumulator and draw lines
   for(int i = 0; i<2*rho_max; i++){
      for(int j=0; j<Theta_range; j++){
         if(accumulator[i][j]>=HOUGH_TRANSFORM_THRESHOLD){
            draw_a_line(height, width, i-rho_max, sin_theta[j], cos_theta[j], edge, origin_image);
            // return;
         }
      }
   }

   printf("draw line finished\n");

   //free the accumulator
   for(int i=0; i<2*rho_max; i++){
      free(accumulator[i]);
   }
   free(accumulator);
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

int main(int argc, char *argv[]) {
	struct pixel *rgb_data = (struct pixel *)malloc(720*720*sizeof(struct pixel));
	unsigned char *gs_data = (unsigned char *)malloc(720*720*sizeof(unsigned char));
	unsigned char *gb_data = (unsigned char *)malloc(720*720*sizeof(unsigned char));
	unsigned char *sobel_data = (unsigned char *)malloc(720*720*sizeof(unsigned char));
	unsigned char *nms_data = (unsigned char *)malloc(720*720*sizeof(unsigned char));
	unsigned char *h_data = (unsigned char *)malloc(720*720*sizeof(unsigned char));
	unsigned char header[64];
	int height, width;

	// Check inputs
	if (argc < 2) {
		printf("Usage: edgedetect <BMP filename>\n");
		return 0;
	}

	FILE * f = fopen(argv[1],"rb");
	if ( f == NULL ) return 0;

	// read the bitmap
	read_bmp(f, header, &height, &width, rgb_data);

	/// Grayscale conversion
	convert_to_grayscale(rgb_data, height, width, gs_data);
	write_grayscale_bmp("../images/stage0_grayscale.bmp", header, gs_data);

	/// Gaussian filter
	gaussian_blur(gs_data, height, width, gb_data);
	write_grayscale_bmp("../images/stage1_gaussian.bmp", header, gb_data);

	/// Sobel operator
	sobel_filter(gb_data, height, width, sobel_data);
	write_grayscale_bmp("../images/stage2_sobel.bmp", header, sobel_data);

	/// Non-maximum suppression
	non_maximum_suppressor(sobel_data, height, width, nms_data);
	write_grayscale_bmp("../images/stage3_nonmax_suppression.bmp", header, nms_data);

	/// Hysteresis
	hysteresis_filter(nms_data, height, width, h_data);
	write_grayscale_bmp("../images/stage4_hysteresis.bmp", header, h_data);

   hough_transform(height, width, h_data, rgb_data);
   write_bmp("../images/output.bmp", header, rgb_data);

	return 0;
}


