localparam logic [2:0] LAST_TRIANGLE = 3'd6;
logic [2:0] triangle_idx;
logic signed [15:0] x0, y0, x1, y1, x2, y2;
logic [7:0] triangle_color;

function automatic logic signed [15:0] fixed_coord(input int coord);
    return 16'(coord * 16);
endfunction

logic [61:0] triangle;

always_comb begin
    case (triangle_idx)
        // Ground
        3'd0: triangle = {9'd0,   9'd199, 9'd320, 9'd199, 9'd0,   9'd240, 8'h29};
        3'd1: triangle = {9'd320, 9'd199, 9'd320, 9'd240, 9'd0,   9'd240, 8'h29};

        // Trunk
        3'd2: triangle = {9'd151, 9'd151, 9'd169, 9'd151, 9'd151, 9'd213, 8'h88};
        3'd3: triangle = {9'd169, 9'd151, 9'd169, 9'd213, 9'd151, 9'd213, 8'h88};

        // Canopy, bottom to top
        3'd4: triangle = {9'd160, 9'd75,  9'd227, 9'd184, 9'd93,  9'd184, 8'h0C};
        3'd5: triangle = {9'd160, 9'd50,  9'd214, 9'd151, 9'd106, 9'd151, 8'h30};
        default:
              triangle = {9'd160, 9'd25,  9'd199, 9'd115, 9'd121, 9'd115, 8'h38};
    endcase
end

assign x0 = fixed_coord(int'(triangle[61:53]));
assign y0 = fixed_coord(int'(triangle[52:44]));
assign x1 = fixed_coord(int'(triangle[43:35]));
assign y1 = fixed_coord(int'(triangle[34:26]));
assign x2 = fixed_coord(int'(triangle[25:17]));
assign y2 = fixed_coord(int'(triangle[16:8]));
assign triangle_color = triangle[7:0];