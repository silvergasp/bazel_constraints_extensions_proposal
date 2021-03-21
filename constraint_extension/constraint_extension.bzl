ConstraintValueExtensionInfo = provider(
    doc = "A boolean provider that specifies if a platform extension is enabled or not",
    fields = {
        "value": "A boolean value specifying if the given platform extension is enabled or not",
    },
)

def _platform_extension_flag_impl(ctx):
    if ctx.build_setting_value:
        valid_build_setting = True
        for constraint in ctx.attr.target_compatible_with_extension:
            if not ctx.target_platform_has_constraint(constraint[platform_common.ConstraintValueInfo]):
                valid_flag = False
        if not valid_build_setting:
            fail("None of the constraint values specified for extension are enabled")
    return [ConstraintValueExtensionInfo(value = ctx.build_setting_value)]

constraints_extension_flag = rule(
    _platform_extension_flag_impl,
    build_setting = config.bool(flag = True),
    attrs = {
        "target_compatible_with_extension": attr.label_list(
            doc = "The constraint_values that are extendable with this extension",
            mandatory = True,
        ),
    },
    provides = [ConstraintValueExtensionInfo],
)

def constraint_extension(name, target_compatible_with_extension):
    """ Extends a constraint_value with extra_values

    constraint_extension creates two targets 'name' and 'name.extension'.
    'name' represents a config_setting and is exposed so that this extension
    can be used in combination with select statements. The 'name.extension'
    target can be depended on directly by other rules (e.g. toolchain rules).
    The 'name.extension' target can also be modified from the command line. In
    other words adding the cammand line --//path/to/name.extension, will enable
    the boolean type extension.

    Args:
        name: The name of the extension
        target_compatible_with_extension: A list of
        constraint_values that this extension can be applied to.

    Example:
        # Floating point extension of cortex-m processors
        # This cpu extension is only compatible with armv7-m and armv7e-m.
        # To enable this extension build with the flag
        # '--//:fpv4-sp-d16.extension'.
        constraint_extension(
            name = "fpv4-sp-d16"
            target_compatible_with_extension = [
                "@platforms//cpu:armv7e-m",
                "@platforms//cpu:armv7-m",
            ]
        )
        # This target requires the cpu extension 'fpv4-sp-d16'
        cc_library(
            name = "some_target_that_needs_fpu",
            hdrs = ["floaty_boaty.h"],
            target_compatible_with = select({
                ":fpv4-sp-d16": ["@platforms//cpu:armv7-m"]],
                "//conditions:default": ["@platforms//:incompatible"],
            })
        )
    }),
    """
    constraints_extension_flag(
        name = name + ".extension",
        target_compatible_with_extension = target_compatible_with_extension,
        build_setting_default = False,
    )
    native.config_setting(
        name = name,
        flag_values = {
            ":" + name + ".extension": "True",
        },
    )
