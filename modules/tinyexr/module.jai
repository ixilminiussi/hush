//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



TINYEXR_X86_OR_X64_CPU :: 1;

TINYEXR_LITTLE_ENDIAN :: 1;

TINYEXR_USE_MINIZ :: 1;

TINYEXR_USE_STB_ZLIB :: 0;

TINYEXR_USE_NANOZLIB :: 0;

TINYEXR_USE_PIZ :: 1;

TINYEXR_USE_ZFP :: 0;

TINYEXR_USE_THREAD :: 0;

TINYEXR_USE_OPENMP :: 0;

TINYEXR_USE_COMPILER_FP16 :: 0;

TINYEXR_HAS_FP16_COMPILER_TYPE :: 0;

TINYEXR_SUCCESS :: 0;
TINYEXR_ERROR_INVALID_MAGIC_NUMBER :: -1;
TINYEXR_ERROR_INVALID_EXR_VERSION :: -2;
TINYEXR_ERROR_INVALID_ARGUMENT :: -3;
TINYEXR_ERROR_INVALID_DATA :: -4;
TINYEXR_ERROR_INVALID_FILE :: -5;
TINYEXR_ERROR_INVALID_PARAMETER :: -6;
TINYEXR_ERROR_CANT_OPEN_FILE :: -7;
TINYEXR_ERROR_UNSUPPORTED_FORMAT :: -8;
TINYEXR_ERROR_INVALID_HEADER :: -9;
TINYEXR_ERROR_UNSUPPORTED_FEATURE :: -10;
TINYEXR_ERROR_CANT_WRITE_FILE :: -11;
TINYEXR_ERROR_SERIALIZATION_FAILED :: -12;
TINYEXR_ERROR_LAYER_NOT_FOUND :: -13;
TINYEXR_ERROR_DATA_TOO_LARGE :: -14;

TINYEXR_PIXELTYPE_UINT :: 0;
TINYEXR_PIXELTYPE_HALF :: 1;
TINYEXR_PIXELTYPE_FLOAT :: 2;

TINYEXR_MAX_HEADER_ATTRIBUTES :: 1024;
TINYEXR_MAX_CUSTOM_ATTRIBUTES :: 128;

TINYEXR_COMPRESSIONTYPE_NONE :: 0;
TINYEXR_COMPRESSIONTYPE_RLE :: 1;
TINYEXR_COMPRESSIONTYPE_ZIPS :: 2;
TINYEXR_COMPRESSIONTYPE_ZIP :: 3;
TINYEXR_COMPRESSIONTYPE_PIZ :: 4;
TINYEXR_COMPRESSIONTYPE_ZFP :: 128;

TINYEXR_ZFP_COMPRESSIONTYPE_RATE :: 0;
TINYEXR_ZFP_COMPRESSIONTYPE_PRECISION :: 1;
TINYEXR_ZFP_COMPRESSIONTYPE_ACCURACY :: 2;

TINYEXR_TILE_ONE_LEVEL :: 0;
TINYEXR_TILE_MIPMAP_LEVELS :: 1;
TINYEXR_TILE_RIPMAP_LEVELS :: 2;

TINYEXR_TILE_ROUND_DOWN :: 0;
TINYEXR_TILE_ROUND_UP :: 1;

TEXRVersion :: struct {
    version:   s32; // this must be 2

    // tile format image;
    // not zero for only a single-part "normal" tiled file (according to spec.)
    tiled:     s32;
    long_name: s32; // long name attribute

    // deep image(EXR 2.0);
    // for a multi-part file, indicates that at least one part is of type deep* (according to spec.)
    non_image: s32;
    multipart: s32; // multi-part(EXR 2.0)
}

EXRVersion :: TEXRVersion;

TEXRAttribute :: struct {
    name:  [256] u8; // name and type are up to 255 chars long.
    type:  [256] u8;
    value: *u8; // uint8_t*
    size:  s32;
    pad0:  s32;
}

EXRAttribute :: TEXRAttribute;

TEXRChannelInfo :: struct {
    name:       [256] u8; // less than 255 bytes long
    pixel_type: s32;
    x_sampling: s32;
    y_sampling: s32;
    p_linear:   u8;
    pad:        [3] u8;
}

