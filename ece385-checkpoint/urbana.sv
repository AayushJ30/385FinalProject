module urbana_video (
    input logic Clk, reset_rtl_0, ready,
    input logic [7:0] scan_pixel,
    output logic pixel_clk, render_reset,
    output logic [16:0] scan_addr,
    output logic hdmi_tmds_clk_p, hdmi_tmds_clk_n,
    output logic [2:0] hdmi_tmds_data_p, hdmi_tmds_data_n
);
    wire pclk, sclk, locked;
    wire reset_async = reset_rtl_0 || !locked;
    (* ASYNC_REG = "TRUE" *) logic [1:0] pixel_rst, render_rst;
    logic [3:0] red, green, blue;
    logic hsync, vsync, active;

    assign pixel_clk = pclk;
    assign render_reset = render_rst[1];
    always_ff @(posedge pclk or posedge reset_async)
        if (reset_async) pixel_rst <= '1;
        else pixel_rst <= {pixel_rst[0], 1'b0};
    always_ff @(posedge Clk or posedge reset_async)
        if (reset_async) render_rst <= '1;
        else render_rst <= {render_rst[0], 1'b0};

    clk_wiz_0 clocks 
    (.clk_in1(Clk), 
    .reset(reset_rtl_0), 
    .locked(locked),
    .clk_out1(pclk),
    .clk_out2(sclk));


    scanout scan (.pixel_clk(pclk), .reset(pixel_rst[1]), .ready(ready),
                  .scan_pixel(scan_pixel), .scan_addr(scan_addr), .red(red),
                  .green(green), .blue(blue), .hsync(hsync), .vsync(vsync), .active(active));
    
    hdmi_tx_0 hdmi (
        .pix_clk(pclk),
        .pix_clkx5(sclk),
        .pix_clk_locked(locked),
        .rst(reset_rtl_0),
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync), 
        .vsync(vsync), 
        .vde(active), 
        .aux0_din(4'b0),
        .aux1_din(4'b0),
         .aux2_din(4'b0), 
         .ade(1'b0),
        .TMDS_CLK_P(hdmi_tmds_clk_p), .TMDS_CLK_N(hdmi_tmds_clk_n),
        .TMDS_DATA_P(hdmi_tmds_data_p), .TMDS_DATA_N(hdmi_tmds_data_n));
endmodule

module gpu_top (
    input logic Clk, reset_rtl_0,
    output logic hdmi_tmds_clk_p, hdmi_tmds_clk_n,
    output logic [2:0] hdmi_tmds_data_p, hdmi_tmds_data_n
);
wire clk_from_pin, render_clk;
wire ready, pixel_clk, render_reset;
wire [16:0] scan_addr;
wire [7:0] scan_pixel;

IBUF board_clk_in (.I(Clk), .O(clk_from_pin));
BUFG render_clk_buf (.I(clk_from_pin), .O(render_clk));

urbana_video video (
    .Clk(clk_from_pin),
    .*
);

gpu_framebuffer fb (
    .clk(render_clk),
    .reset(render_reset),
    .pixel_clk(pixel_clk),
    .scan_addr(scan_addr),
    .scan_pixel(scan_pixel),
    .ready(ready)
);
endmodule
