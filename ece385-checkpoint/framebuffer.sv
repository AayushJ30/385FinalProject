module gpu_framebuffer (
    input logic clk, reset, pixel_clk,
    input logic [16:0] scan_addr,
    output logic [7:0] scan_pixel,
    output logic ready
);
    `include "scene.svh"
    typedef enum logic [1:0] {CLEAR, LAUNCH, RENDER, READY} State;
    State state;
    logic [16:0] clear_addr, draw_addr;
    logic [7:0] draw_pixel;
    logic start, done, wr;
    (* ram_style = "block" *) logic [7:0] memory[0:76799];

    assign ready = state == READY;
    assign start = state == LAUNCH;
    rasterizer draw (
        .clk(clk),
        .reset(reset),
        .start(start),
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .color(triangle_color),
        .busy(),
        .done(done),
        .wr(wr),
        .addr(draw_addr),
        .pixel(draw_pixel)
    );

logic write_enable;
logic [16:0] write_addr;
logic [7:0] write_data;

assign write_enable = !reset && ((state == CLEAR) || wr);
assign write_addr   = (state == CLEAR) ? clear_addr : draw_addr;
assign write_data   = (state == CLEAR) ? 8'h00 : draw_pixel;

always_ff @(posedge clk)
    if (write_enable)
        memory[write_addr] <= write_data;
    always_ff @(posedge pixel_clk)
        scan_pixel <= memory[scan_addr];

    always_ff @(posedge clk)
        if (reset) begin
            state <= CLEAR;
            triangle_idx <= 3'd0;
            clear_addr <= 0;
        end else case (state)
            CLEAR: if (clear_addr == 76799) state <= LAUNCH;
                   else clear_addr <= clear_addr + 1'b1;
            LAUNCH: state <= RENDER;
            RENDER: if (done) begin
        if (triangle_idx == LAST_TRIANGLE) begin
        state <= READY;
    end else begin
        triangle_idx <= triangle_idx + 3'd1;;
        state <= LAUNCH;
    end
end
            READY: state <= READY;
        endcase
endmodule

module cpu_framebuffer (
    input logic bram_clk, bram_en,
    input logic [16:0] bram_addr,
    input logic [3:0] bram_we,
    input logic [31:0] bram_wrdata,
    output logic [31:0] bram_rddata,
    input logic pixel_clk,
    input logic [16:0] scan_addr,
    output logic [7:0] scan_pixel
);
    (* ram_style = "block" *) logic [31:0] memory[0:19199];
    wire [14:0] word_addr = bram_addr[16:2];
    logic [31:0] scan_word;
    logic [1:0] scan_lane;

    always_ff @(posedge bram_clk)
        if (bram_en) begin
            if (word_addr < 19200) begin
                for (int lane = 0; lane < 4; ++lane)
                    if (bram_we[lane])
                        memory[word_addr][8*lane +: 8] <= bram_wrdata[8*lane +: 8];
                bram_rddata <= memory[word_addr];
            end else bram_rddata <= 0;
        end

    always_ff @(posedge pixel_clk) begin
        scan_word <= memory[scan_addr[16:2]];
        scan_lane <= scan_addr[1:0];
    end
    assign scan_pixel = scan_word[8*scan_lane +: 8];
endmodule
