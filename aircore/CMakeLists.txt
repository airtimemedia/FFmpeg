# Copyright Airtime Media 2016

project(ffmpeg)

#
# Check for yasm
#
find_program(YASM yasm)
if(YASM STREQUAL "YASM-NOTFOUND")
  message(FATAL_ERROR "'yasm' not found. Please install. (${YASM})")
endif()

if(APPLE AND CMAKE_OSX_ARCHITECTURES)
  set(ARCHS ${CMAKE_OSX_ARCHITECTURES})
else()
  set(ARCHS ${at_target_arch})
endif()

function(is_empty_dir dir result)
  file(GLOB glob_ret "${dir}/*")
  list(LENGTH glob_ret length)
  if(length EQUAL 0)
    set(${result} 1 PARENT_SCOPE)
  else()
    set(${result} 0 PARENT_SCOPE)
  endif()
endfunction()

# Decide whether to enable specific ffmpeg plugins based on whether the
# submodule is checked out. This lets different projects choose different
# plugins through submodule selection.
set(ffmpeg_configure_flags "")
set(ffmpeg_link_libs "")

is_empty_dir("${at_media_deps_dir}/cuda" cuda_empty)
if (NOT cuda_empty)
  message("ffmpeg: enabling CUDA")
  set(ffmpeg_configure_flags
    "${ffmpeg_configure_flags} \
    --enable-nvenc \
    --enable-cuda \
    --enable-cuvid \
    --enable-libnpp \
    --extra-cflags=-I${cuda_include_dir} \
    --extra-ldflags=-L${cuda_lib_dir}"
  )
endif()

is_empty_dir("${at_deps_dir}/third_party/x264/src" libx264_empty)
if (NOT libx264_empty)
  message("ffmpeg: enabling x264")
  set(ffmpeg_configure_flags
    "${ffmpeg_configure_flags} \
    --enable-libx264"
  )
  list(APPEND ffmpeg_link_libs
    libx264
  )
endif()

is_empty_dir("${at_deps_dir}/third_party/rtmpdump/rtmpdump" rtmpdump_empty)
if (NOT rtmpdump_empty)
  message("ffmpeg: enabling rtmpdump")
  set(ffmpeg_configure_flags
    "${ffmpeg_configure_flags} \
    --enable-librtmp"
  )
  list(APPEND ffmpeg_link_libs
    librtmp
  )
endif()

is_empty_dir("${at_media_deps_dir}/freetype" freetype_empty)
if (NOT freetype_empty)
  message("ffmpeg: enabling freetype")
  set(ffmpeg_configure_flags
    "${ffmpeg_configure_flags} \
    --enable-libfreetype"
  )
  # TODO(tom): freetype should have a cmake INTERFACE library and it should be
  # appended to ffmpeg_link_libs here like the other libs
endif()

set(ffmpeg_lib_files "")
set(ffmpeg_binary_base_dir "${PROJECT_BINARY_DIR}/build")

# serialize the calls to configure by chaining dependencies since configuring
# multiple archs in parallel seems to cause issues (at least with Xcode)
set(last_configure_target "")

foreach(ARCH ${ARCHS})
  set(ffmpeg_binary_dir "${ffmpeg_binary_base_dir}/${ARCH}")
  set(ffmpeg_install_dir "${ffmpeg_binary_base_dir}/${ARCH}/install")
  set(ffmpeg_makefile "${ffmpeg_binary_dir}/Makefile")

  set(libavcodec_arch_file "${ffmpeg_binary_dir}/libavcodec/libavcodec.a")
  set(libavformat_arch_file "${ffmpeg_binary_dir}/libavformat/libavformat.a")
  set(libavutil_arch_file "${ffmpeg_binary_dir}/libavutil/libavutil.a")
  set(libswscale_arch_file "${ffmpeg_binary_dir}/libswscale/libswscale.a")
  set(libswresample_arch_file "${ffmpeg_binary_dir}/libswresample/libswresample.a")
  set(libavfilter_arch_file "${ffmpeg_binary_dir}/libavfilter/libavfilter.a")

  file(MAKE_DIRECTORY "${ffmpeg_binary_dir}")

  # run_config depends on libx264 because configure checks existence of libx264.a using pkg-config
  set(libx264_dir "${at_deps_dir}/third_party/x264")
  set(libx264_src_dir "${libx264_dir}/src")
  set(libx264_bin_arch_dir "${PROJECT_BINARY_DIR}/../x264/build")
  set(libx264_bin_dir "${libx264_bin_arch_dir}/${ARCH}")

  # run_config depends on librtmp because configure checks existence of librtmp.a using pkg-config
  set(librtmp_dir "${at_deps_dir}/third_party/rtmpdump")
  set(librtmp_src_dir "${librtmp_dir}/rtmpdump/librtmp")
  set(librtmp_bin_arch_dir "${PROJECT_BINARY_DIR}/../rtmpdump/build")
  set(librtmp_bin_dir "${librtmp_bin_arch_dir}/${ARCH}/lib")

  set(crypto_target $<TARGET_FILE:crypto>)

  # run_config depends on libcrypto and libssl because librtmp depends on them
  set(libcrypto_bin_arch_dir "${PROJECT_BINARY_DIR}/../boringssl/build")

  # run_config depends on freetype because configure checks existence of libfreetype.a using pkg-config
  set(libfreetype_dir "${at_media_deps_dir}/freetype")
  set(libfreetype_inc_dir "${libfreetype_dir}/include")
  set(libfreetype_lib_arch_dir "${PROJECT_BINARY_DIR}/../freetype")

