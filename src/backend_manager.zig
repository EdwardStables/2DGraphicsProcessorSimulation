const expect = @import("std").testing.expect;

const types = @import("backend_types.zig");

pub const Manager = struct {
    kicks_to_send: u8 = 1,

    pub fn init(kicks: u8) Manager {
        return Manager{ .kicks_to_send = kicks };
    }
    pub fn deinit(_: *Manager) void {}

    pub fn run(self: *Manager) ?types.ManagerToStore {
        if (self.kicks_to_send == 0) {
            return null;
        }

        defer self.kicks_to_send -= 1;
        return types.ManagerToStore{ .kick_id = self.kicks_to_send };
    }
};

test "simple manager test" {
    var manager = Manager.init(3);
    try expect(manager.run().?.kick_id == 3);
    try expect(manager.run().?.kick_id == 2);
    try expect(manager.run().?.kick_id == 1);
    try expect(manager.run() == null);
}
