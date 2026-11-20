`timescale 1ns/1ps

module tb;
    localparam integer WIDTH = 320;
    localparam integer HEIGHT = 240;
    localparam integer PIXELS = WIDTH * HEIGHT;
    localparam integer TRIANGLES = 7;

    logic clk = 0;
    always #5 clk = ~clk;

    logic [7:0] actual [0:PIXELS-1];
    logic [7:0] expected [0:PIXELS-1];

    function automatic integer scene_coord(input integer triangle, input integer coordinate);
        begin
            case (triangle)
                0: case (coordinate)
                    0: scene_coord = 0;    1: scene_coord = 3184;
                    2: scene_coord = 5120; 3: scene_coord = 3184;
                    4: scene_coord = 0;    default: scene_coord = 3840;
                endcase
                1: case (coordinate)
                    0: scene_coord = 5120; 1: scene_coord = 3184;
                    2: scene_coord = 5120; 3: scene_coord = 3840;
                    4: scene_coord = 0;    default: scene_coord = 3840;
                endcase
                2: case (coordinate)
                    0: scene_coord = 2416; 1: scene_coord = 2416;
                    2: scene_coord = 2704; 3: scene_coord = 2416;
                    4: scene_coord = 2416; default: scene_coord = 3408;
                endcase
                3: case (coordinate)
                    0: scene_coord = 2704; 1: scene_coord = 2416;
                    2: scene_coord = 2704; 3: scene_coord = 3408;
                    4: scene_coord = 2416; default: scene_coord = 3408;
                endcase
                4: case (coordinate)
                    0: scene_coord = 2560; 1: scene_coord = 1200;
                    2: scene_coord = 3632; 3: scene_coord = 2944;
                    4: scene_coord = 1488; default: scene_coord = 2944;
                endcase
                5: case (coordinate)
                    0: scene_coord = 2560; 1: scene_coord = 800;
                    2: scene_coord = 3424; 3: scene_coord = 2416;
                    4: scene_coord = 1696; default: scene_coord = 2416;
                endcase
                default: case (coordinate)
                    0: scene_coord = 2560; 1: scene_coord = 400;
                    2: scene_coord = 3184; 3: scene_coord = 1840;
                    4: scene_coord = 1936; default: scene_coord = 1840;
                endcase
            endcase
        end
    endfunction

    function automatic [7:0] scene_color(input integer triangle);
        begin
            case (triangle)
                0, 1: scene_color = 8'h29;
                2, 3: scene_color = 8'h88;
                4: scene_color = 8'h0c;
                5: scene_color = 8'h30;
                default: scene_color = 8'h38;
            endcase
        end
    endfunction

    function automatic integer edge_value(
        input integer ax, input integer ay, input integer bx, input integer by,
        input integer px, input integer py
    );
        edge_value = (bx - ax) * (py - ay) - (by - ay) * (px - ax);
    endfunction

    function automatic integer pixel_floor(input integer value);
        begin
            pixel_floor = (value - (value < 0 ? 15 : 0)) / 16;
        end
    endfunction

    task automatic reference_triangle(input integer triangle, input bit clear_first,
                                      output integer tested, output integer covered);
        integer x0, y0, x1, y1, x2, y2, color;
        integer left, right, top, bottom, area;
        integer x, y, e0, e1, e2, inside;
        begin
            if (clear_first)
                for (integer i = 0; i < PIXELS; ++i) expected[i] = 0;

            x0 = scene_coord(triangle, 0);
            y0 = scene_coord(triangle, 1);
            x1 = scene_coord(triangle, 2);
            y1 = scene_coord(triangle, 3);
            x2 = scene_coord(triangle, 4);
            y2 = scene_coord(triangle, 5);
            color = scene_color(triangle);
            area = edge_value(x0, y0, x1, y1, x2, y2);
            left = pixel_floor(x0);
            right = left;
            top = pixel_floor(y0);
            bottom = top;
            if (pixel_floor(x1) < left) left = pixel_floor(x1);
            if (pixel_floor(x2) < left) left = pixel_floor(x2);
            if (pixel_floor(x1) > right) right = pixel_floor(x1);
            if (pixel_floor(x2) > right) right = pixel_floor(x2);
            if (pixel_floor(y1) < top) top = pixel_floor(y1);
            if (pixel_floor(y2) < top) top = pixel_floor(y2);
            if (pixel_floor(y1) > bottom) bottom = pixel_floor(y1);
            if (pixel_floor(y2) > bottom) bottom = pixel_floor(y2);
            if (left < 0) left = 0;
            if (top < 0) top = 0;
            if (right >= WIDTH) right = WIDTH - 1;
            if (bottom >= HEIGHT) bottom = HEIGHT - 1;

            tested = 0;
            covered = 0;
            if (!area || left > right || top > bottom)
                return;

            for (y = top; y <= bottom; ++y) begin
                for (x = left; x <= right; ++x) begin
                    ++tested;
                    e0 = edge_value(x0, y0, x1, y1, 16*x + 8, 16*y + 8);
                    e1 = edge_value(x1, y1, x2, y2, 16*x + 8, 16*y + 8);
                    e2 = edge_value(x2, y2, x0, y0, 16*x + 8, 16*y + 8);
                    inside = area > 0 ? (e0 >= 0 && e1 >= 0 && e2 >= 0) :
                                         (e0 <= 0 && e1 <= 0 && e2 <= 0);
                    if (inside) begin
                        expected[y*WIDTH + x] = color;
                        ++covered;
                    end
                end
            end
        end
    endtask

    logic signed [15:0] ux0, uy0, ux1, uy1, ux2, uy2;
    logic [7:0] ucolor, upixel;
    logic unit_reset = 1, unit_start = 0;
    logic unit_busy, unit_done, unit_wr;
    logic [16:0] uaddr;
    rasterizer unit_dut (
        .clk(clk), .reset(unit_reset), .start(unit_start),
        .x0(ux0), .y0(uy0), .x1(ux1), .y1(uy1), .x2(ux2), .y2(uy2),
        .color(ucolor), .busy(unit_busy), .done(unit_done), .wr(unit_wr),
        .addr(uaddr), .pixel(upixel)
    );

    task automatic check_unit(input integer triangle);
        integer tested, covered, ticks, writes;
        begin
            reference_triangle(triangle, 1'b1, tested, covered);
            ux0 = scene_coord(triangle, 0);
            uy0 = scene_coord(triangle, 1);
            ux1 = scene_coord(triangle, 2);
            uy1 = scene_coord(triangle, 3);
            ux2 = scene_coord(triangle, 4);
            uy2 = scene_coord(triangle, 5);
            ucolor = scene_color(triangle);
            for (integer i = 0; i < PIXELS; ++i) actual[i] = 0;
            ticks = 0;
            writes = 0;
            unit_start = 1;
            @(negedge clk);
            unit_start = 0;
            while (!unit_done) begin
                if (!unit_busy || ticks > PIXELS + 1)
                    $fatal(1, "unit handshake failed for triangle %0d", triangle);
                if (unit_wr) begin
                    if (uaddr >= PIXELS || actual[uaddr] != 0)
                        $fatal(1, "unit write address failed for triangle %0d", triangle);
                    if (expected[uaddr] !== upixel)
                        $fatal(1, "unit pixel failed for triangle %0d at %0d", triangle, uaddr);
                    actual[uaddr] = upixel;
                    ++writes;
                end
                ++ticks;
                @(negedge clk);
            end
            if (unit_busy || ticks != tested + 1 || writes != covered)
                $fatal(1, "unit statistics failed for triangle %0d", triangle);
            for (integer i = 0; i < PIXELS; ++i)
                if (actual[i] !== expected[i])
                    $fatal(1, "unit framebuffer failed for triangle %0d at %0d", triangle, i);
            $display("UNIT triangle=%0d cycles=%0d tested=%0d covered=%0d writes=%0d",
                     triangle, ticks, tested, covered, writes);
        end
    endtask

    logic fb_reset = 1;
    logic [16:0] scan_addr = 0;
    logic [7:0] scan_pixel;
    logic fb_ready;
    gpu_framebuffer frame_dut (
        .clk(clk), .reset(fb_reset), .pixel_clk(clk), .scan_addr(scan_addr),
        .scan_pixel(scan_pixel), .ready(fb_ready)
    );

    integer cycle_count = 0;
    integer first_clear_cycle = -1;
    integer clear_writes = 0;
    integer triangle_start [0:TRIANGLES-1];
    integer triangle_done [0:TRIANGLES-1];
    integer triangle_tested [0:TRIANGLES-1];
    integer triangle_writes [0:TRIANGLES-1];
    integer final_done_cycle = -1;
    integer ready_cycle = -1;

    /* Count actual writes and candidate pixels at the active clock edge. */
    always @(posedge clk) begin
        if (!fb_reset) begin
            ++cycle_count;
            if (frame_dut.write_enable && frame_dut.state == 0) begin
                ++clear_writes;
                if (first_clear_cycle < 0) first_clear_cycle = cycle_count;
            end
            if (frame_dut.draw.state == 2)
                ++triangle_tested[frame_dut.triangle_idx];
            if (frame_dut.write_enable && frame_dut.state != 0 && frame_dut.draw.wr)
                ++triangle_writes[frame_dut.triangle_idx];
        end
        #1;
        if (!fb_reset) begin
            if (frame_dut.state == 1)
                triangle_start[frame_dut.triangle_idx] = cycle_count;
            if (frame_dut.draw.done) begin
                triangle_done[frame_dut.triangle_idx] = cycle_count;
                if (frame_dut.triangle_idx == TRIANGLES - 1)
                    final_done_cycle = cycle_count;
            end
            if (fb_ready && ready_cycle < 0)
                ready_cycle = cycle_count;
        end
    end

    initial begin
        integer ref_tested [0:TRIANGLES-1];
        integer ref_covered [0:TRIANGLES-1];
        integer total_cycles, checksum, nonzero, actual_nonzero;
        integer i, j;
        reference_triangle(0, 1'b1, ref_tested[0], ref_covered[0]);
        for (i = 1; i < TRIANGLES; ++i)
            reference_triangle(i, 1'b0, ref_tested[i], ref_covered[i]);

        for (i = 0; i < TRIANGLES; ++i) begin
            triangle_start[i] = -1;
            triangle_done[i] = -1;
            triangle_tested[i] = 0;
            triangle_writes[i] = 0;
        end

        repeat (2) @(negedge clk);
        unit_reset = 0;
        for (i = 0; i < TRIANGLES; ++i)
            check_unit(i);

        reference_triangle(0, 1'b1, ref_tested[0], ref_covered[0]);
        for (i = 1; i < TRIANGLES; ++i)
            reference_triangle(i, 1'b0, ref_tested[i], ref_covered[i]);

        fb_reset = 0;
        wait (fb_ready === 1'b1);
        #2;

        if (clear_writes != PIXELS)
            $fatal(1, "clear writes=%0d expected=%0d", clear_writes, PIXELS);
        if (final_done_cycle < 0 || first_clear_cycle < 0)
            $fatal(1, "missing integration timing markers");
        total_cycles = final_done_cycle - first_clear_cycle + 1;

        checksum = 0;
        actual_nonzero = 0;
        for (i = 0; i < PIXELS; ++i) begin
            if (frame_dut.memory[i] !== expected[i])
                $fatal(1, "integration framebuffer failed at %0d", i);
            checksum = checksum * 33 + frame_dut.memory[i];
            if (frame_dut.memory[i] != 0) ++actual_nonzero;
        end
        nonzero = 0;
        for (i = 0; i < PIXELS; ++i)
            if (expected[i] != 0) ++nonzero;

        for (j = 0; j < TRIANGLES; ++j) begin
            if (triangle_start[j] < 0 || triangle_done[j] < 0)
                $fatal(1, "missing integration timing for triangle %0d", j);
            if (triangle_tested[j] != ref_tested[j] ||
                triangle_writes[j] != ref_covered[j])
                $fatal(1, "integration statistics failed for triangle %0d", j);
            $display("FRAME triangle=%0d launch_to_done_cycles=%0d tested=%0d covered=%0d writes=%0d",
                     j, triangle_done[j] - triangle_start[j] + 1,
                     triangle_tested[j], ref_covered[j], triangle_writes[j]);
        end

        $display("FRAME clear_cycles=%0d clear_writes=%0d", clear_writes, clear_writes);
        $display("FRAME render_cycles=%0d render_time_ns=%0d ready_cycle=%0d",
                 total_cycles, total_cycles * 10, ready_cycle);
        $display("FRAME nonzero=%0d checksum=0x%08x", actual_nonzero, checksum);
        $display("SEVEN TRIANGLE HARDWARE TEST PASSED");
        $finish;
    end
endmodule
