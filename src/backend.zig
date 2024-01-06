const std = @import("std");

const component_manager = @import("backend_manager.zig");
const component_store = @import("object_store.zig");
const component_coallesce = @import("coallesce.zig");
const component_colour = @import("colouring.zig");
const component_depth_buffer = @import("depth_buffer.zig");

const types = @import("backend_types.zig");
const system_config = @import("system_config.zig");

pub fn run_backend(allocator: std.mem.Allocator, object_store: *component_store.ObjectStore, config: *system_config.Config) !types.FrameBuffer {
    //Component Instantiation

    std.log.info("Beginning component instantiation", .{});

    var manager = component_manager.Manager.init(1, config);
    defer manager.deinit();

    var coallesce = component_coallesce.Coallesce.init(config);
    defer coallesce.deinit();

    var colouring = component_colour.Colouring.init(config);
    defer colouring.deinit();

    var depth_buffer = try component_depth_buffer.DepthBuffer.init(allocator, config);
    defer depth_buffer.deinit();

    //Pipeline simulation

    std.log.info("Starting simulation", .{});

    std.log.info("Running manager", .{});
    var manager_output = std.ArrayList(types.ManagerToStore).init(allocator);
    defer manager_output.deinit();
    while (manager.run()) |kick| {
        try manager_output.append(kick);
    }

    std.log.info("Running store", .{});
    var store_output = std.ArrayList(types.StoreToCoallesce).init(allocator);
    defer store_output.deinit();
    for (manager_output.items) |kick| {
        while (object_store.runBackend(kick)) |object_attrs| {
            try store_output.append(object_attrs);
        }
    }

    std.log.info("Running coallesce", .{});
    var coallesce_output = std.ArrayList(types.CoallesceToColour).init(allocator);
    defer coallesce_output.deinit();
    for (store_output.items) |object| {
        while (coallesce.run(object)) |pixel| {
            try coallesce_output.append(pixel);
        }
    }

    std.log.info("Running colouring", .{});
    var colouring_output = std.ArrayList(types.ColourToDepthBuffer).init(allocator);
    defer colouring_output.deinit();
    for (coallesce_output.items) |pixel| {
        const colour = colouring.run(pixel) orelse continue;
        try colouring_output.append(colour);
    }

    std.log.info("Running depth buffer", .{});
    var depth_buffer_output = std.ArrayList(types.FrameBuffer).init(allocator);
    defer {
        for (depth_buffer_output.items) |*buffer| {
            buffer.deinit();
        }
        depth_buffer_output.deinit();
    }
    for (colouring_output.items) |pixel| {
        var buf = try depth_buffer.run(pixel) orelse continue;
        defer buf.deinit();
        return buf;
    }

    unreachable;
}

const expect = std.testing.expect;
const ta = std.testing.allocator;
var tc = system_config.Config{ .display_width = 3, .display_height = 3 };

test {
    var store = component_store.ObjectStore.init(ta, &tc);
    defer store.deinit();

    try store.addObject(.{ .object_id = 1, .x = 1, .y = 1, .width = 1, .height = 1, .depth = 0 });
    _ = try run_backend(ta, &store, &tc);
}
