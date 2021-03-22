# Constraint value and extension demonstration

This repository explores the possibility for extending Bazel's narrowing constraint_settings API for more flexible toolchains.

The issue that this proposal intends to address is the difficulty in building flexible toolchains using constraint_settings.
The constraint_value rules that set the value for a constraint_setting are mutually exclusive. In other words you can only
have one constraint_value enabled that sets a constraint_setting. This is demonstrated in the example below;

```python
constraint_setting(
    name = "simd",
)

# ARM only
constraint_value(
    name = "neon",
    constraint_setting = "simd",
)

# Intel only
constraint_value(
    name = "avx",
    constraint_setting = "simd",
)

# Intel only
constraint_value(
    name = "sse",
    constraint_setting = "simd",
)
```

In this example the neon extension is ARM only, thus the constraint_value is useable. However the 'avx' and 'sse' intel instruction extensions often coexist in hardware. This however can't be represented using
Bazel's constraint_value/platform system as only one constraint_value can set a constraint_setting at any one point in time.
In this case you must **choose** between the neon extension **or** the DSP extension, and could not use **both** in the Bazel
build system.

# Broadening this definition

Bazel has the concept of build flags though these do not integrate nicely with Bazel's platforms API. This proposal combines
the two concepts in a way that allows for you to narrow the targeted platforms using the existing platforms API. As well
as broaden the configuration using build flags in a way that makes sense.

Addressing the above using the proposed extensions API, we can express the above example as follows;

```python
load("//constraint_extension:constraint_extension.bzl", "constraint_extension")

constraint_extension(
    name = "neon",
    # The list of cpu's that this extension can be applied to;
    target_compatible_with_extension = [
        # All cortex-A arches
        "@platforms//cpu:arm7",
        "@platforms//cpu:arm7k",
        "@platforms//cpu:arm64",
        "@platforms//cpu:arm64e",
        "@platforms//cpu:arm64_32",
    ],
)

constraint_extension(
    name = "avx",
    # The list of cpu's that this extension can be applied to;
    target_compatible_with_extension = [
        # Only x86_64
        "@platforms//cpu:x86_64",
    ],
)

constraint_extension(
    name = "sse",
    # The list of cpu's that this extension can be applied to;
    target_compatible_with_extension = [
        # Only x86_64
        "@platforms//cpu:x86_64",
    ],
)

platform(
    name = "raspberrypi4",
    constraint_values = [
        "@platforms//cpu:arm64",
        "@platforms//os:linux",
    ]
)

platform(
    name = "some_intel_x86_server",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ]
)

# This rule doesn't exist (yet) this is just a placeholder
# to demonstrate the concept
cc_toolchain_extension_config(
    name = "intel_toolchain_extension_config",
    extension_set [
        ":avx.extension",
        ":sse.extension",
    ]
)

# This rule doesn't exist (yet) this is just a placeholder
# to demonstrate the concept
cc_toolchain_extension_config(
    name = "arm_toolchain_extension_config",
    extension_set [
        ":neon.extension",
    ]
)

# Example of using target_compatible_with to filter rules with extensions
some_rule(
    name = "requires_arm_with_neon_extension",
    target_compatible_with = select(
        # Note that the build_config target is at the name attribute
        # whereas the build_flag is available from the target
        # name.extension.
        ":neon": ["@platforms//cpu:arm64"],
    )
)
```

Each of the constraint_extensions has two targets 'name' and 'name.extension'. The name.extension can be used to
enable the extension from the command line. e.g.

**Build everything for the raspberry pi 4 with neon extension enabled:**

```sh
bazel build //... --platforms=//:raspberrypi4 --//:neon.extension
```

**Build everything for the raspberry pi 4 with avx extension enabled (This should result as a build failure as avx is not compatible with ARM):**

```sh
bazel build //... --platforms=//:raspberrypi4 --//:avx.extension
```

**Build everything for x86 server with avx and sse enabled:**

```sh
bazel build //... --platforms=//:some_intel_x86_server  --//:avx.extension --//:sse.extension
```

Note here that both the avx and sse extensions can be enabled at the same time. This differs from the standard constraint*setting/constraint_value API.
It should be noted that both the constraint*{setting|value}/platforms API are not replaced by the proposed extensions API. Rather the extensions API
and the platforms api function complimentary.

## This repository

See //BUILD for example.

Running build will ignore incompatible targets;

```sh
bazel build //...
```

In this case '//:only_works_on_x86_64', will build but '//:only_works_on_x86_64_with_extension_x' will be skipped as
extension 'x' is not enabled. Running this command again with extension 'x' will result in all targets under //:BUILD
building.

```sh
bazel build //... --//extensions:x.extension
```

Explicitly trying to build '//:only_works_on_x86_64_with_extension_x' without enabling extension flag 'x' will result in a
build failure.

```sh
bazel build //:only_works_on_x86_64_with_extension_x
INFO: Build option --//extensions:x.extension has changed, discarding analysis cache.
ERROR: Target //:only_works_on_x86_64_with_extension_x is incompatible and cannot be built, but was explicitly requested.
Dependency chain:
    //:only_works_on_x86_64_with_extension_x   <-- target platform didn't satisfy constraint @platforms//:incompatible
INFO: Elapsed time: 0.365s
INFO: 0 processes.
FAILED: Build did NOT complete successfully (0 packages loaded, 55 targets configured)
```

Explicitly building '//:only_works_on_x86_64_with_extension_x' with the extension flag enabled will result in a succesful build

```sh
bazel build //:only_works_on_x86_64_with_extension_x --//extensions:x.extension
INFO: Build option --//extensions:x.extension has changed, discarding analysis cache.
INFO: Analyzed target //:only_works_on_x86_64_with_extension_x (0 packages loaded, 53 targets configured).
INFO: Found 1 target...
Target //:only_works_on_x86_64_with_extension_x up-to-date:
  bazel-bin/libonly_works_on_x86_64_with_extension_x.a
  bazel-bin/libonly_works_on_x86_64_with_extension_x.so
INFO: Elapsed time: 0.344s, Critical Path: 0.01s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
```

## Depending on an extension flag from another rule

It is possible to determine if a build flag is enabled or not by extracting the ConstraintValueExtensionInfo.value parameter of the
.extension target. This is particularly useful for building toolchain rules that depend on these broadening flags. For more information
on how to do this see the bazel docs [here](https://docs.bazel.build/versions/1.0.0/skylark/rules.html#providers).
