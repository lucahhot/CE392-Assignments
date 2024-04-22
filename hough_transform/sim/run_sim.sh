#!/bin/csh

source /vol/eecs392/env/questasim.env

mkdir -p lib

vsim -c -do accum_buff_sim.do
