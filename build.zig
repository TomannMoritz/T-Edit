const std = @import("std");
pub fn build(b: *std.Build) void {
    // --------------------------------------------------
    // Create executable
    // --------------------------------------------------
    const exe = b.addExecutable(.{
        .name = "Tedit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
        .use_llvm = true,
    });

    b.installArtifact(exe);
    const add_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&add_exe.step);


    // user can specify program arguments:
    //      `zig build run -- arg1 arg2 etc
    if (b.args) |args| {
        add_exe.addArgs(args);
    }


    // --------------------------------------------------
    // Tests
    // --------------------------------------------------
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        })
    });

    const add_test = b.addRunArtifact(unit_tests);

    const run_test = b.step("test", "Run unit tests");
    run_test.dependOn(&add_test.step);
}
