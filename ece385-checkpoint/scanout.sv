module scanout (
    input logic pixel_clk, reset, ready,
    input logic [7:0] scan_pixel,
    output logic [16:0] scan_addr,
    output logic [3:0] red, green, blue,
    output logic hsync, vsync, active
);
    logic [9:0] x, y;
    (* ASYNC_REG = "TRUE" *) logic ready_meta, ready_sync;
    logic show_frame;
    wire visible = x < 640 && y < 480;
    assign scan_addr = visible ? 17'(y[9:1] * 320 + x[9:1]) : 17'd0;
    assign red   = active && show_frame ? {scan_pixel[7:5], scan_pixel[7]} : 4'd0;
    assign green = active && show_frame ? {scan_pixel[4:2], scan_pixel[4]} : 4'd0;
    assign blue  = active && show_frame ? {scan_pixel[1:0], scan_pixel[1:0]} : 4'd0;

    always_ff @(posedge pixel_clk)
        if (reset) begin
            x <= 0;
            y <= 0;
            ready_meta <= 0;
            ready_sync <= 0;
            show_frame <= 0;
            hsync <= 1;
            vsync <= 1;
            active <= 0;
        end else begin
            ready_meta <= ready;
            ready_sync <= ready_meta;
            if (x == 799) begin
                x <= 0;
                if (y == 524) begin
                    y <= 0;
                    show_frame <= ready_sync;
                end else y <= y + 1'b1;
            end else x <= x + 1'b1;
            active <= visible;
            hsync <= !(x >= 656 && x < 752);
            vsync <= !(y >= 490 && y < 492);
        end
endmodule
