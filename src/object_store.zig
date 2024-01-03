const expect = @import("std").testing.expect;

const types = @import("backend_types.zig");
const config = @import("backend_config.zig");

pub const ObjectStore = struct {
    current_kick: u8 = undefined,

    pub fn init() ObjectStore {
        return ObjectStore{};
    }    

    pub fn runBackend(self: *ObjectStore, manager: types.ManagerToStore) ?types.StoreToCoallesce {
        if (manager.kick_id == self.current_kick) { return null; }

        self.current_kick = manager.kick_id;

        return types.StoreToCoallesce{.kick_id = self.current_kick};
    }
};

test "simple store test" {
    var store = ObjectStore.init();
    const kick1 = types.ManagerToStore{.kick_id = 1};
    const kick2 = types.ManagerToStore{.kick_id = 2};
    try expect(store.runBackend(kick1).?.kick_id == 1);
    try expect(store.runBackend(kick1) == null);
    try expect(store.runBackend(kick2).?.kick_id == 2);
    try expect(store.runBackend(kick2) == null);
}