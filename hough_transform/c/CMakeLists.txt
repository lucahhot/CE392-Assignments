cmake_minimum_required(VERSION 3.10)

project(MAIN) # Define the project name

add_executable(main main.c common.c hough_transform.c)

target_link_libraries(main m)