EXRChannelInfo :: TEXRChannelInfo;

TEXRTile :: struct {
    offset_x: s32;
    offset_y: s32;
    level_x:  s32;
    level_y:  s32;

    width:    s32; // actual width in a tile.
    height:   s32; // actual height int a tile.

    images:   **u8; // image[channels][pixels]
}

EXRTile :: TEXRTile;

TEXRBox2i :: struct {
    min_x: s32;
    min_y: s32;
    max_x: s32;
    max_y: s32;
}

EXRBox2i :: TEXRBox2i;

TEXRHeader :: struct {
    pixel_aspect_ratio:    float;
    line_order:            s32;
    data_window:           EXRBox2i;
    display_window:        EXRBox2i;
    screen_window_center:  [2] float;
    screen_window_width:   float;

    chunk_count:           s32;

    // Properties for tiled format(`tiledesc`).
    tiled:                 s32;
    tile_size_x:           s32;
    tile_size_y:           s32;
    tile_level_mode:       s32;
    tile_rounding_mode:    s32;

    long_name:             s32;

    // for a single-part file, agree with the version field bit 11
    // for a multi-part file, it is consistent with the type of part
    non_image:             s32;
    multipart:             s32;
    header_len:            u32;

    // Custom attributes(exludes required attributes(e.g. `channels`,
    // `compression`, etc)
    num_custom_attributes: s32;
    // array of EXRAttribute. size =
    // `num_custom_attributes`.
    custom_attributes:     *EXRAttribute;

    channels:              *EXRChannelInfo; // [num_channels]

    pixel_types:           *s32; // Loaded pixel type(TINYEXR_PIXELTYPE_*) of `images` for

    // each channel. This is overwritten with `requested_pixel_types` when
    // loading.
    num_channels:          s32;

    compression_type:      s32; // compression type(TINYEXR_COMPRESSIONTYPE_*)
    // Filled initially by
    // ParseEXRHeaderFrom(Meomory|File), then users
    // can edit it(only valid for HALF pixel type
    // channel)
    requested_pixel_types: *s32;

    // name attribute required for multipart files;
    // must be unique and non empty (according to spec.);
    // use EXRSetNameAttr for setting value;
    // max 255 character allowed - excluding terminating zero
    name:                  [256] u8;
}

EXRHeader :: TEXRHeader;

TEXRMultiPartHeader :: struct {
    num_headers: s32;
    headers:     *EXRHeader;
}

EXRMultiPartHeader :: TEXRMultiPartHeader;

TEXRImage :: struct {
    // Tiled pixel data. The application must reconstruct image
    // from tiles manually. NULL if scanline format.
    tiles:        *EXRTile;

    next_level:   *TEXRImage; // NULL if scanline format or image is the last level.
    level_x:      s32; // x level index
    level_y:      s32; // y level index

    images:       **u8; // image[channels][pixels]. NULL if tiled format.

    width:        s32;
    height:       s32;
    num_channels: s32;

    // Properties for tile format.
    num_tiles:    s32;
}

EXRImage :: TEXRImage;

TEXRMultiPartImage :: struct {
    num_images: s32;
    images:     *EXRImage;
}

EXRMultiPartImage :: TEXRMultiPartImage;

TDeepImage :: struct {
    channel_names: **u8;
    image:         ***float; // image[channels][scanlines][samples]
    offset_table:  **s32; // offset_table[scanline][offsets]
    num_channels:  s32;
    width:         s32;
    height:        s32;
    pad0:          s32;
}

DeepImage :: TDeepImage;

