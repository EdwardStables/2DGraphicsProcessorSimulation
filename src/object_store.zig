const std = @import("std");
const types = @import("backend_types.zig");
const system_config = @import("system_config.zig");

pub const ObjectStore = struct {
    //0 indicates no kick is running
    current_kick: u8 = 0,
    object_index: u8 = 0,
    objects: std.ArrayList(types.Object) = undefined,
    allocator: std.mem.Allocator = undefined,
    config: *system_config.Config,

    pub fn init(allocator: std.mem.Allocator, config: *system_config.Config) ObjectStore {
        var store = ObjectStore{ .config = config };
        store.allocator = allocator;
        store.objects = std.ArrayList(types.Object).init(allocator);
        return store;
    }

    pub fn deinit(self: *ObjectStore) void {
        self.objects.deinit();
    }

    pub fn addObject(self: *ObjectStore, object: types.Object) !void {
        try self.objects.append(object);
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
            .barrier = if (self.object_index == self.objects.items.len - 1) types.Barrier.last else types.Barrier.none,
        };

        self.object_index += 1;

        return message;
    }
};

const expect = std.testing.expect;
const ta = std.testing.allocator;
var test_config = system_config.Config{};

test "simple store test" {
    var store = ObjectStore.init(ta, &test_config);
    defer store.deinit();
    const test_obj = types.Object{ .object_id = 123, .x = 10, .y = 10, .width = 100, .height = 100 };

    const kick1 = types.ManagerToStore{ .kick_id = 1 };
    const kick2 = types.ManagerToStore{ .kick_id = 2 };
    const kick3 = types.ManagerToStore{ .kick_id = 3 };

    //Even a valid id gets null when store contains no data
    try expect(store.runBackend(kick1) == null);

    try store.addObject(test_obj);

    var resp = store.runBackend(kick2).?;
    try expect(resp.kick_id == 2);
    try expect(resp.barrier == types.Barrier.last);
    try expect(std.meta.eql(resp.object, test_obj));
    try expect(store.runBackend(kick2) == null);
    try expect(store.current_kick == 0);
    try expect(store.object_index == 0);

    resp = store.runBackend(kick3).?;
    try expect(resp.kick_id == 3);
    try expect(resp.barrier == types.Barrier.last);
    try expect(std.meta.eql(resp.object, test_obj));
    try expect(store.runBackend(kick3) == null);
    try expect(store.current_kick == 0);
    try expect(store.object_index == 0);
}

test "multiple objects" {
    var store = ObjectStore.init(ta, &test_config);
    defer store.deinit();

    const obj1 = types.Object{ .object_id = 123, .x = 10, .y = 10, .width = 100, .height = 100 };
    const obj2 = types.Object{ .object_id = 124, .x = 20, .y = 20, .width = 100, .height = 100 };
    const obj3 = types.Object{ .object_id = 125, .x = 30, .y = 30, .width = 100, .height = 100 };

    const kick = types.ManagerToStore{ .kick_id = 1 };

    try expect(store.runBackend(kick) == null);
    try expect(store.current_kick == 0);
    try expect(store.object_index == 0);

    try store.addObject(obj1);

    var resp = store.runBackend(kick).?;
    try expect(resp.barrier == types.Barrier.last);
    try expect(std.meta.eql(resp.object, obj1));
    try expect(store.current_kick == 1);
    try expect(store.object_index == 1);
    try expect(store.runBackend(kick) == null);
    try expect(store.current_kick == 0);
    try expect(store.object_index == 0);

    try store.addObject(obj2);

    resp = store.runBackend(kick).?;
    try expect(resp.barrier == types.Barrier.none);
    try expect(std.meta.eql(resp.object, obj1));
    try expect(store.current_kick == 1);
    try expect(store.object_index == 1);
    resp = store.runBackend(kick).?;
    try expect(resp.barrier == types.Barrier.last);
    try expect(std.meta.eql(resp.object, obj2));
    try expect(store.current_kick == 1);
    try expect(store.object_index == 2);
    try expect(store.runBackend(kick) == null);
    try expect(store.current_kick == 0);
    try expect(store.object_index == 0);

    try store.addObject(obj3);

    resp = store.runBackend(kick).?;
    try expect(resp.barrier == types.Barrier.none);
    try expect(std.meta.eql(resp.object, obj1));
    try expect(store.current_kick == 1);
    try expect(store.object_index == 1);
    resp = store.runBackend(kick).?;
    try expect(resp.barrier == types.Barrier.none);
    try expect(std.meta.eql(resp.object, obj2));
    try expect(store.current_kick == 1);
    try expect(store.object_index == 2);
    resp = store.runBackend(kick).?;
    try expect(resp.barrier == types.Barrier.last);
    try expect(std.meta.eql(resp.object, obj3));
    try expect(store.current_kick == 1);
    try expect(store.object_index == 3);
    try expect(store.runBackend(kick) == null);
    try expect(store.current_kick == 0);
    try expect(store.object_index == 0);
}
