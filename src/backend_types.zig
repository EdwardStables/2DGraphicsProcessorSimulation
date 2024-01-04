pub const Object = struct { x: u10, y: u10, width: u10, height: u10, depth: u4 = 0, colour_r: u8 = 255, colour_g: u8 = 0, colour_b: u8 = 0, colour_a: u8 = 0, child0_id: u8 = 0, child0_cut: bool = false, child1_id: u8 = 0, child1_cut: bool = false, child2_id: u8 = 0, child2_cut: bool = false };

pub const ManagerToStore = struct {
    kick_id: u8,
};

pub const StoreToCoallesce = struct {
    kick_id: u8,
    object: Object,
};

pub const CoallesceToCull = struct {};

pub const CullToColour = struct {};

pub const ColourToDepthBuffer = struct {};

pub const DepthBufferToFrameBuffer = struct {};
