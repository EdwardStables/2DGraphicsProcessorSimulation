const std = @import("std");
const types = @import("backend_types.zig");
const system_config = @import("backend_config.zig");

const Pair = struct { x: u10 = 0, y: u10 = 0 };

pub const Coallesce = struct {
    object_id: u8 = 0,
    x_min: u10 = 0,
    y_min: u10 = 0,
    next_x: u10 = 0,
    next_y: u10 = 0,
    config: system_config.Config,

    pub fn init(config: system_config.Config) Coallesce {
        return Coallesce{ .config = config };
    }

    pub fn deinit(_: *Coallesce) void {}

    fn testNext(self: *Coallesce, provisional_x: u10, provisional_y: u10, object: types.StoreToCoallesce) ?Pair {
        var x = provisional_x;
        var y = provisional_y;

        //testing x OOB
        if (x >= object.object.width or //iteration beyond edge of object
            @as(i16, x) + object.object.x >= self.config.display_width) //iteration in object but off screen
        {
            x = self.x_min;
            y += 1;
        }

        //testing y OOB
        if (y >= object.object.width or //iteration off object
            @as(i16, y) + object.object.y >= self.config.display_height) //iteration off bottom of screen
        {
            return null;
        }

        return .{ .x = x, .y = y };
    }

    pub fn run(self: *Coallesce, object: types.StoreToCoallesce) ?types.CoallesceToColour {
        var provisional_x: u10 = undefined;
        var provisional_y: u10 = undefined;

        if (self.object_id != object.object.object_id) {
            self.object_id = object.object.object_id;

            self.x_min = if (object.object.x < 0) @abs(object.object.x) else 0;
            self.y_min = if (object.object.y < 0) @abs(object.object.y) else 0;
            self.next_x = self.x_min;
            self.next_y = self.y_min;

            provisional_x = self.next_x;
            provisional_y = self.next_y;
        } else {
            //general case is next pixel along row
            provisional_x = self.next_x + 1;
            provisional_y = self.next_y;
        }

        const update = self.testNext(provisional_x, provisional_y, object) orelse return null;

        self.next_x = update.x;
        self.next_y = update.y;

        //TODO some kind of check for zero width or height

        const pixel_x = if (object.object.x < 0)
            self.next_x - @abs(object.object.x)
        else
            self.next_x + @abs(object.object.x);

        const pixel_y = if (object.object.y < 0)
            self.next_y - @abs(object.object.y)
        else
            self.next_y + @abs(object.object.y);

        //Testing the following position to see barrier value
        const next_query = self.testNext(self.next_x + 1, self.next_y, object);
        const next_invalid = next_query == null;
        const last_barrier = next_invalid and object.barrier == types.Barrier.last;

        const pixel = types.CoallesceToColour{
            .kick_id = object.kick_id,
            .object_id = object.object.object_id,
            .barrier = if (last_barrier) types.Barrier.last else types.Barrier.none,

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
const test_config = system_config.Config{};

fn test2x2block(x: i10, y: i10, count: u8, one: Pair, two: Pair, three: Pair, four: Pair) !void {
    var coallesce = Coallesce.init(test_config);
    const obj = types.Object{ .object_id = 1, .x = x, .y = y, .width = 2, .height = 2 };
    const inp = types.StoreToCoallesce{
        .kick_id = 1,
        .object = obj,
        .barrier = types.Barrier.none,
    };

    var exp = types.CoallesceToColour{
        .kick_id = inp.kick_id,
        .object_id = obj.object_id,
        .barrier = types.Barrier.none,
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

test "out of range iteration test" {
    try test2x2block(-5, -5, 0, .{}, .{}, .{}, .{});
    try test2x2block(test_config.display_width + 10, test_config.display_height + 10, 0, .{}, .{}, .{}, .{});
}

test "left out of range test" {
    try test2x2block(-1, 1, 2, .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 2 }, .{}, .{});
}

test "right side out of range test" {
    const w = test_config.display_width - 1;
    try test2x2block(w, 1, 2, .{ .x = w, .y = 1 }, .{ .x = w, .y = 2 }, .{}, .{});
}

test "top side out of range test" {
    try test2x2block(3, -1, 2, .{ .x = 3, .y = 0 }, .{ .x = 4, .y = 0 }, .{}, .{});
}

test "bottom side out of range test" {
    const h = test_config.display_height - 1;
    try test2x2block(3, h, 2, .{ .x = 3, .y = h }, .{ .x = 4, .y = h }, .{}, .{});
}

test "top left corner" {
    try test2x2block(-1, -1, 1, .{ .x = 0, .y = 0 }, .{}, .{}, .{});
}

test "top right corner" {
    const w = test_config.display_width - 1;
    try test2x2block(w, -1, 1, .{ .x = w, .y = 0 }, .{}, .{}, .{});
}

test "bottom left corner" {
    const h = test_config.display_height - 1;
    try test2x2block(-1, h, 1, .{ .x = 0, .y = h }, .{}, .{}, .{});
}

test "bottom right corner" {
    const w = test_config.display_width - 1;
    const h = test_config.display_height - 1;
    try test2x2block(w, h, 1, .{ .x = w, .y = h }, .{}, .{}, .{});
}

test "barrier" {
    var coallesce = Coallesce.init(test_config);
    const obj = types.Object{ .object_id = 1, .x = 0, .y = 0, .width = 2, .height = 2 };
    const inp = types.StoreToCoallesce{
        .kick_id = 1,
        .object = obj,
        .barrier = types.Barrier.last,
    };

    var exp = types.CoallesceToColour{
        .kick_id = inp.kick_id,
        .object_id = obj.object_id,
        .barrier = types.Barrier.none,
        .x = 0,
        .y = 0,
        .depth = obj.depth,
        .r = obj.colour_r,
        .g = obj.colour_g,
        .b = obj.colour_b,
        .a = obj.colour_a,
    };

    exp.x = 0;
    exp.y = 0;
    var res = coallesce.run(inp).?;
    try expect(std.meta.eql(res, exp));

    exp.x = 1;
    exp.y = 0;
    res = coallesce.run(inp).?;
    try expect(std.meta.eql(res, exp));

    exp.x = 0;
    exp.y = 1;
    res = coallesce.run(inp).?;
    try expect(std.meta.eql(res, exp));

    exp.x = 1;
    exp.y = 1;
    exp.barrier = types.Barrier.last;
    res = coallesce.run(inp).?;
    try expect(std.meta.eql(res, exp));
}
