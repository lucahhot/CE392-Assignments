#include "hough.h"
#include "helper_functions.h"

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
                  denominator += gaussian_filter[i+2][j+2];
               }
            }
         }
		   out_data[y*width + x] = numerator_r / denominator;
      }
   }

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
				  (in_data[(y-1)*width + x - 1] > high_threshold || // top-left
				  in_data[(y-1)*width + x] > high_threshold || // top
				  in_data[(y-1)*width + x + 1] > high_threshold || // top right
				  in_data[y*width + x - 1] > high_threshold || // left
				  in_data[y*width + x + 1] > high_threshold || // right
				  in_data[(y+1)*width + x - 1] > high_threshold || // bottom left
				  in_data[(y+1)*width + x] > high_threshold || // bottom
				  in_data[(y+1)*width + x + 1] > high_threshold)) // bottom right
			){
				out_data[y*width + x] = in_data[y*width + x];
			} else {
				out_data[y*width + x] = 0;
			}
		}
	}
}

int main(int argc, char *argv[]) {
   
   // Check inputs (reject if not enough arguments)
	if (argc < 2) {
		printf("Usage: ./canny_hough <BMP filename>\n");
		return 0;
	}

	FILE * f = fopen(argv[1],"rb");
	if ( f == NULL ) return 0;

   // Reading header to get offset value
   unsigned char header_until_offset[14];
   int offset;

   read_offset(f, header_until_offset, &offset);

   // Reading header to get bits per pixel value
   unsigned char header_until_bits_per_pixel[16];
   int bits_per_pixel;
   int height, width;

   read_bits_per_pixel(f, header_until_bits_per_pixel, &bits_per_pixel, &height, &width);

   // If bits_per_pixel != 24 && bits_per_pixel != 32, then return -1 and exit
   if (bits_per_pixel != 24 && bits_per_pixel != 32) {
      printf("Error: Unsupported bits per pixel value\n");
      return -1;
   }

   struct pixel24 *rgb_data24 = NULL;
   struct pixel24 *output_data24 = NULL;
   struct pixel32 *rgb_data32 = NULL;
   struct pixel32 *output_data32 = NULL;

   // Dynamically allocate memory for the pixel data based on the bits per pixel value
   if (bits_per_pixel == 24) {
      rgb_data24 = (struct pixel24 *)malloc(width * height * sizeof(struct pixel24));
      output_data24 = (struct pixel24 *)malloc(width * height *sizeof(struct pixel24));
   } else {
      rgb_data32 = (struct pixel32 *)malloc(width * height * sizeof(struct pixel32));
      output_data32 = (struct pixel32 *)malloc(width * height *sizeof(struct pixel32));
   }

   // Read the rest of the header
   unsigned char header_remaining[offset-14-16];
   if (bits_per_pixel == 24)
      read_bmp_data24(f, header_remaining, offset, &height, &width, rgb_data24);
   else
      read_bmp_data32(f, header_remaining, offset, &height, &width, rgb_data32);

   // Final complete header
   unsigned char header[offset];

   // Combine all 3 headers to get the full header
   memcpy(header, header_until_offset, 14);  // Copy the first part of the header
   memcpy(header + 14, header_until_bits_per_pixel, 16);  // Copy the second part of the header
   memcpy(header + 14 + 16, header_remaining, offset - 14 - 16);  // Copy the third part of the header

   printf("Successfully read BMP file!\n");

   // Allocate memory for grayscale, gaussian, sobel, non-maximum suppression, and hysteresis data
	unsigned char *gs_data = (unsigned char *)malloc(width * height *sizeof(unsigned char));
	unsigned char *gb_data = (unsigned char *)malloc(width * height *sizeof(unsigned char));
	unsigned char *sobel_data = (unsigned char *)malloc(width * height *sizeof(unsigned char));
	unsigned char *nms_data = (unsigned char *)malloc(width * height *sizeof(unsigned char));
	unsigned char *h_data = (unsigned char *)malloc(width * height *sizeof(unsigned char));	
   
   // Print header data
   print_header_info(header);

   if (bits_per_pixel == 24) {
      // Grayscale conversion
      convert_to_grayscale24(rgb_data24, height, width, gs_data);
      write_grayscale_bmp24("../images/stage0_grayscale.bmp", header, offset, gs_data);

      // Gaussian filter
      gaussian_blur(gs_data, height, width, gb_data);
      write_grayscale_bmp24("../images/stage1_gaussian.bmp", header, offset, gb_data);

      // Sobel operator
      sobel_filter(gb_data, height, width, sobel_data);
      write_grayscale_bmp24("../images/stage2_sobel.bmp", header, offset, sobel_data);

      // Non-maximum suppression
      non_maximum_suppressor(sobel_data, height, width, nms_data);
      write_grayscale_bmp24("../images/stage3_nonmax_suppression.bmp", header, offset, nms_data);

      // Hysteresis
      hysteresis_filter(nms_data, height, width, h_data);
      write_grayscale_bmp24("../images/stage4_hysteresis.bmp", header, offset, h_data);

      // Setting output data to rgb_data to have the original pixel values in our final image output
      output_data24 = rgb_data24;
      // Hough Transform
      hough_transform24(h_data, height, width, output_data24);
      write_bmp24("../images/stage5_hough.bmp", header, offset, output_data24);
   } else {
      /// Grayscale conversion
      convert_to_grayscale32(rgb_data32, height, width, gs_data);
      write_grayscale_bmp32("../images/stage0_grayscale.bmp", header, offset, gs_data);

      /// Gaussian filter
      gaussian_blur(gs_data, height, width, gb_data);
      write_grayscale_bmp32("../images/stage1_gaussian.bmp", header, offset, gb_data);

      /// Sobel operator
      sobel_filter(gb_data, height, width, sobel_data);
      write_grayscale_bmp32("../images/stage2_sobel.bmp", header, offset, sobel_data);

      /// Non-maximum suppression
      non_maximum_suppressor(sobel_data, height, width, nms_data);
      write_grayscale_bmp32("../images/stage3_nonmax_suppression.bmp", header, offset, nms_data);

      /// Hysteresis
      hysteresis_filter(nms_data, height, width, h_data);
      write_grayscale_bmp32("../images/stage4_hysteresis.bmp", header, offset, h_data);

      // Setting output data to rgb_data to have the original pixel values in our final image output
      output_data32 = rgb_data32;
      // Hough Transform
      hough_transform32(h_data, height, width, output_data32);
      write_bmp32("../images/stage5_hough.bmp", header, offset, output_data32);
   }
	

	return 0;
}


