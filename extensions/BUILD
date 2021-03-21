load("//constraint_extension:constraint_extension.bzl", "constraint_extension")

# Extends the cpu arch x86_64 with feature x, disabled by default, enabled
# by adding the flag '--//extensions:x.extension' to the command line.
constraint_extension(
    name = "x",
    target_compatible_with_extension = ["@platforms//cpu:x86_64"],
)
