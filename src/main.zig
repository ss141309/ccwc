const std = @import("std");
const Allocator = std.mem.Allocator;

var read_bytes = false;
var read_lines = false;
var read_words = false;
var read_chars = false;

var total_bytes: usize = 0;
var total_lines: usize = 0;
var total_words: usize = 0;
var total_chars: usize = 0;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = arena.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    _ = args.skip();

    var file_names = std.ArrayList([]const u8).init(allocator);

    try parseArgs(&args, &file_names);

    for (file_names.items) |file_name| {
        const buff = try openFile(&allocator, file_name);

        if (read_bytes) {
            const size = buff.len;
            total_bytes += size;
            try stdout.print("{} ", .{size});
        }

        if (read_lines) {
            var lines = std.mem.split(u8, buff, "\n");
            var line_count: usize = 0;

            while (lines.next()) |_| {
                line_count += 1;
            }

            total_lines += line_count;
            try stdout.print("{} ", .{line_count - 1});
        }

        if (read_words) {
            var words = std.mem.split(u8, buff, " ");
            var word_count: usize = 0;

            while (words.next()) |_| {
                word_count += 1;
            }

            total_words += word_count;
            try stdout.print("{} ", .{word_count});
        }

        if (read_chars) {
            var words = std.mem.split(u8, buff, " ");
            var char_count: usize = 0;

            while (words.next()) |word| {
                char_count += word.len;
            }

            total_chars += char_count;
            try stdout.print("{} ", .{char_count});
        }

        try stdout.print("{s}\n", .{file_name});
        try bw.flush();
    }

    if (file_names.items.len > 1) {
        if (read_bytes)
            try stdout.print("{} ", .{total_bytes});
        if (read_lines)
            try stdout.print("{} ", .{total_lines});
        if (read_words)
            try stdout.print("{} ", .{total_words});

        try stdout.print("total\n", .{});
        try bw.flush();
    }
}

fn parseArgs(args: *std.process.ArgIterator, file_names: *std.ArrayList([]const u8)) !void {
    while (args.next()) |arg| {
        if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--bytes")) {
                read_bytes = true;
            } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--lines")) {
                read_lines = true;
            } else if (std.mem.eql(u8, arg, "-w") or std.mem.eql(u8, arg, "--words")) {
                read_words = true;
            } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--chars")) {
                read_chars = true;
            }
        } else {
            try file_names.*.append(arg);
        }
    }
}

fn openFile(allocator: *Allocator, file_name: []const u8) ![]u8 {
    const stderr_file = std.io.getStdErr().writer();
    var ew = std.io.bufferedWriter(stderr_file);
    const stderr = ew.writer();

    const file = std.fs.cwd().openFile(file_name, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            try stderr.print("ccwc: {s}: No such file or directory\n", .{file_name});
            try ew.flush();
            return undefined;
        },
        else => return err,
    };
    defer file.close();

    const stat = try file.stat();
    const buff = try file.readToEndAlloc(allocator.*, stat.size);
    return buff;
}
