const std = @import("std");
const net = std.net;
const Address = net.Address;
const Stream = net.Stream;
const StreamServer = net.StreamServer;
const ip4Address = net.Ip4Address;
const thread = std.Thread;
const os = std.os.linux;


pub const FTP_Server = struct {

    allocator: std.mem.Allocator,
    threads: std.ArrayList(thread),
    server: StreamServer,
    addr: Address,

    pub const Code = enum { RETR, STOR, LIST, CWD, USER, QUIT, HELP };

    fn trimMess(m: []u8, delim: []const u8) usize {
        var i: usize = 0;
        return for (m) |c| {
            if (std.mem.eql(u8, &[_]u8{c}, delim)) break i;
            i += 1;
        } else i;
    }

    pub fn init(allocator: std.mem.Allocator, port: u16) FTP_Server {
        return FTP_Server{
            .server = StreamServer.init(.{.reuse_address = true}),
            .allocator = allocator,
            .threads = std.ArrayList(thread).init(allocator),
            .addr = Address.initIp4([_]u8{127, 0, 0, 1}, port),
        };
    }

    pub fn deinit(self: *FTP_Server) void {
        std.debug.print("HERE\n", .{});
        self.threads.deinit();
        self.server.close();
        self.server.deinit();
        self.* = undefined;
    }

    pub fn start(self: *FTP_Server) !void {
        try self.server.listen(@as(Address, self.addr));
        std.debug.print("Listening on {any}\n", .{self.addr});

        var i: usize = 0;

        while (i < 5) {
            var connection = try self.server.accept();
            i += 1;
            _ = try self.threads.append(try thread.spawn(.{}, handleClient, .{self, &connection}));
        }
        for (self.threads.items) |t| t.join();
    }

    fn constructMessage(self: *FTP_Server, data: []u8) ![]u8 {
        const rec: []const u8 = "Received: ";
        const slices = [_] []const u8{rec, data, "\n"};
        return try std.mem.concat( self.allocator, u8,  &slices);
    }

    pub fn handleClient(self: *FTP_Server, client_conn: *net.StreamServer.Connection) !void {
        // Init receive buffer
        var client = client_conn.*.stream;
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const reset_mode = std.heap.ArenaAllocator.ResetMode.free_all;
        const alloc = arena.allocator();

        while (true) {
            defer _ = arena.reset(reset_mode);
            var buf = try alloc.alloc(u8, 100);
            
            // Read from stream
            const n = try client.read(buf);
            
            // Convert message to Code
            const code: ?Code = std.meta.stringToEnum(Code, buf[0..trimMess(buf[0..n], " ")]);

            const trimmed = buf[0..trimMess(buf[0..n], "\n")];
            std.debug.print("MESSAGE: {s}\n", .{trimmed});

            // Did the message contain a command?
            if (code) |c| {
                switch (c) {
                    Code.HELP => std.debug.print("HELP COMMAND\n", .{}),
                    Code.QUIT => {
                        std.debug.print("EXIT COMMAND\n", .{});

                        const conc = try self.constructMessage(trimmed);
                        _ = try client.write(conc);
                        break;
                    },
                    Code.USER => std.debug.print("USER COMMAND\n", .{}),
                    Code.CWD => std.debug.print("CWD COMMAND\n", .{}),
                    Code.LIST => std.debug.print("LIST COMMAND\n", .{}),
                    Code.STOR => std.debug.print("STOR COMMAND\n", .{}),
                    Code.RETR => std.debug.print("RETR COMMAND\n", .{}),
                }
            }
            else {
                std.debug.print("{s} command not found", .{buf[0..trimMess(buf[0..n], " ")]});
            }

            const conc = try self.constructMessage(trimmed);
            _ = try client.write(conc);
        }
        std.debug.print("Closing connection...\n", .{});
        client.close();
        
    }


};



pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var server = FTP_Server.init(allocator, 8080); 
    defer server.deinit();

    try server.start();
}