// @deprecated { For backward compatibility. Not recommended to use. }
// Loads single-frame OpenEXR image. Assume EXR image contains A(single channel
// alpha) or RGB(A) channels.
// Application must free image data as returned by `out_rgba`
// Result image format is: float x RGBA x width x hight
// Returns negative value and may set error string in `err` when there's an
// error
LoadEXR :: (out_rgba: **float, width: *s32, height: *s32, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Loads single-frame OpenEXR image by specifying layer name. Assume EXR image
// contains A(single channel alpha) or RGB(A) channels. Application must free
// image data as returned by `out_rgba` Result image format is: float x RGBA x
// width x hight Returns negative value and may set error string in `err` when
// there's an error When the specified layer name is not found in the EXR file,
// the function will return `TINYEXR_ERROR_LAYER_NOT_FOUND`.
LoadEXRWithLayer :: (out_rgba: **float, width: *s32, height: *s32, filename: *u8, layer_name: *u8, err: **u8) -> s32 #foreign tinyexr;

//
// Get layer infos from EXR file.
//
// @param[out] layer_names List of layer names. Application must free memory
// after using this.
// @param[out] num_layers The number of layers
// @param[out] err Error string(will be filled when the function returns error
// code). Free it using FreeEXRErrorMessage after using this value.
//
// @return TINYEXR_SUCCEES upon success.
//
EXRLayers :: (filename: *u8, layer_names: ***u8, num_layers: *s32, err: **u8) -> s32 #foreign tinyexr;

// @deprecated
// Simple wrapper API for ParseEXRHeaderFromFile.
// checking given file is a EXR file(by just look up header)
// @return TINYEXR_SUCCEES for EXR image, TINYEXR_ERROR_INVALID_HEADER for
// others
IsEXR :: (filename: *u8) -> s32 #foreign tinyexr;

// Simple wrapper API for ParseEXRHeaderFromMemory.
// Check if given data is a EXR image(by just looking up a header section)
// @return TINYEXR_SUCCEES for EXR image, TINYEXR_ERROR_INVALID_HEADER for
// others
IsEXRFromMemory :: (memory: *u8, size: u64) -> s32 #foreign tinyexr;

// @deprecated
// Saves single-frame OpenEXR image to a buffer. Assume EXR image contains RGB(A) channels.
// components must be 1(Grayscale), 3(RGB) or 4(RGBA).
// Input image format is: `float x width x height`, or `float x RGB(A) x width x
// hight`
// Save image as fp16(HALF) format when `save_as_fp16` is positive non-zero
// value.
// Save image as fp32(FLOAT) format when `save_as_fp16` is 0.
// Use ZIP compression by default.
// `buffer` is the pointer to write EXR data.
// Memory for `buffer` is allocated internally in SaveEXRToMemory.
// Returns the data size of EXR file when the value is positive(up to 2GB EXR data).
// Returns negative value and may set error string in `err` when there's an
// error
SaveEXRToMemory :: (data: *float, width: s32, height: s32, components: s32, save_as_fp16: s32, buffer: **u8, err: **u8) -> s32 #foreign tinyexr;

// @deprecated { Not recommended, but handy to use. }
// Saves single-frame OpenEXR image to a buffer. Assume EXR image contains RGB(A) channels.
// components must be 1(Grayscale), 3(RGB) or 4(RGBA).
// Input image format is: `float x width x height`, or `float x RGB(A) x width x
// hight`
// Save image as fp16(HALF) format when `save_as_fp16` is positive non-zero
// value.
// Save image as fp32(FLOAT) format when `save_as_fp16` is 0.
// Use ZIP compression by default.
// Returns TINYEXR_SUCCEES(0) when success.
// Returns negative value and may set error string in `err` when there's an
// error
SaveEXR :: (data: *float, width: s32, height: s32, components: s32, save_as_fp16: s32, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Returns the number of resolution levels of the image (including the base)
EXRNumLevels :: (exr_image: *EXRImage) -> s32 #foreign tinyexr;

// Initialize EXRHeader struct
InitEXRHeader :: (exr_header: *EXRHeader) -> void #foreign tinyexr;

// Set name attribute of EXRHeader struct (it makes a copy)
EXRSetNameAttr :: (exr_header: *EXRHeader, name: *u8) -> void #foreign tinyexr;

// Initialize EXRImage struct
InitEXRImage :: (exr_image: *EXRImage) -> void #foreign tinyexr;

// Frees internal data of EXRHeader struct
FreeEXRHeader :: (exr_header: *EXRHeader) -> s32 #foreign tinyexr;

// Frees internal data of EXRImage struct
FreeEXRImage :: (exr_image: *EXRImage) -> s32 #foreign tinyexr;

// Frees error message
FreeEXRErrorMessage :: (msg: *u8) -> void #foreign tinyexr;

// Parse EXR version header of a file.
ParseEXRVersionFromFile :: (version: *EXRVersion, filename: *u8) -> s32 #foreign tinyexr;

// Parse EXR version header from memory-mapped EXR data.
ParseEXRVersionFromMemory :: (version: *EXRVersion, memory: *u8, size: u64) -> s32 #foreign tinyexr;

// Parse single-part OpenEXR header from a file and initialize `EXRHeader`.
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
ParseEXRHeaderFromFile :: (header: *EXRHeader, version: *EXRVersion, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Parse single-part OpenEXR header from a memory and initialize `EXRHeader`.
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
ParseEXRHeaderFromMemory :: (header: *EXRHeader, version: *EXRVersion, memory: *u8, size: u64, err: **u8) -> s32 #foreign tinyexr;

// Parse multi-part OpenEXR headers from a file and initialize `EXRHeader*`
// array.
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
ParseEXRMultipartHeaderFromFile :: (headers: ***EXRHeader, num_headers: *s32, version: *EXRVersion, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Parse multi-part OpenEXR headers from a memory and initialize `EXRHeader*`
// array
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
ParseEXRMultipartHeaderFromMemory :: (headers: ***EXRHeader, num_headers: *s32, version: *EXRVersion, memory: *u8, size: u64, err: **u8) -> s32 #foreign tinyexr;

// Loads single-part OpenEXR image from a file.
// Application must setup `ParseEXRHeaderFromFile` before calling this function.
// Application can free EXRImage using `FreeEXRImage`
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
LoadEXRImageFromFile :: (image: *EXRImage, header: *EXRHeader, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Loads single-part OpenEXR image from a memory.
// Application must setup `EXRHeader` with
// `ParseEXRHeaderFromMemory` before calling this function.
// Application can free EXRImage using `FreeEXRImage`
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
LoadEXRImageFromMemory :: (image: *EXRImage, header: *EXRHeader, memory: *u8, size: u64, err: **u8) -> s32 #foreign tinyexr;

// Loads multi-part OpenEXR image from a file.
// Application must setup `ParseEXRMultipartHeaderFromFile` before calling this
// function.
// Application can free EXRImage using `FreeEXRImage`
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
LoadEXRMultipartImageFromFile :: (images: *EXRImage, headers: **EXRHeader, num_parts: u32, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Loads multi-part OpenEXR image from a memory.
// Application must setup `EXRHeader*` array with
// `ParseEXRMultipartHeaderFromMemory` before calling this function.
// Application can free EXRImage using `FreeEXRImage`
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
LoadEXRMultipartImageFromMemory :: (images: *EXRImage, headers: **EXRHeader, num_parts: u32, memory: *u8, size: u64, err: **u8) -> s32 #foreign tinyexr;

// Saves multi-channel, single-frame OpenEXR image to a file.
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
SaveEXRImageToFile :: (image: *EXRImage, exr_header: *EXRHeader, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Saves multi-channel, single-frame OpenEXR image to a memory.
// Image is compressed using EXRImage.compression value.
// Return the number of bytes if success.
// Return zero and will set error string in `err` when there's an
// error.
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
SaveEXRImageToMemory :: (image: *EXRImage, exr_header: *EXRHeader, memory: **u8, err: **u8) -> u64 #foreign tinyexr;

// Saves multi-channel, multi-frame OpenEXR image to a memory.
// Image is compressed using EXRImage.compression value.
// File global attributes (eg. display_window) must be set in the first header.
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
SaveEXRMultipartImageToFile :: (images: *EXRImage, exr_headers: **EXRHeader, num_parts: u32, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// Saves multi-channel, multi-frame OpenEXR image to a memory.
// Image is compressed using EXRImage.compression value.
// File global attributes (eg. display_window) must be set in the first header.
// Return the number of bytes if success.
// Return zero and will set error string in `err` when there's an
// error.
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
SaveEXRMultipartImageToMemory :: (images: *EXRImage, exr_headers: **EXRHeader, num_parts: u32, memory: **u8, err: **u8) -> u64 #foreign tinyexr;

// Loads single-frame OpenEXR deep image.
// Application must free memory of variables in DeepImage(image, offset_table)
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
LoadDeepEXR :: (out_image: *DeepImage, filename: *u8, err: **u8) -> s32 #foreign tinyexr;

// For emscripten.
// Loads single-frame OpenEXR image from memory. Assume EXR image contains
// RGB(A) channels.
// Returns negative value and may set error string in `err` when there's an
// error
// When there was an error message, Application must free `err` with
// FreeEXRErrorMessage()
LoadEXRFromMemory :: (out_rgba: **float, width: *s32, height: *s32, memory: *u8, size: u64, err: **u8) -> s32 #foreign tinyexr;

#scope_file

#import "Basic"; // For assert


#run {
    {
        info := type_info(TEXRVersion);
        for info.members {
            if it.name == {
                case "version";
                    assert(it.offset_in_bytes == 0, "TEXRVersion.version has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRVersion.version has unexpected size % instead of 4", it.type.runtime_size);
                case "tiled";
                    assert(it.offset_in_bytes == 4, "TEXRVersion.tiled has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRVersion.tiled has unexpected size % instead of 4", it.type.runtime_size);
                case "long_name";
                    assert(it.offset_in_bytes == 8, "TEXRVersion.long_name has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRVersion.long_name has unexpected size % instead of 4", it.type.runtime_size);
                case "non_image";
                    assert(it.offset_in_bytes == 12, "TEXRVersion.non_image has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRVersion.non_image has unexpected size % instead of 4", it.type.runtime_size);
                case "multipart";
                    assert(it.offset_in_bytes == 16, "TEXRVersion.multipart has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRVersion.multipart has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRVersion) == 20, "TEXRVersion has size % instead of 20", size_of(TEXRVersion));
    }

    {
        info := type_info(TEXRAttribute);
        for info.members {
            if it.name == {
                case "name";
                    assert(it.offset_in_bytes == 0, "TEXRAttribute.name has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 256, "TEXRAttribute.name has unexpected size % instead of 256", it.type.runtime_size);
                case "type";
                    assert(it.offset_in_bytes == 256, "TEXRAttribute.type has unexpected offset % instead of 256", it.offset_in_bytes);
                    assert(it.type.runtime_size == 256, "TEXRAttribute.type has unexpected size % instead of 256", it.type.runtime_size);
                case "value";
                    assert(it.offset_in_bytes == 512, "TEXRAttribute.value has unexpected offset % instead of 512", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRAttribute.value has unexpected size % instead of 8", it.type.runtime_size);
                case "size";
                    assert(it.offset_in_bytes == 520, "TEXRAttribute.size has unexpected offset % instead of 520", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRAttribute.size has unexpected size % instead of 4", it.type.runtime_size);
                case "pad0";
                    assert(it.offset_in_bytes == 524, "TEXRAttribute.pad0 has unexpected offset % instead of 524", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRAttribute.pad0 has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRAttribute) == 528, "TEXRAttribute has size % instead of 528", size_of(TEXRAttribute));
    }

    {
        info := type_info(TEXRChannelInfo);
        for info.members {
            if it.name == {
                case "name";
                    assert(it.offset_in_bytes == 0, "TEXRChannelInfo.name has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 256, "TEXRChannelInfo.name has unexpected size % instead of 256", it.type.runtime_size);
                case "pixel_type";
                    assert(it.offset_in_bytes == 256, "TEXRChannelInfo.pixel_type has unexpected offset % instead of 256", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRChannelInfo.pixel_type has unexpected size % instead of 4", it.type.runtime_size);
                case "x_sampling";
                    assert(it.offset_in_bytes == 260, "TEXRChannelInfo.x_sampling has unexpected offset % instead of 260", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRChannelInfo.x_sampling has unexpected size % instead of 4", it.type.runtime_size);
                case "y_sampling";
                    assert(it.offset_in_bytes == 264, "TEXRChannelInfo.y_sampling has unexpected offset % instead of 264", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRChannelInfo.y_sampling has unexpected size % instead of 4", it.type.runtime_size);
                case "p_linear";
                    assert(it.offset_in_bytes == 268, "TEXRChannelInfo.p_linear has unexpected offset % instead of 268", it.offset_in_bytes);
                    assert(it.type.runtime_size == 1, "TEXRChannelInfo.p_linear has unexpected size % instead of 1", it.type.runtime_size);
                case "pad";
                    assert(it.offset_in_bytes == 269, "TEXRChannelInfo.pad has unexpected offset % instead of 269", it.offset_in_bytes);
                    assert(it.type.runtime_size == 3, "TEXRChannelInfo.pad has unexpected size % instead of 3", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRChannelInfo) == 272, "TEXRChannelInfo has size % instead of 272", size_of(TEXRChannelInfo));
    }

    {
        info := type_info(TEXRTile);
        for info.members {
            if it.name == {
                case "offset_x";
                    assert(it.offset_in_bytes == 0, "TEXRTile.offset_x has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRTile.offset_x has unexpected size % instead of 4", it.type.runtime_size);
                case "offset_y";
                    assert(it.offset_in_bytes == 4, "TEXRTile.offset_y has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRTile.offset_y has unexpected size % instead of 4", it.type.runtime_size);
                case "level_x";
                    assert(it.offset_in_bytes == 8, "TEXRTile.level_x has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRTile.level_x has unexpected size % instead of 4", it.type.runtime_size);
                case "level_y";
                    assert(it.offset_in_bytes == 12, "TEXRTile.level_y has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRTile.level_y has unexpected size % instead of 4", it.type.runtime_size);
                case "width";
                    assert(it.offset_in_bytes == 16, "TEXRTile.width has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRTile.width has unexpected size % instead of 4", it.type.runtime_size);
                case "height";
                    assert(it.offset_in_bytes == 20, "TEXRTile.height has unexpected offset % instead of 20", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRTile.height has unexpected size % instead of 4", it.type.runtime_size);
                case "images";
                    assert(it.offset_in_bytes == 24, "TEXRTile.images has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRTile.images has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRTile) == 32, "TEXRTile has size % instead of 32", size_of(TEXRTile));
    }

    {
        info := type_info(TEXRBox2i);
        for info.members {
            if it.name == {
                case "min_x";
                    assert(it.offset_in_bytes == 0, "TEXRBox2i.min_x has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRBox2i.min_x has unexpected size % instead of 4", it.type.runtime_size);
                case "min_y";
                    assert(it.offset_in_bytes == 4, "TEXRBox2i.min_y has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRBox2i.min_y has unexpected size % instead of 4", it.type.runtime_size);
                case "max_x";
                    assert(it.offset_in_bytes == 8, "TEXRBox2i.max_x has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRBox2i.max_x has unexpected size % instead of 4", it.type.runtime_size);
                case "max_y";
                    assert(it.offset_in_bytes == 12, "TEXRBox2i.max_y has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRBox2i.max_y has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRBox2i) == 16, "TEXRBox2i has size % instead of 16", size_of(TEXRBox2i));
    }

    {
        info := type_info(TEXRHeader);
        for info.members {
            if it.name == {
                case "pixel_aspect_ratio";
                    assert(it.offset_in_bytes == 0, "TEXRHeader.pixel_aspect_ratio has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.pixel_aspect_ratio has unexpected size % instead of 4", it.type.runtime_size);
                case "line_order";
                    assert(it.offset_in_bytes == 4, "TEXRHeader.line_order has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.line_order has unexpected size % instead of 4", it.type.runtime_size);
                case "data_window";
                    assert(it.offset_in_bytes == 8, "TEXRHeader.data_window has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 16, "TEXRHeader.data_window has unexpected size % instead of 16", it.type.runtime_size);
                case "display_window";
                    assert(it.offset_in_bytes == 24, "TEXRHeader.display_window has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 16, "TEXRHeader.display_window has unexpected size % instead of 16", it.type.runtime_size);
                case "screen_window_center";
                    assert(it.offset_in_bytes == 40, "TEXRHeader.screen_window_center has unexpected offset % instead of 40", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRHeader.screen_window_center has unexpected size % instead of 8", it.type.runtime_size);
                case "screen_window_width";
                    assert(it.offset_in_bytes == 48, "TEXRHeader.screen_window_width has unexpected offset % instead of 48", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.screen_window_width has unexpected size % instead of 4", it.type.runtime_size);
                case "chunk_count";
                    assert(it.offset_in_bytes == 52, "TEXRHeader.chunk_count has unexpected offset % instead of 52", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.chunk_count has unexpected size % instead of 4", it.type.runtime_size);
                case "tiled";
                    assert(it.offset_in_bytes == 56, "TEXRHeader.tiled has unexpected offset % instead of 56", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.tiled has unexpected size % instead of 4", it.type.runtime_size);
                case "tile_size_x";
                    assert(it.offset_in_bytes == 60, "TEXRHeader.tile_size_x has unexpected offset % instead of 60", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.tile_size_x has unexpected size % instead of 4", it.type.runtime_size);
                case "tile_size_y";
                    assert(it.offset_in_bytes == 64, "TEXRHeader.tile_size_y has unexpected offset % instead of 64", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.tile_size_y has unexpected size % instead of 4", it.type.runtime_size);
                case "tile_level_mode";
                    assert(it.offset_in_bytes == 68, "TEXRHeader.tile_level_mode has unexpected offset % instead of 68", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.tile_level_mode has unexpected size % instead of 4", it.type.runtime_size);
                case "tile_rounding_mode";
                    assert(it.offset_in_bytes == 72, "TEXRHeader.tile_rounding_mode has unexpected offset % instead of 72", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.tile_rounding_mode has unexpected size % instead of 4", it.type.runtime_size);
                case "long_name";
                    assert(it.offset_in_bytes == 76, "TEXRHeader.long_name has unexpected offset % instead of 76", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.long_name has unexpected size % instead of 4", it.type.runtime_size);
                case "non_image";
                    assert(it.offset_in_bytes == 80, "TEXRHeader.non_image has unexpected offset % instead of 80", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.non_image has unexpected size % instead of 4", it.type.runtime_size);
                case "multipart";
                    assert(it.offset_in_bytes == 84, "TEXRHeader.multipart has unexpected offset % instead of 84", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.multipart has unexpected size % instead of 4", it.type.runtime_size);
                case "header_len";
                    assert(it.offset_in_bytes == 88, "TEXRHeader.header_len has unexpected offset % instead of 88", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.header_len has unexpected size % instead of 4", it.type.runtime_size);
                case "num_custom_attributes";
                    assert(it.offset_in_bytes == 92, "TEXRHeader.num_custom_attributes has unexpected offset % instead of 92", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.num_custom_attributes has unexpected size % instead of 4", it.type.runtime_size);
                case "custom_attributes";
                    assert(it.offset_in_bytes == 96, "TEXRHeader.custom_attributes has unexpected offset % instead of 96", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRHeader.custom_attributes has unexpected size % instead of 8", it.type.runtime_size);
                case "channels";
                    assert(it.offset_in_bytes == 104, "TEXRHeader.channels has unexpected offset % instead of 104", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRHeader.channels has unexpected size % instead of 8", it.type.runtime_size);
                case "pixel_types";
                    assert(it.offset_in_bytes == 112, "TEXRHeader.pixel_types has unexpected offset % instead of 112", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRHeader.pixel_types has unexpected size % instead of 8", it.type.runtime_size);
                case "num_channels";
                    assert(it.offset_in_bytes == 120, "TEXRHeader.num_channels has unexpected offset % instead of 120", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.num_channels has unexpected size % instead of 4", it.type.runtime_size);
                case "compression_type";
                    assert(it.offset_in_bytes == 124, "TEXRHeader.compression_type has unexpected offset % instead of 124", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRHeader.compression_type has unexpected size % instead of 4", it.type.runtime_size);
                case "requested_pixel_types";
                    assert(it.offset_in_bytes == 128, "TEXRHeader.requested_pixel_types has unexpected offset % instead of 128", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRHeader.requested_pixel_types has unexpected size % instead of 8", it.type.runtime_size);
                case "name";
                    assert(it.offset_in_bytes == 136, "TEXRHeader.name has unexpected offset % instead of 136", it.offset_in_bytes);
                    assert(it.type.runtime_size == 256, "TEXRHeader.name has unexpected size % instead of 256", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRHeader) == 392, "TEXRHeader has size % instead of 392", size_of(TEXRHeader));
    }

    {
        info := type_info(TEXRMultiPartHeader);
        for info.members {
            if it.name == {
                case "num_headers";
                    assert(it.offset_in_bytes == 0, "TEXRMultiPartHeader.num_headers has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRMultiPartHeader.num_headers has unexpected size % instead of 4", it.type.runtime_size);
                case "headers";
                    assert(it.offset_in_bytes == 8, "TEXRMultiPartHeader.headers has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRMultiPartHeader.headers has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRMultiPartHeader) == 16, "TEXRMultiPartHeader has size % instead of 16", size_of(TEXRMultiPartHeader));
    }

    {
        info := type_info(TEXRImage);
        for info.members {
            if it.name == {
                case "tiles";
                    assert(it.offset_in_bytes == 0, "TEXRImage.tiles has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRImage.tiles has unexpected size % instead of 8", it.type.runtime_size);
                case "next_level";
                    assert(it.offset_in_bytes == 8, "TEXRImage.next_level has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRImage.next_level has unexpected size % instead of 8", it.type.runtime_size);
                case "level_x";
                    assert(it.offset_in_bytes == 16, "TEXRImage.level_x has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRImage.level_x has unexpected size % instead of 4", it.type.runtime_size);
                case "level_y";
                    assert(it.offset_in_bytes == 20, "TEXRImage.level_y has unexpected offset % instead of 20", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRImage.level_y has unexpected size % instead of 4", it.type.runtime_size);
                case "images";
                    assert(it.offset_in_bytes == 24, "TEXRImage.images has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRImage.images has unexpected size % instead of 8", it.type.runtime_size);
                case "width";
                    assert(it.offset_in_bytes == 32, "TEXRImage.width has unexpected offset % instead of 32", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRImage.width has unexpected size % instead of 4", it.type.runtime_size);
                case "height";
                    assert(it.offset_in_bytes == 36, "TEXRImage.height has unexpected offset % instead of 36", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRImage.height has unexpected size % instead of 4", it.type.runtime_size);
                case "num_channels";
                    assert(it.offset_in_bytes == 40, "TEXRImage.num_channels has unexpected offset % instead of 40", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRImage.num_channels has unexpected size % instead of 4", it.type.runtime_size);
                case "num_tiles";
                    assert(it.offset_in_bytes == 44, "TEXRImage.num_tiles has unexpected offset % instead of 44", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRImage.num_tiles has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRImage) == 48, "TEXRImage has size % instead of 48", size_of(TEXRImage));
    }

    {
        info := type_info(TEXRMultiPartImage);
        for info.members {
            if it.name == {
                case "num_images";
                    assert(it.offset_in_bytes == 0, "TEXRMultiPartImage.num_images has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TEXRMultiPartImage.num_images has unexpected size % instead of 4", it.type.runtime_size);
                case "images";
                    assert(it.offset_in_bytes == 8, "TEXRMultiPartImage.images has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TEXRMultiPartImage.images has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(TEXRMultiPartImage) == 16, "TEXRMultiPartImage has size % instead of 16", size_of(TEXRMultiPartImage));
    }

    {
        info := type_info(TDeepImage);
        for info.members {
            if it.name == {
                case "channel_names";
                    assert(it.offset_in_bytes == 0, "TDeepImage.channel_names has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TDeepImage.channel_names has unexpected size % instead of 8", it.type.runtime_size);
                case "image";
                    assert(it.offset_in_bytes == 8, "TDeepImage.image has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TDeepImage.image has unexpected size % instead of 8", it.type.runtime_size);
                case "offset_table";
                    assert(it.offset_in_bytes == 16, "TDeepImage.offset_table has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TDeepImage.offset_table has unexpected size % instead of 8", it.type.runtime_size);
                case "num_channels";
                    assert(it.offset_in_bytes == 24, "TDeepImage.num_channels has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TDeepImage.num_channels has unexpected size % instead of 4", it.type.runtime_size);
                case "width";
                    assert(it.offset_in_bytes == 28, "TDeepImage.width has unexpected offset % instead of 28", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TDeepImage.width has unexpected size % instead of 4", it.type.runtime_size);
                case "height";
                    assert(it.offset_in_bytes == 32, "TDeepImage.height has unexpected offset % instead of 32", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TDeepImage.height has unexpected size % instead of 4", it.type.runtime_size);
                case "pad0";
                    assert(it.offset_in_bytes == 36, "TDeepImage.pad0 has unexpected offset % instead of 36", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "TDeepImage.pad0 has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(TDeepImage) == 40, "TDeepImage has size % instead of 40", size_of(TDeepImage));
    }
}

tinyexr :: #library, no_dll "libtinyexr";
