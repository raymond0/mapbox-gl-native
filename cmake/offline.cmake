add_executable(mbgl-offline
    bin/offline.cpp
)

target_sources(mbgl-offline
    PRIVATE platform/default/mbgl/util/default_styles.hpp
    PRIVATE platform/default/mbgl/util/default_styles.cpp
)

target_compile_options(mbgl-offline
    PRIVATE -fvisibility-inlines-hidden
)

target_include_directories(mbgl-offline
    PRIVATE platform/default
)

target_link_libraries(mbgl-offline
    PRIVATE mbgl-core
)

target_add_mason_package(mbgl-offline PRIVATE boost)
target_add_mason_package(mbgl-offline PRIVATE boost_libprogram_options)

mbgl_platform_offline()

create_source_groups(mbgl-offline)

xcode_create_scheme(
    TARGET mbgl-offline
    OPTIONAL_ARGS
        "--style=file.json"
        "--north=37.2"
        "--west=-122.8"
        "--south=38.1"
        "--east=-121.7"
        "--minZoom=0.0"
        "--maxZoom=15.0"
        "--pixelRatio=1.0"
        "--token="
        "--output=offline.db"
)