get_filename_component(PARENT_DIR "${PROJECT_SOURCE_DIR}" DIRECTORY)

  # configure
  add_custom_command(
    OUTPUT ${ffmpeg_makefile}
    COMMAND "${PROJECT_SOURCE_DIR}/run_config.sh"
    ARGS "${PARENT_DIR}" "${AT_CMAKE_C_COMPILER} ${AT_CMAKE_C_COMPILER_ARG1}" "${CMAKE_C_FLAGS_RELEASE}"
         "${at_target_os}" "${ARCH}" "${at_ccache}" "${CMAKE_AR}" "${CMAKE_RANLIB}"
         "${libx264_src_dir}" "${libx264_bin_dir}"
         "${libfreetype_inc_dir}" "${libfreetype_lib_arch_dir}"
         "${librtmp_src_dir}" "${librtmp_bin_dir}"
         $<TARGET_FILE_DIR:crypto> $<TARGET_FILE_DIR:ssl> $<TARGET_FILE_DIR:decrepit> 
         "${cuda_include_dir}" "${cuda_lib_dir}"
         "${ffmpeg_install_dir}"
         "${ffmpeg_configure_flags}"
         "${CMAKE_SHARED_LINKER_FLAGS}"
         "${YASM}"
    WORKING_DIRECTORY ${ffmpeg_binary_dir}
    DEPENDS ${PROJECT_SOURCE_DIR}/run_config.sh ${last_configure_target}
    VERBATIM
  )

  add_custom_target(ffmpeg_configure_${ARCH}
    DEPENDS ${ffmpeg_makefile} ${ffmpeg_link_libs}
  )
  set(last_configure_target ffmpeg_configure_${ARCH})

  # make
  file(GLOB_RECURSE ffmpeg_sources src *.c *.h *.s)
  add_custom_command(
    OUTPUT ${libavcodec_arch_file} ${libavformat_arch_file} ${libavutil_arch_file} ${libswscale_arch_file} ${libswresample_arch_file} ${libavfilter_arch_file}
    COMMAND make V=1 # add V=1 for verbose output
    COMMAND make install-headers
    DEPENDS ffmpeg_configure_${ARCH} ${ffmpeg_sources}
    WORKING_DIRECTORY ${ffmpeg_binary_dir}
  )

  list(APPEND libavcodec_lib_files ${libavcodec_arch_file})
  list(APPEND libavformat_lib_files ${libavformat_arch_file})
  list(APPEND libavutil_lib_files ${libavutil_arch_file})
  list(APPEND libswscale_lib_files ${libswscale_arch_file})
  list(APPEND libswresample_lib_files ${libswresample_arch_file})
  list(APPEND libavfilter_lib_files ${libavfilter_arch_file})

endforeach()

add_custom_target(ffmpeg_build
  DEPENDS ${libavcodec_lib_files} ${libavformat_lib_files} ${libavutil_lib_files} ${libswscale_lib_files} ${libswresample_lib_files} ${libavfilter_lib_files}
  SOURCES ${ffmpeg_sources}
)

