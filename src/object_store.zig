const std = @import("std");
const types = @import("backend_types.zig");
const config = @import("backend_config.zig");

pub const ObjectStore = struct {
    //0 indicates no kick is running
    current_kick: u8 = 0,
    object_index: u8 = 0,
    objects: std.ArrayList(types.Object) = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) ObjectStore {
        var store = ObjectStore{};
        store.allocator = allocator;
        store.objects = std.ArrayList(types.Object).init(allocator);
        return store;
    }

    pub fn deinit(self: *ObjectStore) void {
        self.objects.deinit();
    }

    //Load a premade set of blocks into the store
    //TODO: A better system of loading for testing once more features implemented
    pub fn initialiseData(self: *ObjectStore) !void {
        const obj = types.Object{ .x = 10, .y = 10, .width = 100, .height = 100 };

        try self.objects.append(obj);
    }

    pub fn runBackend(self: *ObjectStore, manager: types.ManagerToStore) ?types.StoreToCoallesce {
        if (manager.kick_id != self.current_kick) {
            self.current_kick = manager.kick_id;
            self.object_index = 0;
        }

        if (self.object_index == self.objects.items.len or self.current_kick == 0) {
            self.current_kick = 0; //also reset to finish kick
            self.object_index = 0;
            return null;
        }

        const message = types.StoreToCoallesce{
            .kick_id = self.current_kick,
            .object = self.objects.items[self.object_index],
        };

        self.object_index += 1;

        return message;
    }
};

const expect = std.testing.expect;
const ta = std.testing.allocator;

test "simple store test" {
    var store = ObjectStore.init(ta);
    defer store.deinit();
    const test_obj = types.Object{ .x = 10, .y = 10, .width = 100, .height = 100 };

    const kick1 = types.ManagerToStore{ .kick_id = 1 };
    const kick2 = types.ManagerToStore{ .kick_id = 2 };
    const kick3 = types.ManagerToStore{ .kick_id = 3 };

    //Even a valid id gets null when store contains no data
    try expect(store.runBackend(kick1) == null);

    try store.initialiseData();

    var resp = store.runBackend(kick2).?;
    try expect(resp.kick_id == 2);
    try expect(std.meta.eql(resp.object, test_obj));
    try expect(store.runBackend(kick2) == null);

    resp = store.runBackend(kick3).?;
    try expect(resp.kick_id == 3);
    try expect(std.meta.eql(resp.object, test_obj));
    try expect(store.runBackend(kick3) == null);
}
