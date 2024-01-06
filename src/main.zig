const std = @import("std");

const component_manager = @import("backend_manager.zig");
const component_store = @import("object_store.zig");
const component_coallesce = @import("coallesce.zig");
const component_colour = @import("colouring.zig");
const component_depth_buffer = @import("depth_buffer.zig");

const types = @import("backend_types.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    //Component Instantiation

    var manager = component_manager.Manager.init(3);
    defer manager.deinit();

    var store = component_store.ObjectStore.init(gpa.allocator());
    defer store.deinit();

    try store.addObject(.{ .object_id = 1, .x = 3, .y = 3, .width = 3, .height = 3, .depth = 0 });
    try store.addObject(.{ .object_id = 2, .x = 13, .y = 13, .width = 3, .height = 3, .depth = 0, .colour_r = 0, .colour_g = 255 });
    try store.addObject(.{ .object_id = 3, .x = 23, .y = 23, .width = 3, .height = 3, .depth = 0, .colour_r = 0, .colour_b = 255 });

    var coallesce = component_coallesce.Coallesce.init();
    defer coallesce.deinit();

    var colouring = component_colour.Colouring.init();
    defer colouring.deinit();

    var depth_buffer = try component_depth_buffer.DepthBuffer.init(gpa.allocator());
    defer depth_buffer.deinit();

    //Pipeline simulation

    var manager_output = std.ArrayList(types.ManagerToStore).init(gpa.allocator());
    defer manager_output.deinit();
    while (manager.run()) |kick| {
        try manager_output.append(kick);
    }

    var store_output = std.ArrayList(types.StoreToCoallesce).init(gpa.allocator());
    defer store_output.deinit();
    for (try manager_output.toOwnedSlice()) |kick| {
        while (store.runBackend(kick)) |object_attrs| {
            try store_output.append(object_attrs);
        }
    }

    var coallesce_output = std.ArrayList(types.CoallesceToColour).init(gpa.allocator());
    defer coallesce_output.deinit();
    for (try store_output.toOwnedSlice()) |object| {
        while (coallesce.run(object)) |pixel| {
            try coallesce_output.append(pixel);
        }
    }

    var colouring_output = std.ArrayList(types.ColourToDepthBuffer).init(gpa.allocator());
    defer colouring_output.deinit();
    for (try coallesce_output.toOwnedSlice()) |pixel| {
        while (colouring.run(pixel)) |colour| {
            try colouring_output.append(colour);
        }
    }

    var depth_buffer_output = std.ArrayList(types.DepthBufferToFrameBuffer).init(gpa.allocator());
    defer {
        for (depth_buffer_output.items) |*buffer| {
            buffer.deinit();
        }
        depth_buffer_output.deinit();
    }
    for (try colouring_output.toOwnedSlice()) |pixel| {
        while (try depth_buffer.run(pixel)) |output_buffer| {
            try depth_buffer_output.append(output_buffer);
        }
    }

    for (try depth_buffer_output.toOwnedSlice(), 0..depth_buffer_output.items.len) |framebuffer, index| {
        const filename = try std.fmt.allocPrint(gpa.allocator(), "output/{d:0>3}_frame.ppm", .{index});
        try writePPMFile(framebuffer.pixels, filename);
    }
}

fn writePPMFile(framebuffer: []u24, filename: []u8) !void {
    _ = framebuffer;
    std.debug.print("{s}", .{filename});
}

test {
    std.testing.refAllDecls(@This());
}
