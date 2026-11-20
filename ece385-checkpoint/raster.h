#pragma once
#include <stdint.h>

enum { WIDTH = 320, HEIGHT = 240, PIXELS = WIDTH * HEIGHT };
typedef struct { int16_t x, y; } Vertex;
typedef struct { Vertex v[3]; uint8_t color; } Triangle;
typedef struct { uint32_t tested, covered; } Stats;
extern const Triangle demo;
Stats rasterize(const Triangle *triangle, volatile uint8_t *pixels);
