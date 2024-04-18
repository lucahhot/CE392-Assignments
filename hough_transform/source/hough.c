#include "hough.h"

// Function to draw/highlight hough lines on original image
int draw_lines24(int width, int rho, float sin_val, float cos_val, struct pixel24 * mask, struct pixel24* image_out, int rho_resolution)
{
	int cycle_count = 0;
	// K_START and K_END are arbitrary values that we need to set as constants
   	for(int k = K_START; k < K_END; k++){
		// Need to multiply by rho_resolution to get the correct cartesian values since we divide by it in the hough transform
		int x = (int)((rho * cos_val) + k * (-sin_val))*rho_resolution;
		int y = (int)((rho * sin_val) + k * (cos_val))*rho_resolution;

		// Check that the pixel is inside the mask (will naturally be inside the image if this is the case)
		if (mask[y*width + x].r == 0xFF && mask[y*width + x].g == 0xFF && mask[y*width + x].b == 0xFF) {

			int offset_width = 8;

			// Highlighting left and right of the main pixel, and 1 pixel above and below
			for (int offset = -offset_width; offset < offset_width; offset++){
				// Middle row
				image_out[y*width + x + offset].r = 0xFF;
				image_out[y*width + x + offset].g = 0x00;
				image_out[y*width + x + offset].b = 0x00;
				cycle_count++;
			}
		} else {
			cycle_count++;
		}
   	}
	return cycle_count;
}

