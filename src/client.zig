const std = @import("std");
const net = std.net;
const Address = net.Address;
const Stream = net.Stream;

pub fn trimMess(m: []u8, delim: []const u8) usize {
    var i: usize = 0;
    return for (m) |c| {
        if (std.mem.eql(u8, &[_]u8{c}, delim)) break i;
        i += 1;
    } else i;
}

pub fn main() !void {
    const addr = Address.initIp4([_]u8{ 127, 0, 0, 1}, 8080);
    var stream = try net.tcpConnectToAddress(addr);
    var buffer: [1024]u8 = undefined;
    _ = try stream.write("HELP \n");
    var nread = try stream.read(&buffer);
    const message = buffer[0..nread];
    var i: usize = trimMess(message, "\n");
    std.debug.print("read: {s}\n", .{buffer[0..i]});

    var buffer2: [1024]u8 = undefined;

    _ = try stream.write("QUIT \n");
    var mread = try stream.read(&buffer2);
    const message2 = buffer2[0..mread];
    i = trimMess(message2, "\n");
    std.debug.print("read: {s}\n", .{buffer2[0..i]});
    stream.close();
    
}