#include "hough_transform.h"
#include "common.h"

#define ORIGIN_IMAGE_PATH "/home/uko9054/ce392/CE392-Assignments/hough_transform/c/img_out.bmp"
#define EDGE_IMAGE_PATH "/home/uko9054/ce392/CE392-Assignments/hough_transform/c/edges.bmp"

int main(){
  struct pixel *base_frame;
  struct pixel *edge_frame;

  unsigned char header_base[64];
  unsigned char header_edge[64];

  FILE * base_file = fopen(ORIGIN_IMAGE_PATH,"rb");
	if ( base_file == NULL ) return 0;

  FILE * edge_file = fopen(EDGE_IMAGE_PATH,"rb");
	if ( edge_file == NULL ) return 0;

  int height, width;

  read_bmp(base_file, header_base, &height, &width, &base_frame);
  read_bmp(edge_file, header_edge, &height, &width, &edge_frame);

  // draw_a_line(height, width, 100, 0, 1, edge_frame, base_frame);

  // hough_transform(height, width, edge_frame, base_frame);

  write_bmp("img_out.bmp", header_base, base_frame);

  return 0;
}
