from ctypes import CDLL, POINTER, Structure, byref, c_int16, c_uint8, c_uint32
from pathlib import Path
import subprocess
import tempfile

class Vertex(Structure):
    _fields_ = [("x", c_int16), ("y", c_int16)]

class Triangle(Structure):
    _fields_ = [("v", Vertex * 3), ("color", c_uint8)]

class Stats(Structure):
    _fields_ = [("tested", c_uint32), ("covered", c_uint32)]

def run(*args):
    subprocess.run(args, check=True)

with tempfile.TemporaryDirectory() as work:
    work = Path(work)
    run("cc", "-Wall", "-Wextra", "-Werror", "-O2", "-shared", "-fPIC",
        "raster.c", "-o", str(work / "raster.so"))
    lib = CDLL(str(work / "raster.so"))
    lib.rasterize.argtypes = [POINTER(Triangle), POINTER(c_uint8)]
    lib.rasterize.restype = Stats
    scene = tuple(map(int, Path("scene.txt").read_text().split()))
    cases = [
        scene, (*scene[:2], *scene[4:6], *scene[2:4], scene[6]),
        (-119,-37,365,49,12,301,124), (5000,3720,5300,3710,5136,3900,255),
        (-64,-64,-32,-48,-40,-9,81), (16,16,32,32,48,48,85),
        (8,8,120,8,8,120,232), (1,1,3,1,1,3,255),
        (-8192,-8192,8191,-8192,8191,8191,165)
    ]
    tb = """module tb;
    logic clk=0, reset=1, start=0;
    always #5 clk=~clk;
    logic signed [15:0] x0,y0,x1,y1,x2,y2;
    logic [7:0] color,pixel;
    logic busy,done,wr;
    logic [16:0] addr;
    rasterizer dut (.*);
    logic [7:0] actual[0:76799], expected[0:76799];
    task automatic check(input int a,b,c,d,e,f,g,tested,covered,input string expected_path);
        int ticks, writes;
        {x0,y0,x1,y1,x2,y2,color}={16'(a),16'(b),16'(c),16'(d),16'(e),16'(f),8'(g)};
        for(int i=0;i<76800;i++) actual[i]=0;
        $readmemh(expected_path,expected);
        ticks=0;
        writes=0;
        start=1;
        @(negedge clk);
        start=0;
        while(!done) begin
            if(!busy || ticks>76801) $fatal(1,"Handshake");
            if(wr) begin
                if(addr>=76800 || actual[addr]!=0) $fatal(1,"Write address");
                actual[addr]=pixel;
                writes++;
            end
            ticks++;
            @(negedge clk);
        end
        if(busy || ticks!=tested+1 || writes!=covered) $fatal(1,"Counters");
        for(int i=0;i<76800;i++)
            if(actual[i]!==expected[i]) $fatal(1,"Pixel %0d",i);
    endtask
    initial begin
        repeat(2) @(negedge clk);
        reset=0;
    """
    for i, case in enumerate(cases):
        points = list(zip(case[:6:2], case[1:6:2]))
        edges = list(zip(points, points[1:] + points[:1]))
        def cross(a, b, x, y):
            return (b[0]-a[0])*(y-a[1]) - (b[1]-a[1])*(x-a[0])
        area = cross(*edges[0], *points[2])
        expected = bytes(case[6] if area and all(
            cross(a,b,16*x+8,16*y+8)*area >= 0 for a,b in edges) else 0
            for y in range(240) for x in range(320))
        left = max(0, min(x for x,_ in points)//16)
        right = min(319, max(x for x,_ in points)//16)
        top = max(0, min(y for _,y in points)//16)
        bottom = min(239, max(y for _,y in points)//16)
        tested = max(0,right-left+1)*max(0,bottom-top+1) if area else 0
        covered = sum(bool(p) for p in expected)
        tri = Triangle.in_dll(lib, "demo") if i == 0 else Triangle(
            (Vertex * 3)(*(Vertex(*p) for p in points)), case[6])
        pixels = (c_uint8 * 76800)()
        stats = lib.rasterize(byref(tri), pixels)
        assert bytes(pixels) == expected and (stats.tested, stats.covered) == (tested, covered), i
        path = work / f"expected{i}.hex"
        path.write_text("".join(f"{p:02x}\n" for p in expected))
        args = ",".join(map(str, (*case, tested, covered)))
        tb += f'check({args},"{path}");\n'
        if i == 0:
            print(f"Demo: {tested} tested, {covered} covered", flush=True)
    (work / "tb.sv").write_text(tb + '$display("Nine RTL and C cases passed"); $finish; end endmodule\n')
    run("iverilog", "-Wall", "-g2012", "-s", "tb", "-o", str(work / "tb"),
        "rasterizer.sv", str(work / "tb.sv"))
    run("vvp", str(work / "tb"))
