pub const __builtin_bswap16 = @import("std").zig.c_builtins.__builtin_bswap16;
pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_bswap64 = @import("std").zig.c_builtins.__builtin_bswap64;
pub const __builtin_signbit = @import("std").zig.c_builtins.__builtin_signbit;
pub const __builtin_signbitf = @import("std").zig.c_builtins.__builtin_signbitf;
pub const __builtin_popcount = @import("std").zig.c_builtins.__builtin_popcount;
pub const __builtin_ctz = @import("std").zig.c_builtins.__builtin_ctz;
pub const __builtin_clz = @import("std").zig.c_builtins.__builtin_clz;
pub const __builtin_sqrt = @import("std").zig.c_builtins.__builtin_sqrt;
pub const __builtin_sqrtf = @import("std").zig.c_builtins.__builtin_sqrtf;
pub const __builtin_sin = @import("std").zig.c_builtins.__builtin_sin;
pub const __builtin_sinf = @import("std").zig.c_builtins.__builtin_sinf;
pub const __builtin_cos = @import("std").zig.c_builtins.__builtin_cos;
pub const __builtin_cosf = @import("std").zig.c_builtins.__builtin_cosf;
pub const __builtin_exp = @import("std").zig.c_builtins.__builtin_exp;
pub const __builtin_expf = @import("std").zig.c_builtins.__builtin_expf;
pub const __builtin_exp2 = @import("std").zig.c_builtins.__builtin_exp2;
pub const __builtin_exp2f = @import("std").zig.c_builtins.__builtin_exp2f;
pub const __builtin_log = @import("std").zig.c_builtins.__builtin_log;
pub const __builtin_logf = @import("std").zig.c_builtins.__builtin_logf;
pub const __builtin_log2 = @import("std").zig.c_builtins.__builtin_log2;
pub const __builtin_log2f = @import("std").zig.c_builtins.__builtin_log2f;
pub const __builtin_log10 = @import("std").zig.c_builtins.__builtin_log10;
pub const __builtin_log10f = @import("std").zig.c_builtins.__builtin_log10f;
pub const __builtin_abs = @import("std").zig.c_builtins.__builtin_abs;
pub const __builtin_fabs = @import("std").zig.c_builtins.__builtin_fabs;
pub const __builtin_fabsf = @import("std").zig.c_builtins.__builtin_fabsf;
pub const __builtin_floor = @import("std").zig.c_builtins.__builtin_floor;
pub const __builtin_floorf = @import("std").zig.c_builtins.__builtin_floorf;
pub const __builtin_ceil = @import("std").zig.c_builtins.__builtin_ceil;
pub const __builtin_ceilf = @import("std").zig.c_builtins.__builtin_ceilf;
pub const __builtin_trunc = @import("std").zig.c_builtins.__builtin_trunc;
pub const __builtin_truncf = @import("std").zig.c_builtins.__builtin_truncf;
pub const __builtin_round = @import("std").zig.c_builtins.__builtin_round;
pub const __builtin_roundf = @import("std").zig.c_builtins.__builtin_roundf;
pub const __builtin_strlen = @import("std").zig.c_builtins.__builtin_strlen;
pub const __builtin_strcmp = @import("std").zig.c_builtins.__builtin_strcmp;
pub const __builtin_object_size = @import("std").zig.c_builtins.__builtin_object_size;
pub const __builtin___memset_chk = @import("std").zig.c_builtins.__builtin___memset_chk;
pub const __builtin_memset = @import("std").zig.c_builtins.__builtin_memset;
pub const __builtin___memcpy_chk = @import("std").zig.c_builtins.__builtin___memcpy_chk;
pub const __builtin_memcpy = @import("std").zig.c_builtins.__builtin_memcpy;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_nanf = @import("std").zig.c_builtins.__builtin_nanf;
pub const __builtin_huge_valf = @import("std").zig.c_builtins.__builtin_huge_valf;
pub const __builtin_inff = @import("std").zig.c_builtins.__builtin_inff;
pub const __builtin_isnan = @import("std").zig.c_builtins.__builtin_isnan;
pub const __builtin_isinf = @import("std").zig.c_builtins.__builtin_isinf;
pub const __builtin_isinf_sign = @import("std").zig.c_builtins.__builtin_isinf_sign;
pub const __has_builtin = @import("std").zig.c_builtins.__has_builtin;
pub const __builtin_assume = @import("std").zig.c_builtins.__builtin_assume;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;
pub const __builtin_constant_p = @import("std").zig.c_builtins.__builtin_constant_p;
pub const __builtin_mul_overflow = @import("std").zig.c_builtins.__builtin_mul_overflow;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __clang_max_align_nonce1: c_longlong align(8),
    __clang_max_align_nonce2: c_longdouble align(16),
};
pub const cgltf_size = usize;
pub const cgltf_ssize = c_longlong;
pub const cgltf_float = f32;
pub const cgltf_int = c_int;
pub const cgltf_uint = c_uint;
pub const cgltf_bool = c_int;
pub const cgltf_file_type_invalid: c_int = 0;
pub const cgltf_file_type_gltf: c_int = 1;
pub const cgltf_file_type_glb: c_int = 2;
pub const cgltf_file_type_max_enum: c_int = 3;
pub const enum_cgltf_file_type = c_uint;
pub const cgltf_file_type = enum_cgltf_file_type;
pub const cgltf_result_success: c_int = 0;
pub const cgltf_result_data_too_short: c_int = 1;
pub const cgltf_result_unknown_format: c_int = 2;
pub const cgltf_result_invalid_json: c_int = 3;
pub const cgltf_result_invalid_gltf: c_int = 4;
pub const cgltf_result_invalid_options: c_int = 5;
pub const cgltf_result_file_not_found: c_int = 6;
pub const cgltf_result_io_error: c_int = 7;
pub const cgltf_result_out_of_memory: c_int = 8;
pub const cgltf_result_legacy_gltf: c_int = 9;
pub const cgltf_result_max_enum: c_int = 10;
pub const enum_cgltf_result = c_uint;
pub const cgltf_result = enum_cgltf_result;
pub const struct_cgltf_memory_options = extern struct {
    alloc_func: ?*const fn (?*anyopaque, cgltf_size) callconv(.C) ?*anyopaque,
    free_func: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque,
};
pub const cgltf_memory_options = struct_cgltf_memory_options;
pub const struct_cgltf_file_options = extern struct {
    read: ?*const fn ([*c]const struct_cgltf_memory_options, [*c]const struct_cgltf_file_options, [*c]const u8, [*c]cgltf_size, [*c]?*anyopaque) callconv(.C) cgltf_result,
    release: ?*const fn ([*c]const struct_cgltf_memory_options, [*c]const struct_cgltf_file_options, ?*anyopaque) callconv(.C) void,
    user_data: ?*anyopaque,
};
pub const cgltf_file_options = struct_cgltf_file_options;
pub const struct_cgltf_options = extern struct {
    type: cgltf_file_type,
    json_token_count: cgltf_size,
    memory: cgltf_memory_options,
    file: cgltf_file_options,
};
pub const cgltf_options = struct_cgltf_options;
pub const cgltf_buffer_view_type_invalid: c_int = 0;
pub const cgltf_buffer_view_type_indices: c_int = 1;
pub const cgltf_buffer_view_type_vertices: c_int = 2;
pub const cgltf_buffer_view_type_max_enum: c_int = 3;
pub const enum_cgltf_buffer_view_type = c_uint;
pub const cgltf_buffer_view_type = enum_cgltf_buffer_view_type;
pub const cgltf_attribute_type_invalid: c_int = 0;
pub const cgltf_attribute_type_position: c_int = 1;
pub const cgltf_attribute_type_normal: c_int = 2;
pub const cgltf_attribute_type_tangent: c_int = 3;
pub const cgltf_attribute_type_texcoord: c_int = 4;
pub const cgltf_attribute_type_color: c_int = 5;
pub const cgltf_attribute_type_joints: c_int = 6;
pub const cgltf_attribute_type_weights: c_int = 7;
pub const cgltf_attribute_type_custom: c_int = 8;
pub const cgltf_attribute_type_max_enum: c_int = 9;
pub const enum_cgltf_attribute_type = c_uint;
pub const cgltf_attribute_type = enum_cgltf_attribute_type;
pub const cgltf_component_type_invalid: c_int = 0;
pub const cgltf_component_type_r_8: c_int = 1;
pub const cgltf_component_type_r_8u: c_int = 2;
pub const cgltf_component_type_r_16: c_int = 3;
pub const cgltf_component_type_r_16u: c_int = 4;
pub const cgltf_component_type_r_32u: c_int = 5;
pub const cgltf_component_type_r_32f: c_int = 6;
pub const cgltf_component_type_max_enum: c_int = 7;
pub const enum_cgltf_component_type = c_uint;
pub const cgltf_component_type = enum_cgltf_component_type;
pub const cgltf_type_invalid: c_int = 0;
pub const cgltf_type_scalar: c_int = 1;
pub const cgltf_type_vec2: c_int = 2;
pub const cgltf_type_vec3: c_int = 3;
pub const cgltf_type_vec4: c_int = 4;
pub const cgltf_type_mat2: c_int = 5;
pub const cgltf_type_mat3: c_int = 6;
pub const cgltf_type_mat4: c_int = 7;
pub const cgltf_type_max_enum: c_int = 8;
pub const enum_cgltf_type = c_uint;
pub const cgltf_type = enum_cgltf_type;
pub const cgltf_primitive_type_points: c_int = 0;
pub const cgltf_primitive_type_lines: c_int = 1;
pub const cgltf_primitive_type_line_loop: c_int = 2;
pub const cgltf_primitive_type_line_strip: c_int = 3;
pub const cgltf_primitive_type_triangles: c_int = 4;
pub const cgltf_primitive_type_triangle_strip: c_int = 5;
pub const cgltf_primitive_type_triangle_fan: c_int = 6;
pub const cgltf_primitive_type_max_enum: c_int = 7;
pub const enum_cgltf_primitive_type = c_uint;
pub const cgltf_primitive_type = enum_cgltf_primitive_type;
pub const cgltf_alpha_mode_opaque: c_int = 0;
pub const cgltf_alpha_mode_mask: c_int = 1;
pub const cgltf_alpha_mode_blend: c_int = 2;
pub const cgltf_alpha_mode_max_enum: c_int = 3;
pub const enum_cgltf_alpha_mode = c_uint;
pub const cgltf_alpha_mode = enum_cgltf_alpha_mode;
pub const cgltf_animation_path_type_invalid: c_int = 0;
pub const cgltf_animation_path_type_translation: c_int = 1;
pub const cgltf_animation_path_type_rotation: c_int = 2;
pub const cgltf_animation_path_type_scale: c_int = 3;
pub const cgltf_animation_path_type_weights: c_int = 4;
pub const cgltf_animation_path_type_max_enum: c_int = 5;
pub const enum_cgltf_animation_path_type = c_uint;
pub const cgltf_animation_path_type = enum_cgltf_animation_path_type;
pub const cgltf_interpolation_type_linear: c_int = 0;
pub const cgltf_interpolation_type_step: c_int = 1;
pub const cgltf_interpolation_type_cubic_spline: c_int = 2;
pub const cgltf_interpolation_type_max_enum: c_int = 3;
pub const enum_cgltf_interpolation_type = c_uint;
pub const cgltf_interpolation_type = enum_cgltf_interpolation_type;
pub const cgltf_camera_type_invalid: c_int = 0;
pub const cgltf_camera_type_perspective: c_int = 1;
pub const cgltf_camera_type_orthographic: c_int = 2;
pub const cgltf_camera_type_max_enum: c_int = 3;
pub const enum_cgltf_camera_type = c_uint;
pub const cgltf_camera_type = enum_cgltf_camera_type;
pub const cgltf_light_type_invalid: c_int = 0;
pub const cgltf_light_type_directional: c_int = 1;
pub const cgltf_light_type_point: c_int = 2;
pub const cgltf_light_type_spot: c_int = 3;
pub const cgltf_light_type_max_enum: c_int = 4;
pub const enum_cgltf_light_type = c_uint;
pub const cgltf_light_type = enum_cgltf_light_type;
pub const cgltf_data_free_method_none: c_int = 0;
pub const cgltf_data_free_method_file_release: c_int = 1;
pub const cgltf_data_free_method_memory_free: c_int = 2;
pub const cgltf_data_free_method_max_enum: c_int = 3;
pub const enum_cgltf_data_free_method = c_uint;
pub const cgltf_data_free_method = enum_cgltf_data_free_method;
pub const struct_cgltf_extras = extern struct {
    start_offset: cgltf_size,
    end_offset: cgltf_size,
    data: [*c]u8,
};
pub const cgltf_extras = struct_cgltf_extras;
pub const struct_cgltf_extension = extern struct {
    name: [*c]u8,
    data: [*c]u8,
};
pub const cgltf_extension = struct_cgltf_extension;
pub const struct_cgltf_buffer = extern struct {
    name: [*c]u8,
    size: cgltf_size,
    uri: [*c]u8,
    data: ?*anyopaque,
    data_free_method: cgltf_data_free_method,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_buffer = struct_cgltf_buffer;
pub const cgltf_meshopt_compression_mode_invalid: c_int = 0;
pub const cgltf_meshopt_compression_mode_attributes: c_int = 1;
pub const cgltf_meshopt_compression_mode_triangles: c_int = 2;
pub const cgltf_meshopt_compression_mode_indices: c_int = 3;
pub const cgltf_meshopt_compression_mode_max_enum: c_int = 4;
pub const enum_cgltf_meshopt_compression_mode = c_uint;
pub const cgltf_meshopt_compression_mode = enum_cgltf_meshopt_compression_mode;
pub const cgltf_meshopt_compression_filter_none: c_int = 0;
pub const cgltf_meshopt_compression_filter_octahedral: c_int = 1;
pub const cgltf_meshopt_compression_filter_quaternion: c_int = 2;
pub const cgltf_meshopt_compression_filter_exponential: c_int = 3;
pub const cgltf_meshopt_compression_filter_max_enum: c_int = 4;
pub const enum_cgltf_meshopt_compression_filter = c_uint;
pub const cgltf_meshopt_compression_filter = enum_cgltf_meshopt_compression_filter;
pub const struct_cgltf_meshopt_compression = extern struct {
    buffer: [*c]cgltf_buffer,
    offset: cgltf_size,
    size: cgltf_size,
    stride: cgltf_size,
    count: cgltf_size,
    mode: cgltf_meshopt_compression_mode,
    filter: cgltf_meshopt_compression_filter,
};
pub const cgltf_meshopt_compression = struct_cgltf_meshopt_compression;
pub const struct_cgltf_buffer_view = extern struct {
    name: [*c]u8,
    buffer: [*c]cgltf_buffer,
    offset: cgltf_size,
    size: cgltf_size,
    stride: cgltf_size,
    type: cgltf_buffer_view_type,
    data: ?*anyopaque,
    has_meshopt_compression: cgltf_bool,
    meshopt_compression: cgltf_meshopt_compression,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_buffer_view = struct_cgltf_buffer_view;
pub const struct_cgltf_accessor_sparse = extern struct {
    count: cgltf_size,
    indices_buffer_view: [*c]cgltf_buffer_view,
    indices_byte_offset: cgltf_size,
    indices_component_type: cgltf_component_type,
    values_buffer_view: [*c]cgltf_buffer_view,
    values_byte_offset: cgltf_size,
    extras: cgltf_extras,
    indices_extras: cgltf_extras,
    values_extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
    indices_extensions_count: cgltf_size,
    indices_extensions: [*c]cgltf_extension,
    values_extensions_count: cgltf_size,
    values_extensions: [*c]cgltf_extension,
};
pub const cgltf_accessor_sparse = struct_cgltf_accessor_sparse;
pub const struct_cgltf_accessor = extern struct {
    name: [*c]u8,
    component_type: cgltf_component_type,
    normalized: cgltf_bool,
    type: cgltf_type,
    offset: cgltf_size,
    count: cgltf_size,
    stride: cgltf_size,
    buffer_view: [*c]cgltf_buffer_view,
    has_min: cgltf_bool,
    min: [16]cgltf_float,
    has_max: cgltf_bool,
    max: [16]cgltf_float,
    is_sparse: cgltf_bool,
    sparse: cgltf_accessor_sparse,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_accessor = struct_cgltf_accessor;
pub const struct_cgltf_attribute = extern struct {
    name: [*c]u8,
    type: cgltf_attribute_type,
    index: cgltf_int,
    data: [*c]cgltf_accessor,
};
pub const cgltf_attribute = struct_cgltf_attribute;
pub const struct_cgltf_image = extern struct {
    name: [*c]u8,
    uri: [*c]u8,
    buffer_view: [*c]cgltf_buffer_view,
    mime_type: [*c]u8,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_image = struct_cgltf_image;
pub const struct_cgltf_sampler = extern struct {
    name: [*c]u8,
    mag_filter: cgltf_int,
    min_filter: cgltf_int,
    wrap_s: cgltf_int,
    wrap_t: cgltf_int,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_sampler = struct_cgltf_sampler;
pub const struct_cgltf_texture = extern struct {
    name: [*c]u8,
    image: [*c]cgltf_image,
    sampler: [*c]cgltf_sampler,
    has_basisu: cgltf_bool,
    basisu_image: [*c]cgltf_image,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_texture = struct_cgltf_texture;
pub const struct_cgltf_texture_transform = extern struct {
    offset: [2]cgltf_float,
    rotation: cgltf_float,
    scale: [2]cgltf_float,
    has_texcoord: cgltf_bool,
    texcoord: cgltf_int,
};
pub const cgltf_texture_transform = struct_cgltf_texture_transform;
pub const struct_cgltf_texture_view = extern struct {
    texture: [*c]cgltf_texture,
    texcoord: cgltf_int,
    scale: cgltf_float,
    has_transform: cgltf_bool,
    transform: cgltf_texture_transform,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_texture_view = struct_cgltf_texture_view;
pub const struct_cgltf_pbr_metallic_roughness = extern struct {
    base_color_texture: cgltf_texture_view,
    metallic_roughness_texture: cgltf_texture_view,
    base_color_factor: [4]cgltf_float,
    metallic_factor: cgltf_float,
    roughness_factor: cgltf_float,
};
pub const cgltf_pbr_metallic_roughness = struct_cgltf_pbr_metallic_roughness;
pub const struct_cgltf_pbr_specular_glossiness = extern struct {
    diffuse_texture: cgltf_texture_view,
    specular_glossiness_texture: cgltf_texture_view,
    diffuse_factor: [4]cgltf_float,
    specular_factor: [3]cgltf_float,
    glossiness_factor: cgltf_float,
};
pub const cgltf_pbr_specular_glossiness = struct_cgltf_pbr_specular_glossiness;
pub const struct_cgltf_clearcoat = extern struct {
    clearcoat_texture: cgltf_texture_view,
    clearcoat_roughness_texture: cgltf_texture_view,
    clearcoat_normal_texture: cgltf_texture_view,
    clearcoat_factor: cgltf_float,
    clearcoat_roughness_factor: cgltf_float,
};
pub const cgltf_clearcoat = struct_cgltf_clearcoat;
pub const struct_cgltf_transmission = extern struct {
    transmission_texture: cgltf_texture_view,
    transmission_factor: cgltf_float,
};
pub const cgltf_transmission = struct_cgltf_transmission;
pub const struct_cgltf_ior = extern struct {
    ior: cgltf_float,
};
pub const cgltf_ior = struct_cgltf_ior;
pub const struct_cgltf_specular = extern struct {
    specular_texture: cgltf_texture_view,
    specular_color_texture: cgltf_texture_view,
    specular_color_factor: [3]cgltf_float,
    specular_factor: cgltf_float,
};
pub const cgltf_specular = struct_cgltf_specular;
pub const struct_cgltf_volume = extern struct {
    thickness_texture: cgltf_texture_view,
    thickness_factor: cgltf_float,
    attenuation_color: [3]cgltf_float,
    attenuation_distance: cgltf_float,
};
pub const cgltf_volume = struct_cgltf_volume;
pub const struct_cgltf_sheen = extern struct {
    sheen_color_texture: cgltf_texture_view,
    sheen_color_factor: [3]cgltf_float,
    sheen_roughness_texture: cgltf_texture_view,
    sheen_roughness_factor: cgltf_float,
};
pub const cgltf_sheen = struct_cgltf_sheen;
pub const struct_cgltf_emissive_strength = extern struct {
    emissive_strength: cgltf_float,
};
pub const cgltf_emissive_strength = struct_cgltf_emissive_strength;
pub const struct_cgltf_iridescence = extern struct {
    iridescence_factor: cgltf_float,
    iridescence_texture: cgltf_texture_view,
    iridescence_ior: cgltf_float,
    iridescence_thickness_min: cgltf_float,
    iridescence_thickness_max: cgltf_float,
    iridescence_thickness_texture: cgltf_texture_view,
};
pub const cgltf_iridescence = struct_cgltf_iridescence;
pub const struct_cgltf_material = extern struct {
    name: [*c]u8,
    has_pbr_metallic_roughness: cgltf_bool,
    has_pbr_specular_glossiness: cgltf_bool,
    has_clearcoat: cgltf_bool,
    has_transmission: cgltf_bool,
    has_volume: cgltf_bool,
    has_ior: cgltf_bool,
    has_specular: cgltf_bool,
    has_sheen: cgltf_bool,
    has_emissive_strength: cgltf_bool,
    has_iridescence: cgltf_bool,
    pbr_metallic_roughness: cgltf_pbr_metallic_roughness,
    pbr_specular_glossiness: cgltf_pbr_specular_glossiness,
    clearcoat: cgltf_clearcoat,
    ior: cgltf_ior,
    specular: cgltf_specular,
    sheen: cgltf_sheen,
    transmission: cgltf_transmission,
    volume: cgltf_volume,
    emissive_strength: cgltf_emissive_strength,
    iridescence: cgltf_iridescence,
    normal_texture: cgltf_texture_view,
    occlusion_texture: cgltf_texture_view,
    emissive_texture: cgltf_texture_view,
    emissive_factor: [3]cgltf_float,
    alpha_mode: cgltf_alpha_mode,
    alpha_cutoff: cgltf_float,
    double_sided: cgltf_bool,
    unlit: cgltf_bool,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_material = struct_cgltf_material;
pub const struct_cgltf_material_mapping = extern struct {
    variant: cgltf_size,
    material: [*c]cgltf_material,
    extras: cgltf_extras,
};
pub const cgltf_material_mapping = struct_cgltf_material_mapping;
pub const struct_cgltf_morph_target = extern struct {
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
};
pub const cgltf_morph_target = struct_cgltf_morph_target;
pub const struct_cgltf_draco_mesh_compression = extern struct {
    buffer_view: [*c]cgltf_buffer_view,
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
};
pub const cgltf_draco_mesh_compression = struct_cgltf_draco_mesh_compression;
pub const struct_cgltf_mesh_gpu_instancing = extern struct {
    buffer_view: [*c]cgltf_buffer_view,
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
};
pub const cgltf_mesh_gpu_instancing = struct_cgltf_mesh_gpu_instancing;
pub const struct_cgltf_primitive = extern struct {
    type: cgltf_primitive_type,
    indices: [*c]cgltf_accessor,
    material: [*c]cgltf_material,
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
    targets: [*c]cgltf_morph_target,
    targets_count: cgltf_size,
    extras: cgltf_extras,
    has_draco_mesh_compression: cgltf_bool,
    draco_mesh_compression: cgltf_draco_mesh_compression,
    mappings: [*c]cgltf_material_mapping,
    mappings_count: cgltf_size,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_primitive = struct_cgltf_primitive;
pub const struct_cgltf_mesh = extern struct {
    name: [*c]u8,
    primitives: [*c]cgltf_primitive,
    primitives_count: cgltf_size,
    weights: [*c]cgltf_float,
    weights_count: cgltf_size,
    target_names: [*c][*c]u8,
    target_names_count: cgltf_size,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_mesh = struct_cgltf_mesh;
pub const cgltf_node = struct_cgltf_node;
pub const struct_cgltf_skin = extern struct {
    name: [*c]u8,
    joints: [*c][*c]cgltf_node,
    joints_count: cgltf_size,
    skeleton: [*c]cgltf_node,
    inverse_bind_matrices: [*c]cgltf_accessor,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_skin = struct_cgltf_skin;
pub const struct_cgltf_camera_perspective = extern struct {
    has_aspect_ratio: cgltf_bool,
    aspect_ratio: cgltf_float,
    yfov: cgltf_float,
    has_zfar: cgltf_bool,
    zfar: cgltf_float,
    znear: cgltf_float,
    extras: cgltf_extras,
};
pub const cgltf_camera_perspective = struct_cgltf_camera_perspective;
pub const struct_cgltf_camera_orthographic = extern struct {
    xmag: cgltf_float,
    ymag: cgltf_float,
    zfar: cgltf_float,
    znear: cgltf_float,
    extras: cgltf_extras,
};
pub const cgltf_camera_orthographic = struct_cgltf_camera_orthographic;
const union_unnamed_1 = extern union {
    perspective: cgltf_camera_perspective,
    orthographic: cgltf_camera_orthographic,
};
pub const struct_cgltf_camera = extern struct {
    name: [*c]u8,
    type: cgltf_camera_type,
    data: union_unnamed_1,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_camera = struct_cgltf_camera;
pub const struct_cgltf_light = extern struct {
    name: [*c]u8,
    color: [3]cgltf_float,
    intensity: cgltf_float,
    type: cgltf_light_type,
    range: cgltf_float,
    spot_inner_cone_angle: cgltf_float,
    spot_outer_cone_angle: cgltf_float,
    extras: cgltf_extras,
};
pub const cgltf_light = struct_cgltf_light;
pub const struct_cgltf_node = extern struct {
    name: [*c]u8,
    parent: [*c]cgltf_node,
    children: [*c][*c]cgltf_node,
    children_count: cgltf_size,
    skin: [*c]cgltf_skin,
    mesh: [*c]cgltf_mesh,
    camera: [*c]cgltf_camera,
    light: [*c]cgltf_light,
    weights: [*c]cgltf_float,
    weights_count: cgltf_size,
    has_translation: cgltf_bool,
    has_rotation: cgltf_bool,
    has_scale: cgltf_bool,
    has_matrix: cgltf_bool,
    translation: [3]cgltf_float,
    rotation: [4]cgltf_float,
    scale: [3]cgltf_float,
    matrix: [16]cgltf_float,
    extras: cgltf_extras,
    has_mesh_gpu_instancing: cgltf_bool,
    mesh_gpu_instancing: cgltf_mesh_gpu_instancing,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const struct_cgltf_scene = extern struct {
    name: [*c]u8,
    nodes: [*c][*c]cgltf_node,
    nodes_count: cgltf_size,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_scene = struct_cgltf_scene;
pub const struct_cgltf_animation_sampler = extern struct {
    input: [*c]cgltf_accessor,
    output: [*c]cgltf_accessor,
    interpolation: cgltf_interpolation_type,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_animation_sampler = struct_cgltf_animation_sampler;
pub const struct_cgltf_animation_channel = extern struct {
    sampler: [*c]cgltf_animation_sampler,
    target_node: [*c]cgltf_node,
    target_path: cgltf_animation_path_type,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_animation_channel = struct_cgltf_animation_channel;
pub const struct_cgltf_animation = extern struct {
    name: [*c]u8,
    samplers: [*c]cgltf_animation_sampler,
    samplers_count: cgltf_size,
    channels: [*c]cgltf_animation_channel,
    channels_count: cgltf_size,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_animation = struct_cgltf_animation;
pub const struct_cgltf_material_variant = extern struct {
    name: [*c]u8,
    extras: cgltf_extras,
};
pub const cgltf_material_variant = struct_cgltf_material_variant;
pub const struct_cgltf_asset = extern struct {
    copyright: [*c]u8,
    generator: [*c]u8,
    version: [*c]u8,
    min_version: [*c]u8,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_asset = struct_cgltf_asset;
pub const struct_cgltf_data = extern struct {
    file_type: cgltf_file_type,
    file_data: ?*anyopaque,
    asset: cgltf_asset,
    meshes: [*c]cgltf_mesh,
    meshes_count: cgltf_size,
    materials: [*c]cgltf_material,
    materials_count: cgltf_size,
    accessors: [*c]cgltf_accessor,
    accessors_count: cgltf_size,
    buffer_views: [*c]cgltf_buffer_view,
    buffer_views_count: cgltf_size,
    buffers: [*c]cgltf_buffer,
    buffers_count: cgltf_size,
    images: [*c]cgltf_image,
    images_count: cgltf_size,
    textures: [*c]cgltf_texture,
    textures_count: cgltf_size,
    samplers: [*c]cgltf_sampler,
    samplers_count: cgltf_size,
    skins: [*c]cgltf_skin,
    skins_count: cgltf_size,
    cameras: [*c]cgltf_camera,
    cameras_count: cgltf_size,
    lights: [*c]cgltf_light,
    lights_count: cgltf_size,
    nodes: [*c]cgltf_node,
    nodes_count: cgltf_size,
    scenes: [*c]cgltf_scene,
    scenes_count: cgltf_size,
    scene: [*c]cgltf_scene,
    animations: [*c]cgltf_animation,
    animations_count: cgltf_size,
    variants: [*c]cgltf_material_variant,
    variants_count: cgltf_size,
    extras: cgltf_extras,
    data_extensions_count: cgltf_size,
    data_extensions: [*c]cgltf_extension,
    extensions_used: [*c][*c]u8,
    extensions_used_count: cgltf_size,
    extensions_required: [*c][*c]u8,
    extensions_required_count: cgltf_size,
    json: [*c]const u8,
    json_size: cgltf_size,
    bin: ?*const anyopaque,
    bin_size: cgltf_size,
    memory: cgltf_memory_options,
    file: cgltf_file_options,
};
pub const cgltf_data = struct_cgltf_data;
pub extern fn cgltf_parse(options: [*c]const cgltf_options, data: ?*const anyopaque, size: cgltf_size, out_data: [*c][*c]cgltf_data) cgltf_result;
pub extern fn cgltf_parse_file(options: [*c]const cgltf_options, path: [*c]const u8, out_data: [*c][*c]cgltf_data) cgltf_result;
pub extern fn cgltf_load_buffers(options: [*c]const cgltf_options, data: [*c]cgltf_data, gltf_path: [*c]const u8) cgltf_result;
pub extern fn cgltf_load_buffer_base64(options: [*c]const cgltf_options, size: cgltf_size, base64: [*c]const u8, out_data: [*c]?*anyopaque) cgltf_result;
pub extern fn cgltf_decode_string(string: [*c]u8) cgltf_size;
pub extern fn cgltf_decode_uri(uri: [*c]u8) cgltf_size;
pub extern fn cgltf_validate(data: [*c]cgltf_data) cgltf_result;
pub extern fn cgltf_free(data: [*c]cgltf_data) void;
pub extern fn cgltf_node_transform_local(node: [*c]const cgltf_node, out_matrix: [*c]cgltf_float) void;
pub extern fn cgltf_node_transform_world(node: [*c]const cgltf_node, out_matrix: [*c]cgltf_float) void;
pub extern fn cgltf_accessor_read_float(accessor: [*c]const cgltf_accessor, index: cgltf_size, out: [*c]cgltf_float, element_size: cgltf_size) cgltf_bool;
pub extern fn cgltf_accessor_read_uint(accessor: [*c]const cgltf_accessor, index: cgltf_size, out: [*c]cgltf_uint, element_size: cgltf_size) cgltf_bool;
pub extern fn cgltf_accessor_read_index(accessor: [*c]const cgltf_accessor, index: cgltf_size) cgltf_size;
pub extern fn cgltf_num_components(@"type": cgltf_type) cgltf_size;
pub extern fn cgltf_accessor_unpack_floats(accessor: [*c]const cgltf_accessor, out: [*c]cgltf_float, float_count: cgltf_size) cgltf_size;
pub extern fn cgltf_copy_extras_json(data: [*c]const cgltf_data, extras: [*c]const cgltf_extras, dest: [*c]u8, dest_size: [*c]cgltf_size) cgltf_result;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // (no file):80:9
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // (no file):86:9
pub const __FLT16_DENORM_MIN__ = @compileError("unable to translate C expr: unexpected token 'IntegerLiteral'"); // (no file):109:9
pub const __FLT16_EPSILON__ = @compileError("unable to translate C expr: unexpected token 'IntegerLiteral'"); // (no file):113:9
pub const __FLT16_MAX__ = @compileError("unable to translate C expr: unexpected token 'IntegerLiteral'"); // (no file):119:9
pub const __FLT16_MIN__ = @compileError("unable to translate C expr: unexpected token 'IntegerLiteral'"); // (no file):122:9
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // (no file):183:9
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`"); // (no file):205:9
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // (no file):213:9
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):343:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `__attribute__`"); // (no file):344:9
pub const offsetof = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`"); // /home/zak/zig/0.10.0-dev.4720+9b54c9dee/files/lib/include/stddef.h:104:9
pub const __llvm__ = @as(c_int, 1);
pub const __clang__ = @as(c_int, 1);
pub const __clang_major__ = @as(c_int, 15);
pub const __clang_minor__ = @as(c_int, 0);
pub const __clang_patchlevel__ = @as(c_int, 3);
pub const __clang_version__ = "15.0.3 (git@github.com:ziglang/zig-bootstrap.git 0ce789d0f7a4d89fdc4d9571209b6874d3e260c9)";
pub const __GNUC__ = @as(c_int, 4);
pub const __GNUC_MINOR__ = @as(c_int, 2);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 1);
pub const __GXX_ABI_VERSION = @as(c_int, 1002);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __OPENCL_MEMORY_SCOPE_WORK_ITEM = @as(c_int, 0);
pub const __OPENCL_MEMORY_SCOPE_WORK_GROUP = @as(c_int, 1);
pub const __OPENCL_MEMORY_SCOPE_DEVICE = @as(c_int, 2);
pub const __OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES = @as(c_int, 3);
pub const __OPENCL_MEMORY_SCOPE_SUB_GROUP = @as(c_int, 4);
pub const __PRAGMA_REDEFINE_EXTNAME = @as(c_int, 1);
pub const __VERSION__ = "Clang 15.0.3 (git@github.com:ziglang/zig-bootstrap.git 0ce789d0f7a4d89fdc4d9571209b6874d3e260c9)";
pub const __OBJC_BOOL_IS_BOOL = @as(c_int, 0);
pub const __CONSTANT_CFSTRINGS__ = @as(c_int, 1);
pub const __clang_literal_encoding__ = "UTF-8";
pub const __clang_wide_literal_encoding__ = "UTF-32";
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LLONG_WIDTH__ = @as(c_int, 64);
pub const __BITINT_MAXWIDTH__ = @as(c_int, 128);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __INT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __LONG_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __WCHAR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 16);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_FMTd__ = "ld";
pub const __INTMAX_FMTi__ = "li";
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_FMTo__ = "lo";
pub const __UINTMAX_FMTu__ = "lu";
pub const __UINTMAX_FMTx__ = "lx";
pub const __UINTMAX_FMTX__ = "lX";
pub const __PTRDIFF_TYPE__ = c_long;
pub const __PTRDIFF_FMTd__ = "ld";
pub const __PTRDIFF_FMTi__ = "li";
pub const __INTPTR_TYPE__ = c_long;
pub const __INTPTR_FMTd__ = "ld";
pub const __INTPTR_FMTi__ = "li";
pub const __SIZE_TYPE__ = c_ulong;
pub const __SIZE_FMTo__ = "lo";
pub const __SIZE_FMTu__ = "lu";
pub const __SIZE_FMTx__ = "lx";
pub const __SIZE_FMTX__ = "lX";
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __SIG_ATOMIC_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __UINTPTR_FMTo__ = "lo";
pub const __UINTPTR_FMTu__ = "lu";
pub const __UINTPTR_FMTx__ = "lx";
pub const __UINTPTR_FMTX__ = "lX";
pub const __FLT16_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT16_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = 4.9406564584124654e-324;
pub const __DBL_HAS_DENORM__ = @as(c_int, 1);
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = 2.2204460492503131e-16;
pub const __DBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __DBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = 1.7976931348623157e+308;
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = 2.2250738585072014e-308;
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = @as(c_int, 1);
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __LDBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __POINTER_WIDTH__ = @as(c_int, 64);
pub const __BIGGEST_ALIGNMENT__ = @as(c_int, 16);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub const __UINT16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_LEAST8_FMTd__ = "hhd";
pub const __INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const __UINT_LEAST8_FMTo__ = "hho";
pub const __UINT_LEAST8_FMTu__ = "hhu";
pub const __UINT_LEAST8_FMTx__ = "hhx";
pub const __UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_LEAST16_FMTd__ = "hd";
pub const __INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_LEAST16_FMTo__ = "ho";
pub const __UINT_LEAST16_FMTu__ = "hu";
pub const __UINT_LEAST16_FMTx__ = "hx";
pub const __UINT_LEAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_LEAST32_FMTd__ = "d";
pub const __INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_LEAST32_FMTo__ = "o";
pub const __UINT_LEAST32_FMTu__ = "u";
pub const __UINT_LEAST32_FMTx__ = "x";
pub const __UINT_LEAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_LEAST64_FMTd__ = "ld";
pub const __INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_LEAST64_FMTo__ = "lo";
pub const __UINT_LEAST64_FMTu__ = "lu";
pub const __UINT_LEAST64_FMTx__ = "lx";
pub const __UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_FAST8_FMTd__ = "hhd";
pub const __INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const __UINT_FAST8_FMTo__ = "hho";
pub const __UINT_FAST8_FMTu__ = "hhu";
pub const __UINT_FAST8_FMTx__ = "hhx";
pub const __UINT_FAST8_FMTX__ = "hhX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_FAST16_FMTd__ = "hd";
pub const __INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_FAST16_FMTo__ = "ho";
pub const __UINT_FAST16_FMTu__ = "hu";
pub const __UINT_FAST16_FMTx__ = "hx";
pub const __UINT_FAST16_FMTX__ = "hX";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_FAST32_FMTd__ = "d";
pub const __INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_FAST32_FMTo__ = "o";
pub const __UINT_FAST32_FMTu__ = "u";
pub const __UINT_FAST32_FMTx__ = "x";
pub const __UINT_FAST32_FMTX__ = "X";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_FAST64_FMTd__ = "ld";
pub const __INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_FAST64_FMTo__ = "lo";
pub const __UINT_FAST64_FMTu__ = "lu";
pub const __UINT_FAST64_FMTx__ = "lx";
pub const __UINT_FAST64_FMTX__ = "lX";
pub const __USER_LABEL_PREFIX__ = "";
pub const __FINITE_MATH_ONLY__ = @as(c_int, 0);
pub const __GNUC_STDC_INLINE__ = @as(c_int, 1);
pub const __GCC_ATOMIC_TEST_AND_SET_TRUEVAL = @as(c_int, 1);
pub const __CLANG_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __NO_INLINE__ = @as(c_int, 1);
pub const __PIC__ = @as(c_int, 2);
pub const __pic__ = @as(c_int, 2);
pub const __PIE__ = @as(c_int, 2);
pub const __pie__ = @as(c_int, 2);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __GCC_ASM_FLAG_OUTPUTS__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __corei7 = @as(c_int, 1);
pub const __corei7__ = @as(c_int, 1);
pub const __tune_corei7__ = @as(c_int, 1);
pub const __REGISTER_PREFIX__ = "";
pub const __NO_MATH_INLINES = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __SGX__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE2_MATH__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const __ELF__ = @as(c_int, 1);
pub const __gnu_linux__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const _DEBUG = @as(c_int, 1);
pub const __GCC_HAVE_DWARF2_CFI_ASM = @as(c_int, 1);
pub const CGLTF_H_INCLUDED__ = "";
pub const __STDDEF_H = "";
pub const __need_ptrdiff_t = "";
pub const __need_size_t = "";
pub const __need_wchar_t = "";
pub const __need_NULL = "";
pub const __need_STDDEF_H_misc = "";
pub const _PTRDIFF_T = "";
pub const _SIZE_T = "";
pub const _WCHAR_T = "";
pub const NULL = @import("std").zig.c_translation.cast(?*anyopaque, @as(c_int, 0));
pub const __CLANG_MAX_ALIGN_T_DEFINED = "";
