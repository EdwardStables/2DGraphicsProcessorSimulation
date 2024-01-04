const std = @import("std");

const component_manager = @import("backend_manager.zig");
const component_store = @import("object_store.zig");

const types = @import("backend_types.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var manager = component_manager.Manager.init();
    defer manager.deinit();

    var store = component_store.ObjectStore.init(gpa.allocator());
    defer store.deinit();
    try store.initialiseData(); //Simple premade geometry

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
}

test {
    std.testing.refAllDecls(@This());
}
