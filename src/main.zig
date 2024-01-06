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

    std.log.info("Beginning component instantiation", .{});

    var manager = component_manager.Manager.init(3);
    defer manager.deinit();

    var store = component_store.ObjectStore.init(gpa.allocator());
    defer store.deinit();

    std.log.info("Adding objects...", .{});

    try store.addObject(.{ .object_id = 1, .x = 3, .y = 3, .width = 3, .height = 3, .depth = 0 });
    try store.addObject(.{ .object_id = 2, .x = 13, .y = 13, .width = 3, .height = 3, .depth = 0, .colour_r = 0, .colour_g = 255 });
    try store.addObject(.{ .object_id = 3, .x = 23, .y = 23, .width = 3, .height = 3, .depth = 0, .colour_r = 0, .colour_b = 255 });

    std.log.info("Done", .{});

    var coallesce = component_coallesce.Coallesce.init();
    defer coallesce.deinit();

    var colouring = component_colour.Colouring.init();
    defer colouring.deinit();

    var depth_buffer = try component_depth_buffer.DepthBuffer.init(gpa.allocator());
    defer depth_buffer.deinit();

    //Pipeline simulation

    std.log.info("Starting simulation", .{});

    std.log.info("Running manager", .{});
    var manager_output = std.ArrayList(types.ManagerToStore).init(gpa.allocator());
    defer manager_output.deinit();
    while (manager.run()) |kick| {
        try manager_output.append(kick);
    }

    std.log.info("Running store", .{});
    var store_output = std.ArrayList(types.StoreToCoallesce).init(gpa.allocator());
    defer store_output.deinit();
    for (manager_output.items) |kick| {
        while (store.runBackend(kick)) |object_attrs| {
            try store_output.append(object_attrs);
        }
    }

    std.log.info("Running coallesce", .{});
    var coallesce_output = std.ArrayList(types.CoallesceToColour).init(gpa.allocator());
    defer coallesce_output.deinit();
    for (store_output.items) |object| {
        while (coallesce.run(object)) |pixel| {
            try coallesce_output.append(pixel);
        }
    }

    std.log.info("Running colouring", .{});
    var colouring_output = std.ArrayList(types.ColourToDepthBuffer).init(gpa.allocator());
    defer colouring_output.deinit();
    for (coallesce_output.items) |pixel| {
        const colour = colouring.run(pixel) orelse continue;
        try colouring_output.append(colour);
    }

    std.log.info("Running depth buffer", .{});
    var depth_buffer_output = std.ArrayList(types.DepthBufferToFrameBuffer).init(gpa.allocator());
    defer {
        for (depth_buffer_output.items) |*buffer| {
            buffer.deinit();
        }
        depth_buffer_output.deinit();
    }
    for (colouring_output.items) |pixel| {
        const buf = try depth_buffer.run(pixel) orelse continue;
        try depth_buffer_output.append(buf);
    }

    std.log.info("Running image generation", .{});
    for (depth_buffer_output.items, 0..depth_buffer_output.items.len) |framebuffer, index| {
        const filename = try std.fmt.allocPrint(gpa.allocator(), "output/{d:0>3}_frame.ppm", .{index});
        defer gpa.allocator().free(filename);
        try writePPMFile(framebuffer.pixels, filename);
    }

    std.log.info("Finished", .{});
}

fn writePPMFile(framebuffer: []u24, filename: []u8) !void {
    _ = framebuffer;
    std.log.debug("Writing file {s}", .{filename});
}

const expect = std.testing.expect;
const ta = std.testing.allocator;

test {
    std.testing.refAllDecls(@This());
}
