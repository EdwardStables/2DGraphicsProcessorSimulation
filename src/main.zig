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

    var manager = component_manager.Manager.init();
    defer manager.deinit();

    var store = component_store.ObjectStore.init(gpa.allocator());
    defer store.deinit();

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
}

test {
    std.testing.refAllDecls(@This());
}
