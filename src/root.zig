const std = @import("std");
const testing = std.testing;
const Allocator = std.testing.allocator;

const MAX_FIELD_COUNT: u8 = 255;

pub fn tomlize(obj: anytype, writer: anytype) void {
    _ = writer;
    const ttype = @TypeOf(obj);
    const tinfo = @typeInfo(ttype);
    if (!std.mem.eql(u8, @tagName(tinfo), "Struct")) @panic("non struct type given to serialize");
    const field_names = comptime get_fields(tinfo);

    inline for (field_names.buffer) |fname|
        std.debug.print("{s}\n = {s}", .{ fname, @field(obj, fname) });
}

fn get_fields(tinfo: std.builtin.Type) std.BoundedArray([]const u8, MAX_FIELD_COUNT) {
    comptime var field_names = std.BoundedArray([]const u8, MAX_FIELD_COUNT).init(0) catch unreachable;
    comptime var i: u8 = 0;
    const fields = tinfo.Struct.fields;
    if (fields.len > MAX_FIELD_COUNT) @panic("struct field count exceeded MAX_FIELD_COUNT");
    inline while (i < fields.len) {
        const fname = fields.ptr[i].name;
        field_names.append(fname) catch unreachable;
        i += 1;
    }
    return field_names;
}

test "basic test" {
    const TestStruct = struct {
        field1: i32,
        field2: []const u8,
        field3: bool,
        field4: f64,
    };

    const t = TestStruct{
        .field1 = 1024,
        .field2 = "hello world",
        .field3 = false,
        .field4 = 3.14,
    };

    var buf: [1024]u8 = undefined;
    tomlize(t, &buf);
}
