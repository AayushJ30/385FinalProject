module rasterizer (
    input logic clk, reset, start,
    input logic signed [15:0] x0, y0, x1, y1, x2, y2,
    input logic [7:0] color,
    output logic busy, done, wr,
    output logic [16:0] addr,
    output logic [7:0] pixel
);
    typedef enum logic [1:0] {IDLE, SETUP, WALK} State;
    State state;
    logic signed [31:0] vx[3], vy[3], dx[3], dy[3], row[3], e[3];
    int signed left, right, bottom, x, y;
    logic negative;

    function automatic int signed min3(input int signed a, b, c);
        int signed m;
        m = a < b ? a : b;
        return m < c ? m : c;
    endfunction

    function automatic int signed max3(input int signed a, b, c);
        int signed m;
        m = a > b ? a : b;
        return m > c ? m : c;
    endfunction

    function automatic int signed edge_at(input int signed ax, ay, bx, by, px, py);
        return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
    endfunction

    wire signed [31:0] lx = min3(vx[0],vx[1],vx[2]) >>> 4;
    wire signed [31:0] hx = max3(vx[0],vx[1],vx[2]) >>> 4;
    wire signed [31:0] ly = min3(vy[0],vy[1],vy[2]) >>> 4;
    wire signed [31:0] hy = max3(vy[0],vy[1],vy[2]) >>> 4;
    wire signed [31:0] lo_x = lx < 0 ? 0 : lx;
    wire signed [31:0] hi_x = hx > 319 ? 319 : hx;
    wire signed [31:0] lo_y = ly < 0 ? 0 : ly;
    wire signed [31:0] hi_y = hy > 239 ? 239 : hy;
    wire signed [31:0] area = edge_at(vx[0],vy[0],vx[1],vy[1],vx[2],vy[2]);

    assign busy = state != IDLE;
    assign wr = state == WALK &&
        (negative ? e[0] <= 0 && e[1] <= 0 && e[2] <= 0
                  : e[0] >= 0 && e[1] >= 0 && e[2] >= 0);

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            addr <= 0;
            pixel <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (start) begin
                    vx[0] <= int'(x0); vy[0] <= int'(y0);
                    vx[1] <= int'(x1); vy[1] <= int'(y1);
                    vx[2] <= int'(x2); vy[2] <= int'(y2);
                    pixel <= color;
                    state <= SETUP;
                end
                SETUP: if (!area || lo_x > hi_x || lo_y > hi_y) begin
                    done <= 1;
                    state <= IDLE;
                end else begin
                    left <= lo_x;
                    right <= hi_x;
                    bottom <= hi_y;
                    x <= lo_x;
                    y <= lo_y;
                    addr <= 17'(lo_y * 320 + lo_x);
                    negative <= area < 0;
                    for (int i = 0; i < 3; ++i) begin
                        dx[i] <= (vy[i] - vy[(i+1)%3]) * 16;
                        dy[i] <= (vx[(i+1)%3] - vx[i]) * 16;
                        row[i] <= edge_at(vx[i],vy[i],vx[(i+1)%3],vy[(i+1)%3],16*lo_x+8,16*lo_y+8);
                        e[i] <= edge_at(vx[i],vy[i],vx[(i+1)%3],vy[(i+1)%3],16*lo_x+8,16*lo_y+8);
                    end
                    state <= WALK;
                end
                WALK: if (x < right) begin
                    x <= x + 1;
                    addr <= addr + 1'b1;
                    for (int i = 0; i < 3; ++i) e[i] <= e[i] + dx[i];
                end else if (y < bottom) begin
                    x <= left;
                    y <= y + 1;
                    addr <= addr + 17'(320 - right + left);
                    for (int i = 0; i < 3; ++i) begin
                        row[i] <= row[i] + dy[i];
                        e[i] <= row[i] + dy[i];
                    end
                end else begin
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
