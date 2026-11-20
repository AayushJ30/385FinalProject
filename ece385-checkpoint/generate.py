from pathlib import Path

*xys, color = map(int, Path("scene.txt").read_text().split())
assert len(xys) == 6 and all(-8192 <= x <= 8191 for x in xys) and 0 <= color <= 255
Path("scene.h").write_text(
    "const Triangle demo = {{" +
    ", ".join("{%d, %d}" % tuple(xys[i:i+2]) for i in (0, 2, 4)) +
    "}, %d};\n" % color
)
Path("scene.svh").write_text(
    "\n".join(f"localparam logic signed [15:0] {name} = 16'sh{v & 65535:04x};"
              for name, v in zip(("X0", "Y0", "X1", "Y1", "X2", "Y2"), xys)) +
    f"\nlocalparam logic [7:0] COLOR = 8'd{color};\n"
)
