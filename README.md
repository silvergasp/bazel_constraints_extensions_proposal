# Constraint value and extension demonstration

This repository explores the possibility for extending Bazel's narrowing constraint_settings API for more flexible toolchains.

The issue that this proposal intends to address is the difficulty in building flexible toolchains using constraint_settings.
The constraint_value rules that set the value for a constraint_setting are mutually exclusive. In other words you can only
have one constraint_value enabled that sets a constraint_setting. This is demonstrated in the example below;

```python
constraint_setting(
    name = "simd",
)

constraint_value(
    name = "neon",
    constraint_setting = "simd",
)

constraint_value(
    name = "dsp",
    constraint_setting = "simd",
)
```

In this case a target platform can have both the ARM Neon and ARM DSP cpu extensions. This however can be represented using
Bazel's constraint_value/platform system as only one constraint_value can set a constraint_setting at any one point in time.
In this case you must **choose** between the neon extension **or** the DSP extension, and could not use **both** in the Bazel
build system.

# Broadening this definition

Bazel has the concept of build flags though these do not integrate nicely with Bazel's platforms API. This proposal combines
the two concepts in a way that allows for you to narrow the targeted platforms using the existing platforms API. As well
as broaden the configuration using build flags in a way that makes sense. See //BUILD for example.

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
