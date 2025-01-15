const std = @import("std");
const testing = std.testing;
const Allocator = std.testing.allocator;

const MAX_FIELD_COUNT: u8 = 255;

pub fn tomlize(allocator: std.mem.Allocator, obj: anytype, writer: anytype) !void {
    const ttype = @TypeOf(obj);
    const tinfo = @typeInfo(ttype);
    if (!std.mem.eql(u8, @tagName(tinfo), "Struct")) @panic("non struct type given to serialize");
    const fields = comptime get_fields(tinfo);

    comptime var i: u8 = 0;
    inline while (i < fields.len) {
        const field = fields.buffer[i];
        try serialize_field(allocator, obj, field, writer);
        i += 1;
    }
}

fn serialize_field(allocator: std.mem.Allocator, obj: anytype, field: std.builtin.Type.StructField, writer: anytype) !void {
    try writer.print("{s} = ", .{field.name});
    switch (@typeInfo(field.type)) {
        .Int => try writer.print("{d}", .{@field(obj, field.name)}),
        .Bool => {
            if (@field(obj, field.name))
                try writer.print("true", .{})
            else
                try writer.print("false", .{});
        },
        .Float => try writer.print("{d}", .{@field(obj, field.name)}),
        .Pointer => {
            const pointer_type = @typeInfo(field.type);
            if (pointer_type.Pointer.child == u8 and pointer_type.Pointer.size == .Slice) {
                var esc_string = std.ArrayList(u8).init(allocator);
                defer esc_string.deinit();
                const string = @field(obj, field.name);

                var curr_pos: usize = 0;
                while (curr_pos <= string.len) {
                    const new_pos = std.mem.indexOfAnyPos(u8, string, curr_pos, &.{ '\\', '\"' }) orelse string.len;

                    if (new_pos >= curr_pos) {
                        try esc_string.appendSlice(string[curr_pos..new_pos]);
                        try esc_string.append('\\');
                        if (new_pos != string.len) try esc_string.append(string[new_pos]);
                        curr_pos = new_pos + 1;
                    }
                }
                try writer.print("\"{s}\"", .{esc_string.items});
            }
        },
        .Array => {},
        else => {},
    }
    _ = try writer.write("\n");
}

fn get_fields(tinfo: std.builtin.Type) std.BoundedArray(std.builtin.Type.StructField, MAX_FIELD_COUNT) {
    comptime var field_names = std.BoundedArray(std.builtin.Type.StructField, MAX_FIELD_COUNT).init(0) catch unreachable;
    comptime var i: u8 = 0;
    const fields = tinfo.Struct.fields;
    if (fields.len > MAX_FIELD_COUNT) @panic("struct field count exceeded MAX_FIELD_COUNT");
    inline while (i < fields.len) {
        const f = fields.ptr[i];
        field_names.append(f) catch unreachable;
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
        .field2 = "hello \" \\\" \" world",
        .field3 = false,
        .field4 = 3.14,
    };

    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    var writer = stream.writer();
    try tomlize(Allocator, t, &writer);
    std.debug.print("\n{s}", .{buf});
}
