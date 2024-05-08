# SDRAM Interface

This is a test project folder where I'll try and build something that can read and write to the SDRAM or DDR3 RAM on the DE10-Nano board since there is not enough BRAM on the Cyclone V FPGA. This will include a test RTL module that will trigger read and write transactions over Avalon through probably an Avalon master block (SDRAM reader) that will then connect to the SDRAM on the HPS side of the DE10-Nano through the SDRAM bridge. 

https://github.com/zangman/de10-nano/blob/master/docs/FPGA-SDRAM-Communication_-Introduction.md provides a tutorial on how to do this and I will attempt to follow this tutorial in this project folder. 

Below is a screenshot from that tutorial that shows the architecture of this mini-project: