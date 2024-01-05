const std = @import("std");
const types = @import("backend_types.zig");
const config = @import("backend_config.zig");

const Action = types.ChildAction;

pub const Colouring = struct {
    pub fn init() Colouring {
        return Colouring{};
    }

    pub fn deinit(_: *Colouring) void {}

    fn calc_pixel(pixel: u8, child: u8, action: Action) ?u8 {
        switch (action) {
            Action.none => return pixel,
            Action.replace => return child,
            Action.cut => return null,
            Action.combine => return (pixel + child) / 2,
        }
    }

    pub fn run(_: *Colouring, pixel: types.CoallesceToColour) ?types.ColourToDepthBuffer {
        var nulled = false;
        var r = pixel.r;

        r = Colouring.calc_pixel(r, pixel.c1_r, pixel.c1_action) orelse blk: {
            nulled = true;
            break :blk 0;
        };
        r = Colouring.calc_pixel(r, pixel.c2_r, pixel.c2_action) orelse blk: {
            nulled = true;
            break :blk 0;
        };
        r = Colouring.calc_pixel(r, pixel.c3_r, pixel.c3_action) orelse blk: {
            nulled = true;
            break :blk 0;
        };

        var g = pixel.g;
        if (!nulled) {
            g = Colouring.calc_pixel(g, pixel.c1_g, pixel.c1_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
            g = Colouring.calc_pixel(g, pixel.c2_g, pixel.c2_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
            g = Colouring.calc_pixel(g, pixel.c3_g, pixel.c3_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
        } else {
            g = 0;
        }

        var b = pixel.b;
        if (!nulled) {
            b = Colouring.calc_pixel(b, pixel.c1_b, pixel.c1_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
            b = Colouring.calc_pixel(b, pixel.c2_b, pixel.c2_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
            b = Colouring.calc_pixel(b, pixel.c3_b, pixel.c3_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
        } else {
            b = 0;
        }

        var a = pixel.a;
        if (!nulled) {
            a = Colouring.calc_pixel(a, pixel.c1_a, pixel.c1_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
            a = Colouring.calc_pixel(a, pixel.c2_a, pixel.c2_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
            a = Colouring.calc_pixel(a, pixel.c3_a, pixel.c3_action) orelse blk: {
                nulled = true;
                break :blk 0;
            };
        } else {
            a = 0;
        }

        if (nulled and pixel.barrier == types.Barrier.none) return null;

        return types.ColourToDepthBuffer{
            .kick_id = pixel.kick_id,
            .object_id = pixel.object_id,

            .nulled = nulled,
            .barrier = pixel.barrier,

            .x = pixel.x,
            .y = pixel.y,
            .depth = pixel.depth,

            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

const expect = std.testing.expect;

test "pixel test" {
    try expect(Colouring.calc_pixel(1, 2, Action.none).? == 1);
    try expect(Colouring.calc_pixel(1, 2, Action.replace).? == 2);
    try expect(Colouring.calc_pixel(1, 2, Action.cut) == null);
    try expect(Colouring.calc_pixel(0, 128, Action.combine).? == 64);
}

test "run no children" {
    const pixel = types.CoallesceToColour{
        .kick_id = 0,
        .object_id = 0,
        .barrier = types.Barrier.none,
        .x = 3,
        .y = 3,
        .depth = 1,
        .r = 1,
        .g = 2,
        .b = 3,
        .a = 4,
    };
    const exp = types.ColourToDepthBuffer{
        .kick_id = pixel.kick_id,
        .object_id = pixel.object_id,
        .nulled = false,
        .barrier = pixel.barrier,
        .x = pixel.x,
        .y = pixel.y,
        .depth = pixel.depth,
        .r = pixel.r,
        .g = pixel.g,
        .b = pixel.b,
        .a = pixel.a,
    };

    var colouring = Colouring.init();
    defer colouring.deinit();

    const res = colouring.run(pixel);
    try expect(std.meta.eql(res, exp));
}

test "run no children barrier" {
    const pixel = types.CoallesceToColour{
        .kick_id = 0,
        .object_id = 0,
        .barrier = types.Barrier.last,
        .x = 3,
        .y = 3,
        .depth = 1,
        .r = 1,
        .g = 2,
        .b = 3,
        .a = 4,
    };

    const exp = types.ColourToDepthBuffer{
        .kick_id = pixel.kick_id,
        .object_id = pixel.object_id,
        .nulled = false,
        .barrier = pixel.barrier,
        .x = pixel.x,
        .y = pixel.y,
        .depth = pixel.depth,
        .r = pixel.r,
        .g = pixel.g,
        .b = pixel.b,
        .a = pixel.a,
    };

    var colouring = Colouring.init();
    defer colouring.deinit();

    const res = colouring.run(pixel);
    try expect(std.meta.eql(res, exp));
}

test "run 1 child" {
    const pixel = types.CoallesceToColour{
        .kick_id = 0,
        .object_id = 0,
        .barrier = types.Barrier.none,
        .x = 3,
        .y = 3,
        .depth = 1,
        .r = 1,
        .g = 2,
        .b = 3,
        .a = 4,

        .c1_r = 10,
        .c1_g = 10,
        .c1_b = 10,
        .c1_a = 10,
        .c1_action = Action.replace,
    };

    const exp = types.ColourToDepthBuffer{
        .kick_id = pixel.kick_id,
        .object_id = pixel.object_id,
        .nulled = false,
        .barrier = pixel.barrier,
        .x = pixel.x,
        .y = pixel.y,
        .depth = pixel.depth,
        .r = pixel.c1_r,
        .g = pixel.c1_g,
        .b = pixel.c1_b,
        .a = pixel.c1_a,
    };

    var colouring = Colouring.init();
    defer colouring.deinit();

    const res = colouring.run(pixel);
    try expect(std.meta.eql(res, exp));
}

test "run 2 children" {
    const pixel = types.CoallesceToColour{
        .kick_id = 0,
        .object_id = 0,
        .barrier = types.Barrier.none,
        .x = 3,
        .y = 3,
        .depth = 1,
        .r = 1,
        .g = 2,
        .b = 3,
        .a = 4,

        .c1_r = 10,
        .c1_g = 10,
        .c1_b = 10,
        .c1_a = 10,
        .c1_action = Action.replace,

        .c2_r = 20,
        .c2_g = 20,
        .c2_b = 20,
        .c2_a = 20,
        .c2_action = Action.combine,
    };

    const exp = types.ColourToDepthBuffer{
        .kick_id = pixel.kick_id,
        .object_id = pixel.object_id,
        .nulled = false,
        .barrier = pixel.barrier,
        .x = pixel.x,
        .y = pixel.y,
        .depth = pixel.depth,
        .r = 15,
        .g = 15,
        .b = 15,
        .a = 15,
    };

    var colouring = Colouring.init();
    defer colouring.deinit();

    const res = colouring.run(pixel);
    try expect(std.meta.eql(res, exp));
}

test "run 3 children" {
    var pixel = types.CoallesceToColour{
        .kick_id = 0,
        .object_id = 0,
        .barrier = types.Barrier.none,
        .x = 3,
        .y = 3,
        .depth = 1,
        .r = 1,
        .g = 2,
        .b = 3,
        .a = 4,

        .c1_r = 10,
        .c1_g = 10,
        .c1_b = 10,
        .c1_a = 10,
        .c1_action = Action.replace,

        .c2_r = 20,
        .c2_g = 20,
        .c2_b = 20,
        .c2_a = 20,
        .c2_action = Action.combine,

        .c3_r = 30,
        .c3_g = 30,
        .c3_b = 30,
        .c3_a = 30,
        .c3_action = Action.cut,
    };

    var colouring = Colouring.init();
    defer colouring.deinit();

    var res = colouring.run(pixel);
    try expect(std.meta.eql(res, null));

    pixel.barrier = types.Barrier.last;
    const exp = types.ColourToDepthBuffer{
        .kick_id = pixel.kick_id,
        .object_id = pixel.object_id,
        .nulled = true,
        .barrier = pixel.barrier,
        .x = pixel.x,
        .y = pixel.y,
        .depth = pixel.depth,
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
    };

    res = colouring.run(pixel);
    try expect(std.meta.eql(res, exp));
}
