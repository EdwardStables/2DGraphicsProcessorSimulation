const std = @import("std");

const component_store = @import("object_store.zig");
const backend = @import("backend.zig");

const types = @import("backend_types.zig");
const system_config = @import("system_config.zig");

pub fn main() !void {
    var config = system_config.Config{};

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var store = component_store.ObjectStore.init(gpa.allocator(), &config);
    defer store.deinit();

    std.log.info("Adding objects...", .{});

    try store.addObject(.{ .object_id = 1, .x = 3, .y = 3, .width = 3, .height = 3, .depth = 0 });
    try store.addObject(.{ .object_id = 2, .x = 13, .y = 13, .width = 3, .height = 3, .depth = 0, .colour_r = 0, .colour_g = 255 });
    try store.addObject(.{ .object_id = 3, .x = 23, .y = 23, .width = 3, .height = 3, .depth = 0, .colour_r = 0, .colour_b = 255 });

    std.log.info("Done", .{});

    try backend.run_backend(gpa.allocator(), &store, &config);

    std.log.info("Finished", .{});
}

const expect = std.testing.expect;
const ta = std.testing.allocator;

test {
    std.testing.refAllDecls(@This());
}
