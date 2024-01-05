pub const ChildAction = enum {
    none,
    replace,
    combine,
    cut,
    //stencil - child cuts if smaller than value
};
pub const Barrier = enum { none, last };

pub const Object = struct {
    object_id: u8,
    x: i10,
    y: i10,
    width: u10,
    height: u10,
    depth: u4 = 0,
    colour_r: u8 = 255,
    colour_g: u8 = 0,
    colour_b: u8 = 0,
    colour_a: u8 = 0,
    child0_id: u8 = 0,
    child0_cut: ChildAction = ChildAction.none,
    child1_id: u8 = 0,
    child1_cut: ChildAction = ChildAction.none,
    child2_id: u8 = 0,
    child2_cut: ChildAction = ChildAction.none,
};

pub const ManagerToStore = struct {
    kick_id: u8,
};

pub const StoreToCoallesce = struct {
    kick_id: u8,
    object: Object,
    barrier: Barrier,
};

pub const CoallesceToColour = struct {
    kick_id: u8,
    object_id: u8,
    barrier: Barrier,

    x: u10,
    y: u10,
    depth: u4,

    r: u8,
    g: u8,
    b: u8,
    a: u8,

    c1_action: ChildAction = ChildAction.none,
    c1_r: u8 = 0,
    c1_g: u8 = 0,
    c1_b: u8 = 0,
    c1_a: u8 = 0,

    c2_action: ChildAction = ChildAction.none,
    c2_r: u8 = 0,
    c2_g: u8 = 0,
    c2_b: u8 = 0,
    c2_a: u8 = 0,

    c3_action: ChildAction = ChildAction.none,
    c3_r: u8 = 0,
    c3_g: u8 = 0,
    c3_b: u8 = 0,
    c3_a: u8 = 0,
};

pub const ColourToDepthBuffer = struct {
    kick_id: u8,
    object_id: u8,

    nulled: bool, //in case the transaction would be culled, but it's got a non-null barrier so must continue
    barrier: Barrier,

    x: u10,
    y: u10,
    depth: u4,

    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const DepthBufferToFrameBuffer = struct {
    pixels: []u32,
};
