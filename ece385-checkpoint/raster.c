#include "raster.h"
#include "scene.h"

static int edge(Vertex a, Vertex b, int x, int y)
{
    return (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x);
}

static int pixel_floor(int value)
{
    return (value - (value < 0 ? 15 : 0)) / 16;
}

Stats rasterize(const Triangle *triangle, volatile uint8_t *pixels)
{
    const Vertex *v = triangle->v;
    int left = WIDTH, top = HEIGHT, right = -1, bottom = -1;
    int area = edge(v[0], v[1], v[2].x, v[2].y);
    Stats stats = {0, 0};
    for (int i = 0; i < 3; ++i) {
        int x = pixel_floor(v[i].x), y = pixel_floor(v[i].y);
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
    }
    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (right >= WIDTH) right = WIDTH - 1;
    if (bottom >= HEIGHT) bottom = HEIGHT - 1;
    if (!area || left > right || top > bottom) return stats;

    int dx[3], dy[3], row[3];
    int sign = area < 0 ? -1 : 1;
    for (int i = 0; i < 3; ++i) {
        Vertex a = v[i], b = v[(i + 1) % 3];
        dx[i] = sign * (a.y - b.y) * 16;
        dy[i] = sign * (b.x - a.x) * 16;
        row[i] = sign * edge(a, b, 16 * left + 8, 16 * top + 8);
    }
    stats.tested = (uint32_t)((right - left + 1) * (bottom - top + 1));
    for (int y = top; y <= bottom; ++y) {
        int e0 = row[0], e1 = row[1], e2 = row[2];
        volatile uint8_t *pixel = pixels + y * WIDTH + left;
        for (int x = left; x <= right; ++x, ++pixel) {
            if (e0 >= 0 && e1 >= 0 && e2 >= 0) {
                *pixel = triangle->color;
                ++stats.covered;
            }
            e0 += dx[0];
            e1 += dx[1];
            e2 += dx[2];
        }
        for (int i = 0; i < 3; ++i) row[i] += dy[i];
    }
    return stats;
}
