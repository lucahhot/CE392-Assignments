

#add wave -noupdate -group canny_edgedetect_tb
#add wave -noupdate -group canny_edgedetect_tb -radix hexadecimal /canny_edgedetect_tb/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/grayscale_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/grayscale_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/grayscale_inst/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/gaussian_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/gaussian_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/gaussian_inst/*

# add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/sobel_inst
# add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/sobel_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/sobel_inst/*

# add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/nms_inst
# add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/nms_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/nms_inst/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_image_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_image_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/fifo_image_inst/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_gaussian_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_gaussian_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/fifo_gaussian_inst/*

# add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_sobel_inst
# add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_sobel_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/fifo_sobel_inst/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_nms_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_nms_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/fifo_nms_inst/*

add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_img_out_inst
add wave -noupdate -group canny_edgedetect_tb/canny_edgedetect_inst/fifo_img_out_inst -radix hexadecimal /canny_edgedetect_tb/canny_edgedetect_inst/fifo_img_out_inst/*