int hough_transform24(unsigned char *hysteresis_data, struct pixel24 * mask, int height, int width, struct pixel24 *image_out)
{
	// Total cycle count to return (to try and measure algorithm performance)
	int cycle_count = 0;
	// The rho resolution (in number of pixels). 1 is best resolution. (Tried 2 but the line edges are pretty jagged)
	int RHO_RESOLUTION = 1;
	// Adjusting the height and width to reduce the number of cycles 
	int height_adjusted = height*MASK_TR_Y; // y value of the top right corner of the mask
	int width_adjusted = width*MASK_BR_X; // x value of the bottom right corner of the mask
	printf("\nAdjusted Height = %d, Adjusted Width = %d\n", height_adjusted, width_adjusted);
	// Originally have RHOS = diagnonal length of the image, but reducing it to reduce the number of cycles
	int RHOS = (int)(sqrt(height_adjusted*height_adjusted + width_adjusted*width_adjusted)/RHO_RESOLUTION);
	printf("Rho Range = -%d to %d\n", RHOS, RHOS);
	int rho_range = RHOS*2;
	// How many values of theta do we go through? Do 180/128 = 1.40625 degree resolution.
	int THETAS = 180; 
	int n = 0;
	unsigned short accum_buff[rho_range][THETAS];
	
	// Setting accum_buff to all zeroes
	for (int j = 0; j < rho_range; j++)
		for (int i = 0; i < THETAS; i++)
			accum_buff[j][i] = 0;
	
	// #pragma ivdep

	// y starts from the bottom of the mask to the top of the mask
	int starting_y = 0;
	// x starts from the left of the mask to the right of the mask
	int starting_x = width*MASK_BL_X;
	printf("\nStarting y index = %d, Ending y index = %d\n", starting_y, height_adjusted);
	printf("Starting x index = %d, Ending x index = %d\n", starting_x, width_adjusted);

	for (int y = starting_y; y < height_adjusted; y++){
		// #pragma ivdep
		for (int x = starting_x; x < width_adjusted; x++){
			// If the pixel is inside the mask only
			if (mask[y*width + x].r == 0xFF && mask[y*width + x].g == 0xFF && mask[y*width + x].b == 0xFF){
				if (hysteresis_data[y*width + x] != 0){ // If the pixel is an edge pixel (ie. not 0 or pure black)
					// #pragma unroll 8
					for (int theta = 0; theta < THETAS; theta++){
						int rho = (x/RHO_RESOLUTION)*cosvals[theta] + (y/RHO_RESOLUTION)*sinvals[theta];
						accum_buff[rho+RHOS/RHO_RESOLUTION][theta] += 1;
						cycle_count++;
					}
				} else{
					cycle_count++;
				}
			} else {
				cycle_count++;
			}		
		}
	}

	// // Array to hold the rho and theta values of the lines that meet the threshold
	int left_rhos[100]; // Technically there can be rho_range*THETAS number of lines but bringing this down because of a segfault error
	int left_thetas[100];
	int left_index = 0;
	int right_rhos[100];
	int right_thetas[100];
	int right_index = 0;

	// Accumulate the lines that pass a certain threshold 
	for(int i = 0; i < rho_range; i++){
		for(int j = 0; j < THETAS; j++){
			if(accum_buff[i][j] >= HOUGH_TRANSFORM_THRESHOLD){
				int margin = 10;
				// Left lanes (since thetas around 90 are essentially horizontal lines, we want to have a bit of margin)
				if (j > (90 + margin)){
					left_rhos[left_index] = i-RHOS/RHO_RESOLUTION;
					left_thetas[left_index] = j;
					left_index++;
				// Right lanes
				} else if (j < (90 - margin)){
					right_rhos[right_index] = i-RHOS/RHO_RESOLUTION;
					right_thetas[right_index] = j;
					right_index++;
				}
				cycle_count++;
			} else {
				cycle_count++;
			}
		}
	}

	printf("\nNumber of lines detected = %d\n", left_index + right_index);

	// Printing out the rho and theta values of the lines that meet the threshold
	for (int i = 0; i < left_index; i++){
		printf("Detected Left Line %d: Theta = %d, Rho = %d\n", i, left_thetas[i], left_rhos[i]);
	}
	for (int i = 0; i < right_index; i++){
		printf("Detected Right Line %d: Theta = %d, Rho = %d\n", i, right_thetas[i], right_rhos[i]);
	}

	// Now we have to select a left and a right line to draw
	int left_theta = 0; 
	int left_rho = 0;
	int right_theta = 0; 
	int right_rho = 0;

	// Variables to keep track of the best lines
	int difference = 180;
	int best_left_index = 0;
	int best_right_index = 0;

	// Finding the left and right lines which have the most symmetric thetas with respect to the y axis
	// This is how we're going to simply choose our left and right lanes. 
	// for (int left = 0; left < left_index; left++){
	// 	for (int right = 0; right < right_index; right++){
	// 		if (abs((180-left_thetas[left]) - (90-right_thetas[right])) < difference){
	// 			difference = abs(abs(90-left_thetas[left]) - (90-right_thetas[right]));
	// 			// printf("Difference = %d\n", difference);
	// 			left_theta = left_thetas[left];
	// 			left_rho = left_rhos[left];
	// 			right_theta = right_thetas[right];
	// 			right_rho = right_rhos[right];
	// 			cycle_count++;
	// 		} else {
	// 			cycle_count++;
	// 		}
	// 		// If there are identical thetas, choosing the rho with the smallest value (might not need this)
	// 		// else if (abs((180-left_thetas[left]) - (90-right_thetas[right])) == difference){
	// 		// 	if (left_rhos[left] < left_rho){
	// 		// 		left_theta = left_thetas[left];
	// 		// 		left_rho = left_rhos[left];
	// 		// 	}
	// 		// 	if (right_rhos[right] < right_rho){
	// 		// 		right_theta = right_thetas[right];
	// 		// 		right_rho = right_rhos[right];
	// 		// 	}
	// 		// }
		
	// 	}
	// }

	// Finding the average theta and rho values of the left and right lines
	int left_theta_avg = 0;
	int left_rho_avg = 0;
	int right_theta_avg = 0;
	int right_rho_avg = 0;
	for (int i = 0; i < left_index; i++){
		left_theta_avg += left_thetas[i];
		left_rho_avg += left_rhos[i];
		cycle_count++;
	}
	for (int i = 0; i < right_index; i++){
		right_theta_avg += right_thetas[i];
		right_rho_avg += right_rhos[i];
		cycle_count++;
	}
	left_theta_avg = left_theta_avg/left_index;
	left_rho_avg = left_rho_avg/left_index;
	right_theta_avg = right_theta_avg/right_index;
	right_rho_avg = right_rho_avg/right_index;

	// At this point, we should have 2 lines to draw, if the theta equals 0, it means there is no line so we don't draw it
	if (left_theta_avg != 0) {
		printf("Drawing left line with theta = %d, rho = %d\n", left_theta_avg, left_rho_avg);
		cycle_count += draw_lines24(width, left_rho_avg, sinvals[left_theta_avg], cosvals[left_theta_avg], mask, image_out, RHO_RESOLUTION);
	}
	if (right_theta_avg != 0) {
		printf("Drawing right line with theta = %d, rho = %d\n", right_theta_avg, right_rho_avg);
		cycle_count += draw_lines24(width, right_rho_avg, sinvals[right_theta_avg], cosvals[right_theta_avg], mask, image_out, RHO_RESOLUTION);
	}

	// // At this point, we should have 2 lines to draw, if the theta equals 0, it means there is no line so we don't draw it
	// if (left_theta != 0) {
	// 	printf("Drawing left line with theta = %d, rho = %d\n", left_theta, left_rho);
	// 	cycle_count += draw_lines24(width, left_rho, sinvals[left_theta], cosvals[left_theta], mask, image_out, RHO_RESOLUTION);
	// }
	// if (right_theta != 0) {
	// 	printf("Drawing right line with theta = %d, rho = %d\n", right_theta, right_rho);
	// 	cycle_count += draw_lines24(width, right_rho, sinvals[right_theta], cosvals[right_theta], mask, image_out, RHO_RESOLUTION);
	// }

	return cycle_count;
	
}

// Function to draw/highlight hough lines on original image
void draw_lines32(int width, int rho, float sin_val, float cos_val, struct pixel32 * mask, struct pixel32* image_out)
{
	// Will adjust once the 24-bit versions are finalized
}

void hough_transform32(unsigned char *hysteresis_data, struct pixel32 * mask, int height, int width, struct pixel32 *image_out)
{
	// Will adjust once the 24-bit versions are finalized
	
}