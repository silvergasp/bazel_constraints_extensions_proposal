load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "only_works_on_x86_64",
    srcs = ["dummy.cc"],
    target_compatible_with = ["@platforms//cpu:x86_64"],
)

cc_library(
    name = "only_works_on_x86_64_with_extension_x",
    srcs = ["dummy.cc"],
    target_compatible_with = select({
        "//extensions:x": ["@platforms//cpu:x86_64"],
        "//conditions:default": ["@platforms//:incompatible"],
    }),
)
