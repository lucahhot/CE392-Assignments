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


img_height, img_width = edges.shape

theta_max = 90
theta_min = -90
thetas = np.deg2rad(np.arange(theta_min, theta_max))
rho_max = int(np.round(np.sqrt(img_height**2 + img_width ** 2)))
accumulator = np.zeros((2 * rho_max, len(thetas)), dtype=np.uint64)

for y in range(img_height):
    for x in range(img_width):
        if edges[y, x] > 0:  # Edge pixel
            for theta in range(len(thetas)):
                rho = int((x * np.cos(thetas[theta])) + (y * np.sin(thetas[theta]))) + rho_max
                accumulator[rho, theta] += 1
                
threshold = 200  # Threshold of votes to be considered a line
lines = np.where(accumulator > threshold)

for rho_minus_rho_max, theta in zip(*lines):
    rho = rho_minus_rho_max - rho_max
    a = np.cos(thetas[theta])
    b = np.sin(thetas[theta])
    x0 = (a * rho)
    y0 = (b * rho)
    x1 = int(x0 + 1000 * (-b))
    y1 = int(y0 + 1000 * (a))
    x2 = int(x0 - 1000 * (-b))
    y2 = int(y0 - 1000 * (a))
    
    cv2.line(image, (x1, y1), (x2, y2), (255, 0, 0), 2)

# lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 100, minLineLength=100, maxLineGap=10)

# # Draw lines on the original image
# for line in lines:
#     x1, y1, x2, y2 = line[0]
#     cv2.line(image, (x1, y1), (x2, y2), (0, 255, 0), 2)

# Display the result
cv2.imwrite('output.png', image)
