#include "hough_transform.h"

int is_edge(struct pixel point){
   if(point.b==255 || point.g==255 || point.r==255){
      return 1;
   }
   return 0;
}

void draw_a_line(int height, int width, int rho, double sin_theta, double cos_theta, struct pixel* edge, struct pixel* origin_image){
   printf("starting a line\n");
   double x0 = rho * cos_theta;
   double y0 = rho * sin_theta;
   for(int k=-LINE_LENGTH; k<LINE_LENGTH; k++){
      int x1 = (int)(x0 + k*(-sin_theta));
      int y1 = (int)(y0 + k *(cos_theta));

      // int index = y1*width + x1;
      if(x1>=0 && x1<width && y1>=0 && y1<height) {
         printf("%d, %d, %d\n", x1, y1, y1*width + x1);
         origin_image[y1*width + x1] = (struct pixel){0, 255, 0};
      }
      // if(x1>=0 && x1<width - 1 && y1>=0 && y1<height) {origin_image[y1*width + x1 +1 ] = (struct pixel){0, 255, 0};}
   }
}


void hough_transform(int height, int width, struct pixel* edge, struct pixel* origin_image){

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
   int **accumulator = malloc(2*rho_max*sizeof(int*));
   for(int i=0; i<2*rho_max; i++){
      accumulator[i] = malloc(Theta_range*sizeof(int));
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
         if(is_edge(edge[y*width + x])){
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
