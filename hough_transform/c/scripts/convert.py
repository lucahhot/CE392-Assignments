from PIL import Image

# Open the black and white BMP file
bw_image = Image.open('/home/uko9054/ce392/CE392-Assignments/hough_transform/c/1.bmp')

# Convert the black and white image to a colorful image using a colormap
color_image = bw_image.convert('RGB')

# Save the colorful image
color_image.save('1.bmp')