

#add wave -noupdate -group edgedetect_tb
#add wave -noupdate -group edgedetect_tb -radix hexadecimal /edgedetect_tb/*

add wave -noupdate -group edgedetect_tb/edgedetect_inst
add wave -noupdate -group edgedetect_tb/edgedetect_inst -radix hexadecimal /edgedetect_tb/edgedetect_inst/*

add wave -noupdate -group edgedetect_tb/edgedetect_inst/grayscale_inst
add wave -noupdate -group edgedetect_tb/edgedetect_inst/grayscale_inst -radix hexadecimal /edgedetect_tb/edgedetect_inst/grayscale_inst/*

add wave -noupdate -group edgedetect_tb/edgedetect_inst/sobel_inst
add wave -noupdate -group edgedetect_tb/edgedetect_inst/sobel_inst -radix hexadecimal /edgedetect_tb/edgedetect_inst/sobel_inst/*

add wave -noupdate -group edgedetect_tb/edgedetect_inst/fifo_image_inst
add wave -noupdate -group edgedetect_tb/edgedetect_inst/fifo_image_inst -radix hexadecimal /edgedetect_tb/edgedetect_inst/fifo_image_inst/*

add wave -noupdate -group edgedetect_tb/edgedetect_inst/fifo_sobel_inst
add wave -noupdate -group edgedetect_tb/edgedetect_inst/fifo_sobel_inst -radix hexadecimal /edgedetect_tb/edgedetect_inst/fifo_sobel_inst/*

add wave -noupdate -group edgedetect_tb/edgedetect_inst/fifo_img_out_inst
add wave -noupdate -group edgedetect_tb/edgedetect_inst/fifo_img_out_inst -radix hexadecimal /edgedetect_tb/edgedetect_inst/fifo_img_out_inst/*

