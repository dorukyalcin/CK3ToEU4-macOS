# macOS build of the CK3ToEU4 command-line converter (no GUI).
# scripts/build.sh fills work/ (upstream source + dependencies) and then runs this.
cmake_minimum_required(VERSION 3.20)

set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Oldest macOS the build runs on")
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "librakaly's macOS release is arm64-only")
project(CK3ToEU4macOS CXX C)

option(CK3TOEU4_TESTS "Also build upstream's unit tests (needs work/upstream/commonItems/external/googletest)" OFF)

set(WORK ${CMAKE_SOURCE_DIR}/work)
set(SRC ${WORK}/upstream)
set(CONVERTER_SOURCE_DIR ${SRC}/CK3ToEU4/Source)
set(RAKALY_DIR ${WORK}/deps/rakaly)
set(OUT_DIR ${CMAKE_SOURCE_DIR}/dist/CK3ToEU4-macOS/CK3ToEU4)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release)
endif()
add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-Wno-deprecated-declarations>)

# Static ImageMagick 7.0.10-31, Q8, no HDRI: the exact version upstream ships on Windows.
# (Homebrew's Q16 HDRI build draws visibly wrong flags.)
set(ENV{PKG_CONFIG_PATH} "${WORK}/deps/imagemagick/lib/pkgconfig")
find_package(PkgConfig REQUIRED)
pkg_check_modules(MAGICK REQUIRED IMPORTED_TARGET Magick++)
find_package(Iconv REQUIRED)

include_directories(
	${SRC}
	${SRC}/commonItems
	${SRC}/commonItems/external/zip/src
	${SRC}/commonItems/external/json/single_include
	${CONVERTER_SOURCE_DIR}
)

# Lets the code build against older Apple C++ libraries; force-included through the precompiled headers below.
set(COMPAT_HEADER ${CMAKE_SOURCE_DIR}/compat/libcxx_compat.h)

#### commonItems ####
file(GLOB COMMON_SOURCES
	${SRC}/commonItems/*.cpp
	${SRC}/commonItems/ModLoader/*.cpp
	${SRC}/commonItems/Localization/*.cpp
)
list(REMOVE_ITEM COMMON_SOURCES ${SRC}/commonItems/WinUtils.cpp ${SRC}/commonItems/iconvlite.cpp)
add_library(CommonItems STATIC ${COMMON_SOURCES} ${SRC}/commonItems/external/zip/src/zip.c)
target_link_libraries(CommonItems PUBLIC Iconv::Iconv "-framework CoreFoundation")
target_precompile_headers(CommonItems PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${COMPAT_HEADER}>)

#### rakaly (save decoder) ####
add_library(rakaly SHARED IMPORTED)
set_target_properties(rakaly PROPERTIES IMPORTED_LOCATION ${RAKALY_DIR}/librakaly.dylib)

#### Converter ####
file(GLOB_RECURSE LIB_SOURCES ${CONVERTER_SOURCE_DIR}/*/*.cpp)
add_library(CK3ToEU4lib STATIC ${LIB_SOURCES})
target_link_libraries(CK3ToEU4lib PUBLIC CommonItems rakaly PkgConfig::MAGICK)

# Upstream's sources rely on these being force-included via a precompiled header.
set(PCH_HEADERS
	${COMPAT_HEADER}
	<algorithm> <sstream> <fstream> <ranges> <set> <map> <optional> <filesystem>
	${SRC}/commonItems/BulkParser.h ${SRC}/commonItems/Color.h ${SRC}/commonItems/CommonFunctions.h
	${SRC}/commonItems/CommonRegexes.h ${SRC}/commonItems/ConvenientParser.h ${SRC}/commonItems/ConverterVersion.h
	${SRC}/commonItems/Date.h ${SRC}/commonItems/GameVersion.h ${SRC}/commonItems/Log.h
	${SRC}/commonItems/OSCompatibilityLayer.h ${SRC}/commonItems/Parser.h ${SRC}/commonItems/ParserHelpers.h
	${SRC}/commonItems/StringUtils.h ${SRC}/commonItems/targa.h
	${SRC}/commonItems/ModLoader/ModFilesystem.h ${SRC}/commonItems/ModLoader/Mod.h
	${SRC}/commonItems/ModLoader/ModLoader.h ${SRC}/commonItems/ModLoader/ModParser.h
	${SRC}/commonItems/Localization/LocalizationBlock.h ${SRC}/commonItems/Localization/LocalizationDatabase.h
	${SRC}/commonItems/Localization/LocalizationLambdas.h
)
target_precompile_headers(CK3ToEU4lib PUBLIC ${PCH_HEADERS})

file(GLOB MAIN_SOURCES ${CONVERTER_SOURCE_DIR}/*.cpp)
add_executable(CK3ToEU4Converter ${MAIN_SOURCES})
target_link_libraries(CK3ToEU4Converter PRIVATE CK3ToEU4lib)
target_precompile_headers(CK3ToEU4Converter REUSE_FROM CK3ToEU4lib)
set_target_properties(CK3ToEU4Converter PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY ${OUT_DIR}
	BUILD_RPATH "@executable_path"
	INSTALL_RPATH "@executable_path"
)

# Lay out the folder the way the converter expects: data files next to the binary.
add_custom_target(CopyDataFiles ALL
	DEPENDS CK3ToEU4Converter
	COMMAND ${CMAKE_COMMAND} -E copy ${RAKALY_DIR}/librakaly.dylib ${OUT_DIR}/
	COMMAND ${CMAKE_COMMAND} -E copy_directory ${SRC}/CK3ToEU4/Data_Files/configurables ${OUT_DIR}/configurables
	COMMAND ${CMAKE_COMMAND} -E copy_directory ${SRC}/CK3ToEU4/Data_Files/blankMod ${OUT_DIR}/blankMod
	COMMAND ${CMAKE_COMMAND} -E copy ${SRC}/CK3ToEU4/Data_Files/configuration-example.txt ${OUT_DIR}/
	COMMAND ${CMAKE_COMMAND} -E copy ${SRC}/CK3ToEU4/Data_Files/log.txt ${OUT_DIR}/
)

#### Upstream unit tests (run from build/tests so relative test-file paths resolve) ####
if(CK3TOEU4_TESTS)
	set(GTEST_DIR ${SRC}/commonItems/external/googletest)
	file(GLOB_RECURSE TEST_SOURCES ${SRC}/CK3ToEU4Tests/*.cpp)
	add_executable(CK3ToEU4Tests ${TEST_SOURCES}
		${GTEST_DIR}/googletest/src/gtest-all.cc
		${GTEST_DIR}/googletest/src/gtest_main.cc
		${GTEST_DIR}/googlemock/src/gmock-all.cc
	)
	target_include_directories(CK3ToEU4Tests PRIVATE
		${GTEST_DIR}/googletest ${GTEST_DIR}/googletest/include
		${GTEST_DIR}/googlemock ${GTEST_DIR}/googlemock/include
	)
	target_link_libraries(CK3ToEU4Tests PRIVATE CK3ToEU4lib)
	target_precompile_headers(CK3ToEU4Tests REUSE_FROM CK3ToEU4lib)
	set_target_properties(CK3ToEU4Tests PROPERTIES
		RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/tests
		BUILD_RPATH ${RAKALY_DIR}
	)
	file(COPY ${SRC}/CK3ToEU4Tests/TestFiles/configurables ${SRC}/CK3ToEU4Tests/TestFiles/FlagFoundry
		DESTINATION ${CMAKE_BINARY_DIR}/tests)
endif()
