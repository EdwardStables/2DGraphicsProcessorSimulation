const std = @import("std");
const types = @import("backend_types.zig");
const system_config = @import("system_config.zig");

pub const DepthBuffer = struct {
    allocator: std.mem.Allocator,
    pixels: []u24,
    depths: []u4,
    allocate_new: bool,
    config: *system_config.Config,

    pub fn init(allocator: std.mem.Allocator, config: *system_config.Config) !DepthBuffer {
        const db = DepthBuffer{
            .allocator = allocator,
            .pixels = undefined,
            .depths = try allocator.alloc(u4, config.display_height * config.display_width),
            .allocate_new = true,
            .config = config,
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

    fn getIndex(config: *system_config.Config, y: usize, x: usize) usize {
        return config.display_width * y + x;
    }

    fn zero(self: *DepthBuffer) void {
        for (0..self.config.display_height) |y| {
            for (0..self.config.display_width) |x| {
                self.pixels[getIndex(self.config, y, x)] = 0;
                self.depths[getIndex(self.config, y, x)] = 0;
            }
        }
    }

    pub fn run(self: *DepthBuffer, pixel: types.ColourToDepthBuffer) !?types.FrameBuffer {
        if (self.allocate_new) {
            self.pixels = try self.allocator.alloc(u24, self.config.display_height * self.config.display_width);
            self.zero();
            self.allocate_new = false;
        }

        const ind = DepthBuffer.getIndex(self.config, pixel.y, pixel.x);

        //TODO consider alpha
        if (!pixel.nulled and pixel.depth >= self.depths[ind]) {
            var new_colour: u24 = pixel.b;
            new_colour |= (@as(u24, pixel.g) << 8);
            new_colour |= (@as(u24, pixel.r) << 16);
            self.pixels[ind] = new_colour;
            self.depths[ind] = pixel.depth;
        }

        if (pixel.barrier != types.Barrier.last) return null;

        self.allocate_new = true;

        return types.FrameBuffer{
            .kick_id = pixel.kick_id,
            .width = self.config.display_width,
            .height = self.config.display_height,
            .pixels = self.pixels,
            .allocator = self.allocator,
        };
    }
};

const expect = std.testing.expect;
const ta = std.testing.allocator;
var test_config = system_config.Config{};

test "idle cleanup" {
    var db = try DepthBuffer.init(ta, &test_config);
    defer db.deinit();
}

test "write one pixel" {
    var db = try DepthBuffer.init(ta, &test_config);
    defer db.deinit();

    const pixel = types.ColourToDepthBuffer{
        .kick_id = 3,
        .object_id = 4,
        .nulled = false,
        .barrier = types.Barrier.last,
        .x = 0,
        .y = 0,
        .depth = 0,
        .r = 0xFF,
        .g = 0xFF,
        .b = 0xFF,
        .a = 0xFF,
    };

    var buffer = (try db.run(pixel)).?;
    defer buffer.deinit();

    try expect(buffer.kick_id == pixel.kick_id);
    try expect(buffer.pixels[0] == @as(u24, 0xFFFFFF));

    for (0..test_config.display_height) |y| {
        for (0..test_config.display_width) |x| {
            if (y == 0 and x == 0) continue;
            try expect(buffer.pixels[DepthBuffer.getIndex(&test_config, y, x)] == 0);
        }
    }
}

test "multiple writes" {
    var db = try DepthBuffer.init(ta, &test_config);
    defer db.deinit();

    var pixel = types.ColourToDepthBuffer{
        .kick_id = 3,
        .object_id = 4,
        .nulled = false,
        .barrier = types.Barrier.none,
        .x = 0,
        .y = 0,
        .depth = 0,
        .r = 0xFF,
        .g = 0xFF,
        .b = 0xFF,
        .a = 0xFF,
    };

    try expect(try db.run(pixel) == null);

    pixel.barrier = types.Barrier.last;
    pixel.x = 1;

    var buffer = (try db.run(pixel)).?;
    defer buffer.deinit();
    try expect(buffer.kick_id == pixel.kick_id);
    try expect(buffer.pixels[0] == @as(u24, 0xFFFFFF));
    try expect(buffer.pixels[1] == @as(u24, 0xFFFFFF));

    for (0..test_config.display_height) |y| {
        for (0..test_config.display_width) |x| {
            if (y == 0 and x == 0) continue;
            if (y == 0 and x == 1) continue;
            try expect(buffer.pixels[DepthBuffer.getIndex(&test_config, y, x)] == 0);
        }
    }
}

test "nulled pixel doesn't write" {
    var db = try DepthBuffer.init(ta, &test_config);
    defer db.deinit();

    const pixel = types.ColourToDepthBuffer{
        .kick_id = 3,
        .object_id = 4,
        .nulled = true,
        .barrier = types.Barrier.last,
        .x = 0,
        .y = 0,
        .depth = 0,
        .r = 0xFF,
        .g = 0xFF,
        .b = 0xFF,
        .a = 0xFF,
    };

    var buffer = (try db.run(pixel)).?;
    defer buffer.deinit();

    try expect(buffer.kick_id == pixel.kick_id);
    for (0..test_config.display_height) |y| {
        for (0..test_config.display_width) |x| {
            try expect(buffer.pixels[DepthBuffer.getIndex(&test_config, y, x)] == 0);
        }
    }
}

test "depth override" {
    var db = try DepthBuffer.init(ta, &test_config);
    defer db.deinit();

    var pixel = types.ColourToDepthBuffer{
        .kick_id = 3,
        .object_id = 4,
        .nulled = false,
        .barrier = types.Barrier.none,
        .x = 0,
        .y = 0,
        .depth = 0,
        .r = 0xFF,
        .g = 0xFF,
        .b = 0xFF,
        .a = 0xFF,
    };

    try expect(try db.run(pixel) == null);

    pixel.barrier = types.Barrier.last;
    pixel.depth = 1;
    pixel.r = 0xDD;
    pixel.g = 0xDD;
    pixel.b = 0xDD;

    var buffer = (try db.run(pixel)).?;
    defer buffer.deinit();
    try expect(buffer.kick_id == pixel.kick_id);
    try expect(buffer.pixels[0] == @as(u24, 0xDDDDDD));

    for (0..test_config.display_height) |y| {
        for (0..test_config.display_width) |x| {
            if (y == 0 and x == 0) continue;
            try expect(buffer.pixels[DepthBuffer.getIndex(&test_config, y, x)] == 0);
        }
    }
}

test "multiple kicks" {
    var db = try DepthBuffer.init(ta, &test_config);
    defer db.deinit();

    var pixel = types.ColourToDepthBuffer{
        .kick_id = 3,
        .object_id = 4,
        .nulled = false,
        .barrier = types.Barrier.last,
        .x = 0,
        .y = 0,
        .depth = 0,
        .r = 0xFF,
        .g = 0xFF,
        .b = 0xFF,
        .a = 0xFF,
    };

    var buffer1 = (try db.run(pixel)).?;
    defer buffer1.deinit();
    try expect(buffer1.kick_id == pixel.kick_id);
    try expect(buffer1.pixels[0] == @as(u24, 0xFFFFFF));

    for (0..test_config.display_height) |y| {
        for (0..test_config.display_width) |x| {
            if (y == 0 and x == 0) continue;
            try expect(buffer1.pixels[DepthBuffer.getIndex(&test_config, y, x)] == 0);
        }
    }

    pixel.kick_id = 4;
    pixel.r = 0xDD;
    pixel.g = 0xDD;
    pixel.b = 0xDD;

    var buffer2 = (try db.run(pixel)).?;
    defer buffer2.deinit();
    try expect(buffer2.kick_id == pixel.kick_id);
    try expect(buffer2.pixels[0] == @as(u24, 0xDDDDDD));

    for (0..test_config.display_height) |y| {
        for (0..test_config.display_width) |x| {
            if (y == 0 and x == 0) continue;
            try expect(buffer2.pixels[DepthBuffer.getIndex(&test_config, y, x)] == 0);
        }
    }
}
