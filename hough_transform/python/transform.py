import cv2
import numpy as np

# Load the image
image = cv2.imread('/home/uko9054/ce392/CE392-Assignments/hough_transform/python/1.png')

# Convert it to grayscale
gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

cv2.imwrite('gray.png', gray)


# Apply Canny edge detection
edges = cv2.Canny(gray, 100, 150, apertureSize=3)

cv2.imwrite('edges.png', edges)

# Use HoughLinesP to detect lines
# Parameters: image, rho accuracy, theta accuracy, threshold
# rho and theta are in pixel and radian units respectively, threshold is the minimum vote for it to be considered a line
lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 100, minLineLength=100, maxLineGap=10)

# Draw lines on the original image
for line in lines:
    x1, y1, x2, y2 = line[0]
    cv2.line(image, (x1, y1), (x2, y2), (0, 255, 0), 2)

# Display the result
cv2.imwrite('output.png', image)
