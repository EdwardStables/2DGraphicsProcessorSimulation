const expect = @import("std").testing.expect;

const types = @import("backend_types.zig");

pub const Manager = struct {
    kicks_to_send: u8 = 1,    

    pub fn init() Manager {
        return Manager{};
    }

    pub fn run(self: *Manager) ?types.ManagerToStore {
        if (self.kicks_to_send == 0){ return null; }

        self.kicks_to_send -= 1;
        return types.ManagerToStore{.kick_id = self.kicks_to_send};
    }
};

test "simple manager test" {
    var manager = Manager.init();
    try expect(manager.run().?.kick_id == 0);
    try expect(manager.run() == null);
}