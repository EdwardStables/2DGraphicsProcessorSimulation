const std = @import("std");
const types = @import("backend_types.zig");
const config = @import("backend_config.zig");

pub const Coallesce = struct {
    object_id: u8 = 0,
    x_min: u10 = 0,
    y_min: u10 = 0,
    next_x: u10 = 0,
    next_y: u10 = 0,

    pub fn init() Coallesce {
        return Coallesce{};
    }

    pub fn deinit(_: *Coallesce) void {}

    pub fn run(self: *Coallesce, object: types.StoreToCoallesce) ?types.CoallesceToColour {
        if (self.object_id != object.object.object_id) {
            self.object_id = object.object.object_id;

            //TODO: once made signed, if negative this needs to start at a position integer
            self.x_min = if (object.object.x < 0) @abs(object.object.x) else 0;
            self.y_min = if (object.object.y < 0) @abs(object.object.y) else 0;
            self.next_x = self.x_min;
            self.next_y = self.y_min;

            //test for invalid range therefore early return
            if (object.object.x > config.display_width or
                object.object.y > config.display_height)
            {
                return null;
            }
        } else {
            //update next pos

            //general case is next pixel along row
            var provisional_x: u10 = self.next_x + 1;
            var provisional_y: u10 = self.next_y;

            //testing x OOB
            if (provisional_x >= object.object.width or //iteration beyond edge of object
                @as(i16, provisional_x) + object.object.x >= config.display_width) //iteration in object but off screen
            {
                provisional_x = self.x_min;
                provisional_y += 1;
            }

            //testing y OOB
            if (provisional_y >= object.object.width or //iteration off object
                @as(i16, provisional_y) + object.object.y >= config.display_height) //iteration off bottom of screen
            {
                return null;
            }

            self.next_x = provisional_x;
            self.next_y = provisional_y;
        }

        //TODO some kind of check for zero width or height

        const pixel_x = if (object.object.x < 0)
            self.next_x - @abs(object.object.x)
        else
            self.next_x + @abs(object.object.x);

        const pixel_y = if (object.object.y < 0)
            self.next_y - @abs(object.object.y)
        else
            self.next_y + @abs(object.object.y);

        const pixel = types.CoallesceToColour{
            .kick_id = object.kick_id,
            .object_id = object.object.object_id,

            .x = pixel_x,
            .y = pixel_y,
            .depth = object.object.depth,

            .r = object.object.colour_r,
            .g = object.object.colour_g,
            .b = object.object.colour_b,
            .a = object.object.colour_a,
        };

        //TODO handle children

        return pixel;
    }
};

const expect = std.testing.expect;

const pair = struct { x: u10 = 0, y: u10 = 0 };
fn test2x2block(x: i10, y: i10, count: u8, one: pair, two: pair, three: pair, four: pair) !void {
    var coallesce = Coallesce.init();
    const obj = types.Object{ .object_id = 1, .x = x, .y = y, .width = 2, .height = 2 };
    const inp = types.StoreToCoallesce{ .kick_id = 1, .object = obj };

    var exp = types.CoallesceToColour{
        .kick_id = inp.kick_id,
        .object_id = obj.object_id,
        .x = 0,
        .y = 0,
        .depth = obj.depth,
        .r = obj.colour_r,
        .g = obj.colour_g,
        .b = obj.colour_b,
        .a = obj.colour_a,
    };

    var res: types.CoallesceToColour = undefined;

    if (count > 0) {
        exp.x = one.x;
        exp.y = one.y;
        res = coallesce.run(inp).?;
        try expect(std.meta.eql(res, exp));
    }

    if (count > 1) {
        exp.x = two.x;
        exp.y = two.y;
        res = coallesce.run(inp).?;
        try expect(std.meta.eql(res, exp));
    }

    if (count > 2) {
        exp.x = three.x;
        exp.y = three.y;
        res = coallesce.run(inp).?;
        try expect(std.meta.eql(res, exp));
    }

    if (count > 3) {
        exp.x = four.x;
        exp.y = four.y;
        res = coallesce.run(inp).?;
        try expect(std.meta.eql(res, exp));
    }

    try expect(coallesce.run(inp) == null);
}

test "in range iteration test" {
    try test2x2block(1, 1, 4, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 });
}

test "left out of range test" {
    try test2x2block(-1, 1, 2, .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 2 }, .{}, .{});
}

test "right side out of range test" {
    const w = config.display_width - 1;
    try test2x2block(w, 1, 2, .{ .x = w, .y = 1 }, .{ .x = w, .y = 2 }, .{}, .{});
}

test "top side out of range test" {
    try test2x2block(3, -1, 2, .{ .x = 3, .y = 0 }, .{ .x = 4, .y = 0 }, .{}, .{});
}

test "bottom side out of range test" {
    const h = config.display_height - 1;
    try test2x2block(3, h, 2, .{ .x = 3, .y = h }, .{ .x = 4, .y = h }, .{}, .{});
}
