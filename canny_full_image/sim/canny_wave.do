

add wave -noupdate -group canny_tb
add wave -noupdate -group canny_tb -radix hexadecimal /canny_tb/*

add wave -noupdate -group canny_tb/canny_top_inst
add wave -noupdate -group canny_tb/canny_top_inst -radix hexadecimal /canny_tb/canny_top_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/img_grayscale_inst
add wave -noupdate -group canny_tb/canny_top_inst/img_grayscale_inst -radix hexadecimal /canny_tb/canny_top_inst/img_grayscale_inst/*

# add wave -noupdate -group canny_tb/canny_top_inst/gaussian_inst
# add wave -noupdate -group canny_tb/canny_top_inst/gaussian_inst -radix hexadecimal /canny_tb/canny_top_inst/gaussian_inst/*

# add wave -noupdate -group canny_tb/canny_top_inst/gaussian_inst/divider_inst
# add wave -noupdate -group canny_tb/canny_top_inst/gaussian_inst/divider_inst -radix hexadecimal /canny_tb/canny_top_inst/gaussian_inst/divider_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/sobel_inst
add wave -noupdate -group canny_tb/canny_top_inst/sobel_inst -radix hexadecimal /canny_tb/canny_top_inst/sobel_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/nms_inst
add wave -noupdate -group canny_tb/canny_top_inst/nms_inst -radix hexadecimal /canny_tb/canny_top_inst/nms_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/hysteresis_inst
add wave -noupdate -group canny_tb/canny_top_inst/hysteresis_inst -radix hexadecimal /canny_tb/canny_top_inst/hysteresis_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/fifo_image_inst
add wave -noupdate -group canny_tb/canny_top_inst/fifo_image_inst -radix hexadecimal /canny_tb/canny_top_inst/fifo_image_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/fifo_gaussian_inst
add wave -noupdate -group canny_tb/canny_top_inst/fifo_gaussian_inst -radix hexadecimal /canny_tb/canny_top_inst/fifo_gaussian_inst/*

# add wave -noupdate -group canny_tb/canny_top_inst/fifo_sobel_inst
# add wave -noupdate -group canny_tb/canny_top_inst/fifo_sobel_inst -radix hexadecimal /canny_tb/canny_top_inst/fifo_sobel_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/fifo_nms_inst
add wave -noupdate -group canny_tb/canny_top_inst/fifo_nms_inst -radix hexadecimal /canny_tb/canny_top_inst/fifo_nms_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/fifo_hysteresis_inst
add wave -noupdate -group canny_tb/canny_top_inst/fifo_hysteresis_inst -radix hexadecimal /canny_tb/canny_top_inst/fifo_hysteresis_inst/*

add wave -noupdate -group canny_tb/canny_top_inst/fifo_img_out_inst
add wave -noupdate -group canny_tb/canny_top_inst/fifo_img_out_inst -radix hexadecimal /canny_tb/canny_top_inst/fifo_img_out_inst/*

