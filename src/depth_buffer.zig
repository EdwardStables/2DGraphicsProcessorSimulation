const std = @import("std");
const types = @import("backend_types.zig");
const config = @import("backend_config.zig");

pub const DepthBuffer = struct {
    allocator: std.mem.Allocator,
    pixels: []u24,
    depths: []u4,
    allocate_new: bool,

    pub fn init(allocator: std.mem.Allocator) !DepthBuffer {
        const db = DepthBuffer{
            .allocator = allocator,
            .pixels = undefined,
            .depths = try allocator.alloc(u4, config.display_height * config.display_width),
            .allocate_new = true,
        };

        return db;
    }

    pub fn deinit(self: *DepthBuffer) void {
        //If this is set then the buffer's ownership has been relinquished
        if (!self.allocate_new) {
            self.allocator.free(self.pixels);
        }

        self.allocator.free(self.depths);
    }

    fn get_index(y: usize, x: usize) usize {
        return config.display_width * y + x;
    }

    fn zero(self: *DepthBuffer) void {
        for (0..config.display_height) |y| {
            for (0..config.display_width) |x| {
                self.pixels[get_index(y, x)] = 0;
                self.depths[get_index(y, x)] = 0;
            }
        }
    }

    pub fn run(self: *DepthBuffer, pixel: types.ColourToDepthBuffer) !?types.DepthBufferToFrameBuffer {
        if (self.allocate_new) {
            self.pixels = try self.allocator.alloc(u24, config.display_height * config.display_width);
            self.zero();
            self.allocate_new = false;
        }

        const ind = DepthBuffer.get_index(pixel.y, pixel.x);

        //TODO consider alpha
        if (pixel.depth >= self.depths[ind]) {
            var new_colour: u32 = pixel.b;
            new_colour |= (pixel.g << 8);
            new_colour |= (pixel.r << 16);
        }

        if (pixel.barrier != types.Barrier.last) return null;

        self.allocate_new = true;

        return types.DepthBufferToFrameBuffer{ .pixels = self.pixels };
    }
};

const expect = std.testing.expect;
const ta = std.testing.allocator;

test "idle cleanup" {
    var db = try DepthBuffer.init(ta);
    defer db.deinit();
}
