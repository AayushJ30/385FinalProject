# ECE 385 first checkpoint

Run `python3 generate.py` after editing the six coordinates and RGB332 color in
`scene.txt`. Coordinates are signed 14-bit raw values with four fractional bits,
sign-extended to 16 bits. Pixels are sampled at their centers. Each rasterizer
accepts both windings and includes points on the triangle boundary.

Run `python3 test.py` with a C compiler, Icarus Verilog and Python 3. Nine
triangles are checked against an independent Python reference. The default scene
tests 42,716 pixels and covers 19,660 pixels. The RTL spends 42,717 clocks
between accepting start and asserting done.

## GPU board

In Vivado, target xc7s50csga324-1 and add rasterizer.sv, framebuffer.sv,
scanout.sv, urbana.sv, and scene.svh. Set the include directory to the project
source directory and the top to gpu_top. Add urbana.xdc. Reuse the ECE 385
clk_wiz_0 and hdmi_tx_0 (4-bit color, active-high reset) module IP. Configure
the wizard for 100 MHz input and 25.2/126 MHz output, or the course 25/125 MHz
pair. The first output is the pixel clock. Check implementation timing and
program the board. A cyan triangle should appear after reset and frame handoff.

## MicroBlaze board

Start with the course MicroBlaze UART project. Keep the CPU, AXI peripherals
and timer at 100 MHz, use little endian, and place the framebuffer in
uncacheable peripheral space. Add the same HDL and clock/HDMI IP, using
urbana_video and cpu_framebuffer as module references in the block design.
Wire the video module to the board clock, active-high button reset and HDMI.
Wire pixel_clk, scan_addr and scan_pixel between the video and framebuffer
modules. Tie ready to a single 1-bit AXI GPIO output that defaults to zero.
The video module's render_reset output may be left open.

Add a 32-bit, single-port AXI BRAM Controller with ECC disabled and a
128 KiB aligned address window. Wire native clock, enable, byte address
(bits 16:0), byte enables, write data and read data to the cpu_framebuffer
bram_* ports. Add an AXI Timer and connect both peripherals and the GPIO
to the processor data interconnect and reset controller. Merge the HDMI
pin constraints into the existing XDC, preserving its UART/reset circuitry.
Validate, build, and export the XSA including bitstream.

Build raster.c and microblaze_main.c with the Vitis standalone BSP and its
platform.c/platform.h at -O2. Include raster.h and the generated scene.h.
Replace any template main. Override FRAMEBUFFER_BASE, TIMER_BASE and
READY_BASE if the xparameters.h names differ. Program the FPGA and run
the ELF with the UART open. Expect the same cyan triangle and printed
cycles/tested pixel and cycles/covered pixel. Elapsed microseconds are
cycles divided by 100. Timer reads bracket the rasterizer only, with the
clear, scanout handoff and UART outside the timed region.

Both designs store one 320x240 RGB332 frame, about 19 RAMB36 equivalents,
and display it at 2x scale. The memory is written once before the ready
signal lets scanout reveal it at a frame boundary. FPGA timing, physical
HDMI output and MicroBlaze measurements require the lab setup.
