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

    var framebuffer = try backend.run_backend(gpa.allocator(), &store, &config);
    defer framebuffer.deinit();

    const output = "output";
    try createOutputDirectory(output);
    try writePPMFile(
        framebuffer,
        gpa.allocator(),
        0,
        config,
        output,
    );

    std.log.info("Finished", .{});
}

fn createOutputDirectory(dirname: []const u8) !void {
    std.fs.cwd().deleteTree(dirname) catch |e| {
        switch (e) {
            error.InvalidHandle => {}, //That's fine
            else => return e,
        }
    };

    try std.fs.cwd().makeDir(dirname);
}

fn writePPMFile(
    framebuffer: types.FrameBuffer,
    allocator: std.mem.Allocator,
    index: u32,
    config: system_config.Config,
    output_directory: []const u8,
) !void {
    std.log.info("Running image generation", .{});

    const filename = try std.fmt.allocPrint(allocator, "{s}/{d:0>3}_frame.ppm", .{ output_directory, index });
    defer allocator.free(filename);

    std.log.debug("Writing file {s}", .{filename});

    const file = try std.fs.cwd().createFile(filename, .{ .read = true });
    defer file.close();

    const writer = file.writer();

    try std.fmt.format(writer, "P3\n{d} {d}\n255\n", .{ config.display_width, config.display_height });

    for (0..(config.display_width * config.display_height)) |i| {
        const r: u8 = @truncate(framebuffer.pixels[i] >> 16);
        const g: u8 = @truncate(framebuffer.pixels[i] >> 8);
        const b: u8 = @truncate(framebuffer.pixels[i]);
        try std.fmt.format(writer, "{d} {d} {d}\n", .{ r, g, b });
    }
}

const expect = std.testing.expect;
const ta = std.testing.allocator;

test {
    std.testing.refAllDecls(@This());
}