list(LENGTH CMAKE_OSX_ARCHITECTURES num_archs)
if (APPLE AND num_archs GREATER 1)
  set(ffmpeg_universal_binary_dir "${ffmpeg_binary_base_dir}/universal")
  file(MAKE_DIRECTORY "${ffmpeg_universal_binary_dir}")

  set(libavcodec_file "${ffmpeg_universal_binary_dir}/libavcodec.a")
  set(libavformat_file "${ffmpeg_universal_binary_dir}/libavformat.a")
  set(libavutil_file "${ffmpeg_universal_binary_dir}/libavutil.a")
  set(libswscale_file "${ffmpeg_universal_binary_dir}/libswscale.a")
  set(libswresample_file "${ffmpeg_universal_binary_dir}/libsweresample.a")
  set(libavfilter_file "${ffmpeg_universal_binary_dir}/libavfilter.a")

  add_custom_command(TARGET ffmpeg_build POST_BUILD
    COMMAND lipo -output ${libavcodec_file} -create ${libavcodec_lib_files}
  )
  add_custom_command(TARGET ffmpeg_build POST_BUILD
    COMMAND lipo -output ${libavformat_file} -create ${libavformat_lib_files}
  )
  add_custom_command(TARGET ffmpeg_build POST_BUILD
    COMMAND lipo -output ${libavutil_file} -create ${libavutil_lib_files}
  )
  add_custom_command(TARGET ffmpeg_build POST_BUILD
    COMMAND lipo -output ${libswscale_file} -create ${libswscale_lib_files}
  )
  add_custom_command(TARGET ffmpeg_build POST_BUILD
    COMMAND lipo -output ${libswresample_file} -create ${libswresample_lib_files}
  )
  add_custom_command(TARGET ffmpeg_build POST_BUILD
    COMMAND lipo -output ${libavfilter_file} -create ${libavfilter_lib_files}
  )
else()
  set(libavcodec_file ${libavcodec_lib_files})
  set(libavformat_file ${libavformat_lib_files})
  set(libavutil_file ${libavutil_lib_files})
  set(libswscale_file ${libswscale_lib_files})
  set(libswresample_file ${libswresample_lib_files})
  set(libavfilter_file ${libavfilter_lib_files})
endif()

# NOTE: This doesn't seem to work with ninja and ExternalProject due to this bug:
# http://public.kitware.com/Bug/view.php?id=13574
add_library(libavcodec STATIC IMPORTED GLOBAL)
set_target_properties(libavcodec
  PROPERTIES IMPORTED_LOCATION "${libavcodec_file}"
)
add_dependencies(libavcodec ffmpeg_build)

add_library(libavformat STATIC IMPORTED GLOBAL)
set_target_properties(libavformat
  PROPERTIES IMPORTED_LOCATION "${libavformat_file}"
)
add_dependencies(libavformat ffmpeg_build)

add_library(libavutil STATIC IMPORTED GLOBAL)
set_target_properties(libavutil
  PROPERTIES IMPORTED_LOCATION "${libavutil_file}"
)
add_dependencies(libavutil ffmpeg_build)

add_library(libswscale STATIC IMPORTED GLOBAL)
set_target_properties(libswscale
  PROPERTIES IMPORTED_LOCATION "${libswscale_file}"
)
add_dependencies(libswscale ffmpeg_build)

add_library(libswresample STATIC IMPORTED GLOBAL)
set_target_properties(libswresample
  PROPERTIES IMPORTED_LOCATION "${libswresample_file}"
)
add_dependencies(libswresample ffmpeg_build)

add_library(libavfilter STATIC IMPORTED GLOBAL)
set_target_properties(libavfilter
  PROPERTIES IMPORTED_LOCATION "${libavfilter_file}"
)
add_dependencies(libavfilter ffmpeg_build)

add_library(at_ffmpeg INTERFACE)
target_link_libraries(at_ffmpeg INTERFACE
  libavformat
  libavcodec
  libavfilter
  libavutil
  libswresample
  libswscale
  ${ffmpeg_link_libs}
)
if (APPLE)
  target_link_libraries(at_ffmpeg INTERFACE
    z
    "-framework VideoToolbox"
  )
endif()
target_include_directories(at_ffmpeg INTERFACE ${ffmpeg_install_dir}/include)

# NOTE(tom): shouldn't be necessary, but downstream targets that depended on at_ffmpeg weren't being built
# (perhaps because they weren't linked to at_ffmpeg, just using add_dependencies)
add_dependencies(at_ffmpeg ffmpeg_build)
