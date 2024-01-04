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
            self.x_min = 0;
            self.y_min = 0;
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
            var provisional_x = self.next_x + 1;
            var provisional_y = self.next_y;

            //testing x OOB
            if (provisional_x >= object.object.width or //iteration beyond edge of object
                provisional_x + object.object.x >= config.display_width) //iteration in object but off screen
            {
                provisional_x = self.x_min;
                provisional_y += 1;
            }

            //testing y OOB
            if (provisional_y >= object.object.width or //iteration off object
                provisional_y + object.object.y >= config.display_height) //iteration off bottom of screen
            {
                return null;
            }

            self.next_x = provisional_x;
            self.next_y = provisional_y;
        }

        //TODO some kind of check for zero width or height

        const pixel = types.CoallesceToColour{
            .kick_id = object.kick_id,
            .object_id = object.object.object_id,

            .x = self.next_x + object.object.x,
            .y = self.next_y + object.object.y,
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

test "in range iteration test" {
    var coallesce = Coallesce.init();
    const obj = types.Object{ .object_id = 1, .x = 1, .y = 1, .width = 2, .height = 2 };
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

    const one = coallesce.run(inp).?;
    exp.x = 1;
    exp.y = 1;
    try expect(std.meta.eql(one, exp));

    const two = coallesce.run(inp).?;
    exp.x = 2;
    exp.y = 1;
    try expect(std.meta.eql(two, exp));

    const three = coallesce.run(inp).?;
    exp.x = 1;
    exp.y = 2;
    try expect(std.meta.eql(three, exp));

    const four = coallesce.run(inp).?;
    exp.x = 2;
    exp.y = 2;
    try expect(std.meta.eql(four, exp));

    try expect(coallesce.run(inp) == null);
}
