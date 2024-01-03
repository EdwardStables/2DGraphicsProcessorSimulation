pub const Object = struct {
    x: u10,
    y: u10,
    width: u10,
    height: u10,
    depth: u4,
    colour_r: u8,
    colour_g: u8,
    colour_b: u8,
    colour_a: u8,
    child0_id: u8,
    child0_cut: bool,
    child1_id: u8,
    child1_cut: bool,
    child2_id: u8,
    child2_cut: bool
};

pub const ManagerToStore= struct {
    kick_id: u8,
};

pub const StoreToCoallesce = struct {
    kick_id: u8,
};

pub const CoallesceToCull = struct {

};

pub const CullToColour = struct {

};

pub const ColourToDepthBuffer = struct {

};

pub const DepthBufferToFrameBuffer = struct {

};