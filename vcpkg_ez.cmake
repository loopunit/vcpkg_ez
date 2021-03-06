# # Implement thusly:
#
# include(FetchContent)
# 
# macro(vcpkg_setup_ez)
# 	cmake_parse_arguments(
# 		"_arg"
# 		""
# 		"REPO;TAG;DIR;UPDATE_DISCONNECTED"
# 		""
# 		${ARGN}
# 	)
# 
# 	if(NOT _arg_TAG)
# 		set(vcpkg_ez_SOURCE_DIR ${_arg_DIR})
# 	else()
# 		FetchContent_Declare(
# 			vcpkg_ez
# 			GIT_REPOSITORY		${_arg_REPO}
# 			GIT_TAG				${_arg_TAG}
# 			SOURCE_DIR			${_arg_DIR}
# 			UPDATE_DISCONNECTED	${_arg_UPDATE_DISCONNECTED}
# 		)
# 
# 		FetchContent_GetProperties(vcpkg_ez)
# 
# 		if(NOT vcpkg_ez_POPULATED)
# 			FetchContent_Populate(vcpkg_ez)
# 		endif()
# 	endif()
# endmacro()
# 
# if(NOT VCPKG_DEVELOP_ROOT_DIR)
# 	set(VCPKG_DEVELOP_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR}/vcpkg_root)
# endif()
# 
# if(VCPKG_DEVELOP_EZ_DIR)
# 	vcpkg_setup_ez(DIR ${VCPKG_DEVELOP_EZ_DIR})
# else()
# 	vcpkg_setup_ez(
# 		REPO ???/vcpkg_ez.git
# 		TAG ???
# 		DIR ${VCPKG_DEVELOP_ROOT_DIR}/vcpkg_ez
# 	)
# endif()
# 
# include(${vcpkg_ez_SOURCE_DIR}/vcpkg_ez.cmake)
# 
# vcpkg_static_library(${PROJECT_NAME}
# 	HEADERS
# 		include/???.h
# 	SOURCES 
# 		src/???.cpp
# 	PUBLIC_INCLUDES
# 		${CMAKE_CURRENT_LIST_DIR}/include
# 	PRIVATE_INCLUDES
# 		${CMAKE_CURRENT_LIST_DIR}/src
# 	VCPACKAGES
# 		???
# 	PRIVATE_DEPENDENCIES
# 		???::???
# )
# 
# if(NOT ${VCPKG_DEVELOP_IS_PORT})
# 	vcpkg_executable(${PROJECT_NAME}_test
# 		SOURCES
# 			test/test.cpp
# 		PRIVATE_INCLUDES
# 			${CMAKE_CURRENT_LIST_DIR}/test
# 		VCPACKAGES
# 			catch2
# 		PRIVATE_DEPENDENCIES
# 			Catch2::Catch2 ???
# 	)
# endif()
#
# # In vstudio's cmakesettings.json, we can redirect the paths to the proper locations to pull these modules from local paths:
#	"cmakeCommandArgs": "-DVCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT=D:/???/dev_port_lookup.cmake -DVCPKG_DEVELOP_EZ_DIR=D:/???/vcpkg_ez -DVCPKG_DEVELOP_DIR=D:/???/vcpkg -DVCPKG_PORTS_DEVELOP_DIR=D:/???/vcpkg_ports",
#
# Ports can be locally overridden using VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT, copy dev_port_lookup.cmake to the project root & modify.
#
# See portfile.cmake for portfile implementation
#
# Someone with real cmake experience might be able to simplify a lot of this, obvs.

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(vcpkg_root_SOURCE_DIR ${VCPKG_DEVELOP_ROOT_DIR})

if(NOT DEFINED VCPKG_DEVELOP_ENABLED)
	set(VCPKG_DEVELOP_ENABLED ON)
endif()

if(NOT DEFINED VCPKG_DEVELOP_IS_PORT)
	set(VCPKG_DEVELOP_IS_PORT OFF)
endif()

if(NOT DEFINED VCPKG_DEVELOP_TRIPLET)
	set(VCPKG_DEVELOP_TRIPLET x64-windows-static-md)
endif()

if(NOT DEFINED VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT)
	set(VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT ${vcpkg_ez_SOURCE_DIR}/dev_port_lookup.cmake)
endif()

message(STATUS "VCPKG is ${VCPKG_DEVELOP_ENABLED} and using root at: ${vcpkg_root_SOURCE_DIR}")
message(STATUS "VCPKG port mode is set to ${VCPKG_DEVELOP_IS_PORT} and building for ${VCPKG_DEVELOP_TRIPLET}")

macro(vcpkg_fetch_content _arg_NAME)
	cmake_parse_arguments(
		"_arg"
		""
		"REPO;TAG;DIR;UPDATE_DISCONNECTED"
		""
		${ARGN}
	)

	if(NOT _arg_TAG)
		set(${_arg_NAME}_SOURCE_DIR ${_arg_DIR})
	else()
		FetchContent_Declare(
			${_arg_NAME}
			GIT_REPOSITORY		${_arg_REPO}
			GIT_TAG				${_arg_TAG}
			SOURCE_DIR			${_arg_DIR}
			UPDATE_DISCONNECTED	${_arg_UPDATE_DISCONNECTED}
		)

		FetchContent_GetProperties(${_arg_NAME})

		if(NOT ${_arg_NAME}_POPULATED)
			FetchContent_Populate(${_arg_NAME})
		endif()
	endif()
endmacro()


macro(vcpkg_setup)
	if(${VCPKG_DEVELOP_ENABLED})
		vcpkg_fetch_content(vcpkg ${ARGV})
	endif()
endmacro()


macro(vcpkg_build _arg_DIR)
	if(${VCPKG_DEVELOP_ENABLED})
		set(VCPKG_EXE ${_arg_DIR}/vcpkg.exe)
		
		if(EXISTS ${VCPKG_EXE})
			set(VCPKG_EXE_EXISTS true)
		else()
			set(VCPKG_EXE_EXISTS false)
		endif()
		
		if(NOT ${VCPKG_EXE_EXISTS})
			message(STATUS "Building vcpkg to: " ${VCPKG_EXE})
			execute_process(
				COMMAND				${_arg_DIR}/bootstrap-vcpkg.bat
				WORKING_DIRECTORY	${_arg_DIR}
			)
		else()
			message(STATUS "Using prebuilt vcpkg: " ${VCPKG_EXE})
		endif()
	else()
		set(VCPKG_EXE_EXISTS false)
		message(STATUS "Vcpkg disabled")
	endif()
endmacro()


macro(vcpkg_setup_ports)
	if(${VCPKG_DEVELOP_ENABLED})
		vcpkg_fetch_content(vcpkg_ports ${ARGV})
	endif()
endmacro()


function(_vcpkg_replace_string filename match_string replace_string)
	file(READ ${filename} _contents)
    string(REPLACE "${match_string}" "${replace_string}" _contents "${_contents}")
    file(WRITE ${filename} "${_contents}")
endfunction()


function(vcpkg_setup_build_root _arg_ROOT)
	cmake_parse_arguments(
		"_arg"
		""
		"VCPKG_DIR"
		""
		${ARGN}
	)

	if(NOT EXISTS ${_arg_ROOT}/scripts)
		file(INSTALL ${_arg_VCPKG_DIR}/scripts DESTINATION ${_arg_ROOT})
		_vcpkg_replace_string("${_arg_ROOT}/scripts/buildsystems/vcpkg.cmake" "_find_package" "find_package")
		_vcpkg_replace_string("${_arg_ROOT}/scripts/buildsystems/vcpkg.cmake" [=[macro(${VCPKG_OVERRIDE_FIND_PACKAGE_NAME} name)]=] [=[macro(vcpkg_find name)]=])
	endif()
	
	if(NOT EXISTS ${_arg_ROOT_DIR}/.vcpkg-root)
		file(INSTALL ${_arg_VCPKG_DIR}/.vcpkg-root DESTINATION ${_arg_ROOT})
	endif()
endfunction()


macro(vcpkg_setup_globals)
	cmake_parse_arguments(_arg "" "VCPKG_DIR;ROOT_DIR;PORTS_DIR;TARGET_TRIPLET" "" ${ARGN})
	
	set(VCPKG_EXE				${_arg_VCPKG_DIR}/vcpkg.exe		CACHE INTERNAL "VCPKG_EXE")
	set(VCPKG_DIR				${_arg_VCPKG_DIR}				CACHE INTERNAL "VCPKG_DIR")
	set(VCPKG_ROOT_DIR 			${_arg_ROOT_DIR} 				CACHE INTERNAL "VCPKG_ROOT_DIR")
	set(VCPKG_PORTS_DIR 		${_arg_PORTS_DIR} 				CACHE INTERNAL "VCPKG_PORTS_DIR")
	set(VCPKG_TARGET_TRIPLET 	${_arg_TARGET_TRIPLET} 			CACHE INTERNAL "VCPKG_TARGET_TRIPLET")
	set(VCPKG_SCRIPTS_DIR 		${VCPKG_ROOT_DIR}/scripts 		CACHE INTERNAL "VCPKG_SCRIPTS_DIR")
	set(VCPKG_BUILDTREES_ROOT	${VCPKG_ROOT_DIR}/buildtrees	CACHE INTERNAL "VCPKG_BUILDTREES_ROOT")
	set(VCPKG_INSTALLED_ROOT	${VCPKG_ROOT_DIR}/installed		CACHE INTERNAL "VCPKG_INSTALLED_ROOT")
	set(VCPKG_PACKAGES_ROOT		${VCPKG_ROOT_DIR}/packages		CACHE INTERNAL "VCPKG_PACKAGES_ROOT")
	set(VCPKG_DOWNLOADS_ROOT	${VCPKG_ROOT_DIR}/downloads		CACHE INTERNAL "VCPKG_DOWNLOADS_ROOT")
endmacro()


function(vcpkg_install)	
	if (NOT ARGN)
		message(STATUS "vcpkg_install() called with no packages to install")
		return()
	endif()

	set(USE_AUTO_VCPKG_TRIPLET "-DVCPKG_TARGET_TRIPLET=${VCPKG_TARGET_TRIPLET}")
	set(packages ${ARGN})
	list(TRANSFORM packages APPEND ":${VCPKG_TARGET_TRIPLET}")
	
	string(TOLOWER "${AUTO_VCPKG_GIT_TAG}:${packages}" packages_cache)
	
	message(STATUS "vcpkg_install() is installing packages: ${packages}")
	
	set(ENV{VCPKG_EZ_DIR} ${vcpkg_ez_SOURCE_DIR})
	set(ENV{VCPKG_DIR} ${VCPKG_DIR})
	set(ENV{VCPKG_PORTS_DIR} ${VCPKG_PORTS_DIR})
	set(ENV{VCPKG_ROOT_DIR} ${VCPKG_ROOT_DIR})
	set(ENV{VCPKG_TRIPLET} ${VCPKG_TARGET_TRIPLET})
	set(ENV{VCPKG_PORT_LOOKUP_SCRIPT} ${VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT})
	set(ENV{VCPKG_KEEP_ENV_VARS} "VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;VCPKG_ROOT_DIR;VCPKG_TRIPLET;VCPKG_PORT_LOOKUP_SCRIPT")

	#message(STATUS "VCPKG: ENV{VCPKG_EZ_DIR} ${vcpkg_ez_SOURCE_DIR})  ")
	#message(STATUS "VCPKG: ENV{VCPKG_DIR} ${VCPKG_DIR})               ")
	#message(STATUS "VCPKG: ENV{VCPKG_PORTS_DIR} ${VCPKG_PORTS_DIR})    ")
	#message(STATUS "VCPKG: ENV{VCPKG_ROOT_DIR} ${VCPKG_ROOT_DIR})     ")
	#message(STATUS "VCPKG: ENV{VCPKG_TRIPLET} ${VCPKG_TARGET_TRIPLET})")
	
	execute_process(
		COMMAND	"${VCPKG_EXE}" 
			"--x-buildtrees-root=${VCPKG_BUILDTREES_ROOT}" 
			"--x-install-root=${VCPKG_INSTALLED_ROOT}" 
			"--x-packages-root=${VCPKG_PACKAGES_ROOT}" 
#			"--x-scripts-root=${VCPKG_SCRIPTS_DIR}" 
			"--downloads-root=${VCPKG_DOWNLOADS_ROOT}" 
			"--overlay-ports=${VCPKG_PORTS_DIR}" 
			"install" ${packages}
	)

endfunction()

add_custom_target(vcpkg_ez_update
	COMMAND	
		${CMAKE_COMMAND} -E env
		"VCPKG_EZ_DIR=${vcpkg_ez_SOURCE_DIR}"
		"VCPKG_DIR=${VCPKG_DIR}"
		"VCPKG_PORTS_DIR=${VCPKG_PORTS_DIR}"
		"VCPKG_ROOT_DIR=${VCPKG_ROOT_DIR}"
		"VCPKG_TRIPLET=${VCPKG_TARGET_TRIPLET}"
		"VCPKG_PORT_LOOKUP_SCRIPT=${VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT}"
		"VCPKG_KEEP_ENV_VARS=\"VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;VCPKG_ROOT_DIR;VCPKG_TRIPLET;VCPKG_PORT_LOOKUP_SCRIPT\""
		"${VCPKG_EXE}" 
		"--x-buildtrees-root=${VCPKG_BUILDTREES_ROOT}" 
		"--x-install-root=${VCPKG_INSTALLED_ROOT}" 
		"--x-packages-root=${VCPKG_PACKAGES_ROOT}" 
#		"--x-scripts-root=${VCPKG_SCRIPTS_DIR}" 
		"--downloads-root=${VCPKG_DOWNLOADS_ROOT}" 
		"--overlay-ports=${VCPKG_PORTS_DIR}" 
		"update"
)

add_custom_target(vcpkg_ez_upgrade
	COMMAND	
		${CMAKE_COMMAND} -E env
		"VCPKG_EZ_DIR=${vcpkg_ez_SOURCE_DIR}"
		"VCPKG_DIR=${VCPKG_DIR}"
		"VCPKG_PORTS_DIR=${VCPKG_PORTS_DIR}"
		"VCPKG_ROOT_DIR=${VCPKG_ROOT_DIR}"
		"VCPKG_TRIPLET=${VCPKG_TARGET_TRIPLET}"
		"VCPKG_PORT_LOOKUP_SCRIPT=${VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT}"
		"VCPKG_KEEP_ENV_VARS=\"VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;VCPKG_ROOT_DIR;VCPKG_TRIPLET;VCPKG_PORT_LOOKUP_SCRIPT\""
		"${VCPKG_EXE}" 
		"--x-buildtrees-root=${VCPKG_BUILDTREES_ROOT}" 
		"--x-install-root=${VCPKG_INSTALLED_ROOT}" 
		"--x-packages-root=${VCPKG_PACKAGES_ROOT}" 
#		"--x-scripts-root=${VCPKG_SCRIPTS_DIR}" 
		"--downloads-root=${VCPKG_DOWNLOADS_ROOT}" 
		"--overlay-ports=${VCPKG_PORTS_DIR}" 
		"--no-dry-run"
		"upgrade"
)

add_custom_target(vcpkg_ez_remove_outdated
	COMMAND	
		${CMAKE_COMMAND} -E env
		"VCPKG_EZ_DIR=${vcpkg_ez_SOURCE_DIR}"
		"VCPKG_DIR=${VCPKG_DIR}"
		"VCPKG_PORTS_DIR=${VCPKG_PORTS_DIR}"
		"VCPKG_ROOT_DIR=${VCPKG_ROOT_DIR}"
		"VCPKG_TRIPLET=${VCPKG_TARGET_TRIPLET}"
		"VCPKG_PORT_LOOKUP_SCRIPT=${VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT}"
		"VCPKG_KEEP_ENV_VARS=\"VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;VCPKG_ROOT_DIR;VCPKG_TRIPLET;VCPKG_PORT_LOOKUP_SCRIPT\""
		"${VCPKG_EXE}" 
		"--x-buildtrees-root=${VCPKG_BUILDTREES_ROOT}" 
		"--x-install-root=${VCPKG_INSTALLED_ROOT}" 
		"--x-packages-root=${VCPKG_PACKAGES_ROOT}" 
#		"--x-scripts-root=${VCPKG_SCRIPTS_DIR}" 
		"--downloads-root=${VCPKG_DOWNLOADS_ROOT}" 
		"--overlay-ports=${VCPKG_PORTS_DIR}" 
		"remove --outdated"
)

function(vcpkg_ez_install_target _arg_PACKAGE)
	add_custom_target(vcpkg_ez_install_${_arg_PACKAGE}
		COMMAND	
			${CMAKE_COMMAND} -E env
			"VCPKG_EZ_DIR=${vcpkg_ez_SOURCE_DIR}"
			"VCPKG_DIR=${VCPKG_DIR}"
			"VCPKG_PORTS_DIR=${VCPKG_PORTS_DIR}"
			"VCPKG_ROOT_DIR=${VCPKG_ROOT_DIR}"
			"VCPKG_TRIPLET=${VCPKG_TARGET_TRIPLET}"
			"VCPKG_PORT_LOOKUP_SCRIPT=${VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT}"
			"VCPKG_KEEP_ENV_VARS=\"VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;VCPKG_ROOT_DIR;VCPKG_TRIPLET;VCPKG_PORT_LOOKUP_SCRIPT\""
			"${VCPKG_EXE}" 
			"--x-buildtrees-root=${VCPKG_BUILDTREES_ROOT}" 
			"--x-install-root=${VCPKG_INSTALLED_ROOT}" 
			"--x-packages-root=${VCPKG_PACKAGES_ROOT}" 
	#		"--x-scripts-root=${VCPKG_SCRIPTS_DIR}" 
			"--downloads-root=${VCPKG_DOWNLOADS_ROOT}" 
			"--overlay-ports=${VCPKG_PORTS_DIR}" 
			install ${_arg_PACKAGE}:${VCPKG_TARGET_TRIPLET}
	)
endfunction()

function(vcpkg_ez_uninstall_target _arg_PACKAGE)
	add_custom_target(vcpkg_ez_uninstall_${_arg_PACKAGE}
		COMMAND	
			${CMAKE_COMMAND} -E env
			"VCPKG_EZ_DIR=${vcpkg_ez_SOURCE_DIR}"
			"VCPKG_DIR=${VCPKG_DIR}"
			"VCPKG_PORTS_DIR=${VCPKG_PORTS_DIR}"
			"VCPKG_ROOT_DIR=${VCPKG_ROOT_DIR}"
			"VCPKG_TRIPLET=${VCPKG_TARGET_TRIPLET}"
			"VCPKG_PORT_LOOKUP_SCRIPT=${VCPKG_DEVELOPMENT_PORT_LOOKUP_SCRIPT}"
			"VCPKG_KEEP_ENV_VARS=\"VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;VCPKG_ROOT_DIR;VCPKG_TRIPLET;VCPKG_PORT_LOOKUP_SCRIPT\""
			"${VCPKG_EXE}" 
			"--x-buildtrees-root=${VCPKG_BUILDTREES_ROOT}" 
			"--x-install-root=${VCPKG_INSTALLED_ROOT}" 
			"--x-packages-root=${VCPKG_PACKAGES_ROOT}" 
	#		"--x-scripts-root=${VCPKG_SCRIPTS_DIR}" 
			"--downloads-root=${VCPKG_DOWNLOADS_ROOT}" 
			"--overlay-ports=${VCPKG_PORTS_DIR}" 
			remove ${_arg_PACKAGE}:${VCPKG_TARGET_TRIPLET}
	)
endfunction()

macro(vcpkg_standard_setup _arg_ROOT_DIR)
	if(${VCPKG_DEVELOP_ENABLED})
		cmake_parse_arguments(
			"_arg"
			""
			"VCPKG_EZ_DIR;VCPKG_DIR;VCPKG_PORTS_DIR;TARGET_TRIPLET"
			""
			${ARGN}
		)

		message(STATUS "VCPKG: Using vcpkg_ez from: ${vcpkg_ez_SOURCE_DIR}")
		message(STATUS "VCPKG: Using vcpkg from: ${_arg_VCPKG_DIR}")
		message(STATUS "VCPKG: Using vcpkg ports from: ${_arg_VCPKG_PORTS_DIR}")
		message(STATUS "VCPKG: Using vcpkg build root at: ${_arg_ROOT_DIR}")
	
		vcpkg_build(${_arg_VCPKG_DIR})

		vcpkg_setup_build_root(${_arg_ROOT_DIR}
			VCPKG_DIR ${_arg_VCPKG_DIR}
		)
	
		vcpkg_setup_globals(
			VCPKG_DIR 		${_arg_VCPKG_DIR}
			ROOT_DIR		${_arg_ROOT_DIR}
			PORTS_DIR		${_arg_VCPKG_PORTS_DIR}
			TARGET_TRIPLET	${_arg_TARGET_TRIPLET}
		)
	endif()
endmacro()

macro(vcpkg_common_configure_project _arg_PROJECT_NAME)
	cmake_parse_arguments(
		"_arg"
		""
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
		message(FATAL_ERROR "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there.\n")
	endif()

	if(NOT ${_arg_PROJECT_NAME}_MSVC_WARNINGS)
		set(${_arg_PROJECT_NAME}_MSVC_WARNINGS
			/W3     # Baseline reasonable warnings
			/w14242 # 'identifier': conversion from 'type1' to 'type1', possible loss
				  # of data
			/w14254 # 'operator': conversion from 'type1:field_bits' to
				  # 'type2:field_bits', possible loss of data
			/w14263 # 'function': member function does not override any base class
				  # virtual member function
			/w14265 # 'classname': class has virtual functions, but destructor is not
				  # virtual instances of this class may not be destructed correctly
			/w14287 # 'operator': unsigned/negative constant mismatch
			/we4289 # nonstandard extension used: 'variable': loop control variable
				  # declared in the for-loop is used outside the for-loop scope
			/w14296 # 'operator': expression is always 'boolean_value'
			/w14311 # 'variable': pointer truncation from 'type1' to 'type2'
			/w14545 # expression before comma evaluates to a function which is missing
				  # an argument list
			/w14546 # function call before comma missing argument list
			/w14547 # 'operator': operator before comma has no effect; expected
				  # operator with side-effect
			/w14549 # 'operator': operator before comma has no effect; did you intend
				  # 'operator'?
			/w14555 # expression has no effect; expected expression with side- effect
			/w14619 # pragma warning: there is no warning number 'number'
			/w14640 # Enable warning on thread un-safe static member initialization
			/w14826 # Conversion from 'type1' to 'type_2' is sign-extended. This may
				  # cause unexpected runtime behavior.
			/w14905 # wide string literal cast to 'LPSTR'
			/w14906 # string literal cast to 'LPWSTR'
			/w14928 # illegal copy-initialization; more than one user-defined
				  # conversion has been implicitly applied
			/permissive- # standards conformance mode for MSVC compiler.
		)
	endif()

	if (NOT ${_arg_PROJECT_NAME}_CLANG_WARNINGS)
		set(${_arg_PROJECT_NAME}_CLANG_WARNINGS
			-Wall
			-Wextra  # reasonable and standard
			-Wshadow # warn the user if a variable declaration shadows one from a
				   # parent context
			-Wnon-virtual-dtor # warn the user if a class with virtual functions has a
							 # non-virtual destructor. This helps catch hard to
							 # track down memory errors
			-Wold-style-cast # warn for c-style casts
			-Wcast-align     # warn for potential performance problem casts
			-Wunused         # warn on anything being unused
			-Woverloaded-virtual # warn if you overload (not override) a virtual
							   # function
			-Wpedantic   # warn if non-standard C++ is used
			-Wconversion # warn on type conversions that may lose data
			-Wsign-conversion  # warn on sign conversions
			-Wnull-dereference # warn if a null dereference is detected
			-Wdouble-promotion # warn if float is implicit promoted to double
			-Wformat=2 # warn on security issues around functions that format output
					 # (ie printf)
		)
	endif()
	
	if(NOT DEFINED ${_arg_PROJECT_NAME}_WARNINGS_AS_ERRORS)
		set(${_arg_PROJECT_NAME}_WARNINGS_AS_ERRORS OFF)
	endif()

	if(${${_arg_PROJECT_NAME}_WARNINGS_AS_ERRORS})
		set(${_arg_PROJECT_NAME}_CLANG_WARNINGS ${_arg_PROJECT_NAME}_CLANG_WARNINGS -Werror)
		set(${_arg_PROJECT_NAME}_MSVC_WARNINGS ${_arg_PROJECT_NAME}_MSVC_WARNINGS /WX)
	endif()
		
	if(NOT ${_arg_PROJECT_NAME}_GCC_WARNINGS)
		set(${_arg_PROJECT_NAME}_GCC_WARNINGS
			${_arg_PROJECT_NAME}_CLANG_WARNINGS
			-Wmisleading-indentation # warn if indentation implies blocks where blocks
								   # do not exist
			-Wduplicated-cond # warn if if / else chain has duplicated conditions
			-Wduplicated-branches # warn if if / else branches have duplicated code
			-Wlogical-op   # warn about logical operations being used where bitwise were
						 # probably wanted
			-Wuseless-cast # warn if you perform a cast to the same type
		)
	endif()

	if(NOT ${_arg_PROJECT_NAME}_CXX_STANDARD)
		set(${_arg_PROJECT_NAME}_CXX_STANDARD "cxx_std_17")
	endif()

	#
	# Compiler options
	#

	option(${_arg_PROJECT_NAME}_WARNINGS_AS_ERRORS "Treat compiler warnings as errors." OFF)

	#
	# Unit testing
	#
	# Currently supporting: GoogleTest, Catch2.

	option(${_arg_PROJECT_NAME}_ENABLE_UNIT_TESTING "Enable unit tests for the projects (from the `test` subfolder)." OFF)

	option(${_arg_PROJECT_NAME}_USE_GTEST "Use the GoogleTest project for creating unit tests." OFF)
	option(${_arg_PROJECT_NAME}_USE_GOOGLE_MOCK "Use the GoogleMock project for extending the unit tests." OFF)

	option(${_arg_PROJECT_NAME}_USE_CATCH2 "Use the Catch2 project for creating unit tests." OFF)
	
	#
	# Static analyzers
	#
	# Currently supporting: Clang-Tidy, Cppcheck.

	option(${_arg_PROJECT_NAME}_ENABLE_CLANG_TIDY "Enable static analysis with Clang-Tidy." OFF)
	option(${_arg_PROJECT_NAME}_ENABLE_CPPCHECK "Enable static analysis with Cppcheck." OFF)

	#
	# Code coverage
	#

	option(${_arg_PROJECT_NAME}_ENABLE_CODE_COVERAGE "Enable code coverage through GCC." OFF)

	#
	# Doxygen
	#

	option(${_arg_PROJECT_NAME}_ENABLE_DOXYGEN "Enable Doxygen documentation builds of source." OFF)

	# Etc

	option(${_arg_PROJECT_NAME}_EXPORT_COMPILE_COMMANDS "Generate compile_commands.json for clang based tools." ON)

	option(${_arg_PROJECT_NAME}_VERBOSE_OUTPUT "Enable verbose output, allowing for a better understanding of each step taken." ON)

	option(${_arg_PROJECT_NAME}_GENERATE_EXPORT_HEADER "Create a `project_export.h` file containing all exported symbols." OFF)

	option(${_arg_PROJECT_NAME}_ENABLE_LTO "Enable Interprocedural Optimization, aka Link Time Optimization (LTO)." OFF)

	option(${_arg_PROJECT_NAME}_ENABLE_CCACHE "Enable the usage of CCache, in order to speed up build times." OFF)

	if (${${_arg_PROJECT_NAME}_EXPORT_COMPILE_COMMANDS})
		set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
	endif()

	# Export all symbols when building a shared library
	if(${${_arg_PROJECT_NAME}_BUILD_SHARED_LIBS})
		set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS OFF)
		set(CMAKE_CXX_VISIBILITY_PRESET hidden)
		set(CMAKE_VISIBILITY_INLINES_HIDDEN 1)
	endif()

	if(${${_arg_PROJECT_NAME}_ENABLE_LTO})
		include(CheckIPOSupported)
		check_ipo_supported(RESULT result OUTPUT output)
		if(result)
			set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
		else()
			message(SEND_ERROR "VCPKG: IPO is not supported: ${output}.")
		endif()
	endif()

	find_program(CCACHE_FOUND ccache)
	if(CCACHE_FOUND)
		set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
		set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
	endif()
endmacro()

function(vcpkg_target_common _arg_PROJECT_NAME _arg_SCOPE)
	cmake_parse_arguments(
		"_arg"
		""
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	target_compile_features(${_arg_PROJECT_NAME} ${_arg_SCOPE} ${${_arg_PROJECT_NAME}_CXX_STANDARD})

	if(MSVC)
		set(PROJECT_WARNINGS ${${_arg_PROJECT_NAME}_MSVC_WARNINGS})
	elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
		set(PROJECT_WARNINGS ${${_arg_PROJECT_NAME}_CLANG_WARNINGS})
	elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		set(PROJECT_WARNINGS ${${_arg_PROJECT_NAME}_GCC_WARNINGS})
	else()
		message(AUTHOR_WARNING "No compiler warnings set for '${CMAKE_CXX_COMPILER_ID}' compiler.")
	endif()

	if(${${_arg_PROJECT_NAME}_BUILD_HEADERS_ONLY})
		target_compile_options(${_arg_PROJECT_NAME} INTERFACE ${PROJECT_WARNINGS})
	else()
		target_compile_options(${_arg_PROJECT_NAME} PUBLIC ${PROJECT_WARNINGS})
	endif()

	if(NOT TARGET ${_arg_PROJECT_NAME})
		message(AUTHOR_WARNING "${_arg_PROJECT_NAME} is not a target, thus no compiler warning were added.")
	endif()

	#
	# Enable Doxygen
	#

	if(${${_arg_PROJECT_NAME}_ENABLE_DOXYGEN})
		set(DOXYGEN_CALLER_GRAPH YES)
		set(DOXYGEN_CALL_GRAPH YES)
		set(DOXYGEN_EXTRACT_ALL YES)
		find_package(Doxygen REQUIRED dot)
		doxygen_add_docs(doxygen-docs ${PROJECT_SOURCE_DIR})

		verbose_message("VCPKG: Doxygen has been setup and documentation is now available.")
	endif()
	
	#
	# Set the build/user include directories
	#
	
	if (NOT ${_arg_SCOPE} STREQUAL INTERFACE)
		target_include_directories(
			${_arg_PROJECT_NAME}
			PUBLIC 
				$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
				$<INSTALL_INTERFACE:include>
		)
	endif()

	if(_arg_PUBLIC_INCLUDES)
		foreach(incl ${_arg_PUBLIC_INCLUDES})
			target_include_directories(
				${_arg_PROJECT_NAME}
				PUBLIC 
					$<BUILD_INTERFACE:${incl}>
			)
		endforeach()
	endif()

	if(_arg_PRIVATE_INCLUDES)
		foreach(incl ${_arg_PRIVATE_INCLUDES})
			target_include_directories(
				${_arg_PROJECT_NAME}
				PRIVATE
					$<BUILD_INTERFACE:${incl}>
			)
		endforeach()
	endif()

	if(_arg_INTERFACE_INCLUDES)
		foreach(incl ${_arg_INTERFACE_INCLUDES})
			target_include_directories(
				${_arg_PROJECT_NAME}
				INTERFACE
					$<BUILD_INTERFACE:${incl}>
			)
		endforeach()
	endif()


	#
	# Model project dependencies 
	#

	if(_arg_VCPACKAGES)
		if(${VCPKG_DEVELOP_ENABLED})
			vcpkg_install(${_arg_VCPACKAGES})
			
			foreach(package ${_arg_VCPACKAGES})
				if(NOT ${VCPKG_DEVELOP_IS_PORT})
					vcpkg_find(${package} CONFIG) # TODO: Needs to have a fallback or some way for this to not fail on interface libraries
				else()
					find_package(${package} CONFIG) # TODO: Needs to have a fallback or some way for this to not fail on interface libraries
				endif()
			endforeach()
			
		else()
			# Find dependencies the standard way
			foreach(package ${_arg_VCPACKAGES})
				find_package(${package} CONFIG) # TODO: Needs to have a fallback or some way for this to not fail on interface libraries
			endforeach()
		endif()
	endif()

	if(_arg_PACKAGES)
		foreach(package ${_arg_PACKAGES})
			find_package(${package} CONFIG) # TODO: Needs to have a fallback or some way for this to not fail on interface libraries
		endforeach()
	endif()

	# Identify and link with the specific "packages" the project uses
	if(_arg_PUBLIC_DEPENDENCIES)
		target_link_libraries(
		  ${_arg_PROJECT_NAME}
		  PUBLIC
			${_arg_PUBLIC_DEPENDENCIES}
		)
	endif()

	if(_arg_PRIVATE_DEPENDENCIES)
		target_link_libraries(
		  ${_arg_PROJECT_NAME}
		  PRIVATE
			${_arg_PRIVATE_DEPENDENCIES}
		)
	endif()
endfunction()

function(vcpkg_target_install_executable _arg_PROJECT_NAME)
	install(
		TARGETS
			${_arg_PROJECT_NAME}
		RUNTIME DESTINATION
			${CMAKE_INSTALL_BINDIR}
		ARCHIVE DESTINATION
			${CMAKE_INSTALL_LIBDIR}
	)
endfunction()

function(vcpkg_target_install_library _arg_PROJECT_NAME)
	cmake_parse_arguments(
		"_arg"
		"INSTALL_CONFIG_HEADER"
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	install(
		TARGETS
			${_arg_PROJECT_NAME}
		EXPORT
			${_arg_PROJECT_NAME}Targets
		LIBRARY DESTINATION
			${CMAKE_INSTALL_LIBDIR}
		RUNTIME DESTINATION
			${CMAKE_INSTALL_BINDIR}
		ARCHIVE DESTINATION
			${CMAKE_INSTALL_LIBDIR}
		INCLUDES DESTINATION
			include
		PUBLIC_HEADER DESTINATION
			include
	)

    install(
      EXPORT 
        ${_arg_PROJECT_NAME}Targets
      FILE
        ${_arg_PROJECT_NAME}Targets.cmake
      NAMESPACE
        ${_arg_PROJECT_NAME}::
      DESTINATION
        ${CMAKE_INSTALL_LIBDIR}/cmake/${_arg_PROJECT_NAME}
    )

	if(_arg_INSTALL_CONFIG_HEADER)
		# Add version header
		configure_file(
			${vcpkg_ez_SOURCE_DIR}/version.h.in
			include/${_arg_PROJECT_NAME}-version.h
			@ONLY
		)

		install(
		  FILES
			${CMAKE_CURRENT_BINARY_DIR}/include/${_arg_PROJECT_NAME}-version.h
		  DESTINATION
			include
		)
	endif()

	# Install public includes
	if(_arg_PUBLIC_INCLUDES)
		foreach(incl ${_arg_PUBLIC_INCLUDES})
			install(
			  DIRECTORY
				${incl}
			  DESTINATION
				.
			)
		endforeach()
	endif()

	# Install interface includes
	if(_arg_INTERFACE_INCLUDES)
		foreach(incl ${_arg_INTERFACE_INCLUDES})
			install(
			  DIRECTORY
				${incl}
			  DESTINATION
				.
			)
		endforeach()
	endif()

    # Quick `ConfigVersion.cmake` creation
    write_basic_package_version_file(
        ${_arg_PROJECT_NAME}ConfigVersion.cmake
      VERSION
        ${PROJECT_VERSION}
      COMPATIBILITY
        SameMajorVersion
    )

    configure_package_config_file(
      ${vcpkg_ez_SOURCE_DIR}/ProjectConfig.cmake.in
      ${CMAKE_CURRENT_BINARY_DIR}/${_arg_PROJECT_NAME}Config.cmake
      INSTALL_DESTINATION 
        ${CMAKE_INSTALL_LIBDIR}/cmake/${_arg_PROJECT_NAME}
    )

    install(
      FILES
        ${CMAKE_CURRENT_BINARY_DIR}/${_arg_PROJECT_NAME}Config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/${_arg_PROJECT_NAME}ConfigVersion.cmake
      DESTINATION
        ${CMAKE_INSTALL_LIBDIR}/cmake/${_arg_PROJECT_NAME}
    )

    # TODO: Generate export header if specified
    #if(${${_arg_PROJECT_NAME}_GENERATE_EXPORT_HEADER})
    #  include(GenerateExportHeader)
    #  generate_export_header(${_arg_PROJECT_NAME})
    #  install(
    #    FILES
    #      ${PROJECT_BINARY_DIR}/${_arg_PROJECT_NAME}_export.h 
    #    DESTINATION
    #      include
    #  )
	#endif()

endfunction()

function(vcpkg_executable _arg_PROJECT_NAME)
	cmake_parse_arguments(
		"_arg"
		""
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	if(NOT _arg_SOURCES)
		message(FATAL_ERROR "VCPKG: sources must be defined")
	endif()
	
	set(${_arg_PROJECT_NAME}_BUILD_HEADERS_ONLY OFF)
	
	vcpkg_common_configure_project(${_arg_PROJECT_NAME} ${ARGV})
	
	add_executable(${_arg_PROJECT_NAME} ${_arg_SOURCES} ${_arg_HEADERS})
	
	vcpkg_target_common(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
	
	add_executable(${_arg_PROJECT_NAME}::${_arg_PROJECT_NAME} ALIAS ${_arg_PROJECT_NAME})
	
	vcpkg_target_install_executable(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
endfunction()


function(vcpkg_static_library _arg_PROJECT_NAME)
	cmake_parse_arguments(
		"_arg"
		""
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	if(NOT _arg_SOURCES)
		message(FATAL_ERROR "VCPKG: sources must be defined")
	endif()
	
	set(${_arg_PROJECT_NAME}_BUILD_HEADERS_ONLY OFF)
	
	vcpkg_common_configure_project(${_arg_PROJECT_NAME} ${ARGV})
	
	add_library(${_arg_PROJECT_NAME} STATIC ${_arg_SOURCES} ${_arg_HEADERS})
	
	target_compile_features(${_arg_PROJECT_NAME} PUBLIC ${${_arg_PROJECT_NAME}_CXX_STANDARD})
	
	vcpkg_target_common(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
	
	add_library(${_arg_PROJECT_NAME}::${_arg_PROJECT_NAME} ALIAS ${_arg_PROJECT_NAME})
	
	vcpkg_target_install_library(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
endfunction()


function(vcpkg_interface_library _arg_PROJECT_NAME)
	cmake_parse_arguments(
		"_arg"
		""
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	if(NOT _arg_INTERFACE_INCLUDES)
		message(FATAL_ERROR "VCPKG: interface headers must be defined")
	endif()
	
	set(${_arg_PROJECT_NAME}_BUILD_HEADERS_ONLY ON)

	vcpkg_common_configure_project(${_arg_PROJECT_NAME} ${ARGV})
	
	add_library(${_arg_PROJECT_NAME} INTERFACE)
	
	#target_compile_features(${_arg_PROJECT_NAME} INTERFACE ${${_arg_PROJECT_NAME}_CXX_STANDARD})
	
	vcpkg_target_common(${_arg_PROJECT_NAME} INTERFACE ${ARGV})
	
	add_library(${_arg_PROJECT_NAME}::${_arg_PROJECT_NAME} ALIAS ${_arg_PROJECT_NAME})
	
	vcpkg_target_install_library(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
endfunction()


#    Copyright (C) 2012 Modelon AB

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the BSD style license.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    FMILIB_License.txt file for more details.

#    You should have received a copy of the FMILIB_License.txt file
#    along with this program. If not, contact Modelon AB <http://www.modelon.com>.

# Merge_static_libs(outlib lib1 lib2 ... libn) merges a number of static
# libs into a single static library
function(merge_static_libs outlib)
	set(libs ${ARGV})
	list(REMOVE_AT libs 0)
# Create a dummy file that the target will depend on
	set(dummyfile ${CMAKE_CURRENT_BINARY_DIR}/${outlib}_dummy.c)
	file(WRITE ${dummyfile} "const char * dummy = \"${dummyfile}\";")
	
	add_library(${outlib} STATIC ${dummyfile})

	if("${CMAKE_CFG_INTDIR}" STREQUAL ".")
		set(multiconfig FALSE)
	else()
		set(multiconfig TRUE)
	endif()
	
# First get the file names of the libraries to be merged	
	foreach(lib ${libs})
		get_target_property(libtype ${lib} TYPE)
		if(NOT libtype STREQUAL "STATIC_LIBRARY")
			message(FATAL_ERROR "Merge_static_libs can only process static libraries, ${lib} is a ${libtype}")
		endif()
		if(multiconfig)
			foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
				cmake_policy(PUSH)
				cmake_policy(SET CMP0026 OLD)
				get_target_property("libfile_${CONFIG_TYPE}" ${lib} "LOCATION_${CONFIG_TYPE}")
				cmake_policy(POP)
				list(APPEND libfiles_${CONFIG_TYPE} ${libfile_${CONFIG_TYPE}})
			endforeach()
		else()
			message(STATUS "Merging ${lib}")
			cmake_policy(PUSH)
			cmake_policy(SET CMP0026 OLD)
			get_target_property(libfile ${lib} LOCATION)
			cmake_policy(POP)
			message(STATUS "Merging ${libfile}")
			list(APPEND libfiles "${libfile}")
		endif(multiconfig)
	endforeach()
	message(STATUS "will be merging ${libfiles}")
# Just to be sure: cleanup from duplicates
	if(multiconfig)	
		foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
			list(REMOVE_DUPLICATES libfiles_${CONFIG_TYPE})
			set(libfiles ${libfiles} ${libfiles_${CONFIG_TYPE}})
		endforeach()
	endif()
	list(REMOVE_DUPLICATES libfiles)

# Now the easy part for MSVC and for MAC
  if(MSVC)
    # lib.exe does the merging of libraries just need to conver the list into string
	foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
		set(flags "")
		foreach(lib ${libfiles_${CONFIG_TYPE}})
			set(flags "${flags} ${lib}")
		endforeach()
		string(TOUPPER "STATIC_LIBRARY_FLAGS_${CONFIG_TYPE}" PROPNAME)
		set_target_properties(${outlib} PROPERTIES ${PROPNAME} "${flags}")
	endforeach()
	
  elseif(APPLE)
    # Use OSX's libtool to merge archives
	if(multiconfig)
		message(FATAL_ERROR "Multiple configurations are not supported")
	endif()
	get_target_property(outfile ${outlib} LOCATION)  
	add_custom_command(TARGET ${outlib} POST_BUILD
		COMMAND rm ${outfile}
		COMMAND /usr/bin/libtool -static -o ${outfile} 
		${libfiles}
	)
  else() 
  # general UNIX - need to "ar -x" and then "ar -ru"
	if(multiconfig)
		message(FATAL_ERROR "Multiple configurations are not supported")
	endif()
	get_target_property(outfile ${outlib} LOCATION)
	message(STATUS "outfile location is ${outfile}")
	foreach(lib ${libfiles})
# objlistfile will contain the list of object files for the library
		set(objlistfile ${lib}.objlist)
		set(objdir ${lib}.objdir)
		set(objlistcmake  ${objlistfile}.cmake)
# we only need to extract files once 
		if(${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/cmake.check_cache IS_NEWER_THAN ${objlistcmake})
#---------------------------------			
			FILE(WRITE ${objlistcmake}
"# Extract object files from the library
message(STATUS \"Extracting object files from ${lib}\")
EXECUTE_PROCESS(COMMAND ${CMAKE_AR} -x ${lib}                
                WORKING_DIRECTORY ${objdir})
# save the list of object files
EXECUTE_PROCESS(COMMAND ls . 
				OUTPUT_FILE ${objlistfile}
                WORKING_DIRECTORY ${objdir})")
#---------------------------------					
			file(MAKE_DIRECTORY ${objdir})
			add_custom_command(
				OUTPUT ${objlistfile}
				COMMAND ${CMAKE_COMMAND} -P ${objlistcmake}
				DEPENDS ${lib})
		endif()
		list(APPEND extrafiles "${objlistfile}")
		# relative path is needed by ar under MSYS
		file(RELATIVE_PATH objlistfilerpath ${objdir} ${objlistfile})
		add_custom_command(TARGET ${outlib} POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E echo "Running: ${CMAKE_AR} ru ${outfile} @${objlistfilerpath}"
			COMMAND ${CMAKE_AR} ru "${outfile}" @"${objlistfilerpath}"
			WORKING_DIRECTORY ${objdir})		
	endforeach()
	add_custom_command(TARGET ${outlib} POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E echo "Running: ${CMAKE_RANLIB} ${outfile}"
			COMMAND ${CMAKE_RANLIB} ${outfile})
  endif()
  file(WRITE ${dummyfile}.base "const char* ${outlib}_sublibs=\"${libs}\";")
  add_custom_command( 
		OUTPUT  ${dummyfile}
		COMMAND ${CMAKE_COMMAND}  -E copy ${dummyfile}.base ${dummyfile}
		DEPENDS ${libs} ${extrafiles})
endfunction()
 
 
function(vcpkg_static_library_glob _arg_PROJECT_NAME)
	cmake_parse_arguments(
		"_arg"
		""
		""
		"SOURCES;HEADERS;STATIC_LIBS;PUBLIC_INCLUDES;PRIVATE_INCLUDES;INTERFACE_INCLUDES;VCPACKAGES;PACKAGES;PUBLIC_DEPENDENCIES;PRIVATE_DEPENDENCIES"
		${ARGN}
	)

	if(NOT _arg_SOURCES AND NOT _arg_HEADERS)
		if(NOT _arg_STATIC_LIBS)
			message(FATAL_ERROR "VCPKG: static_libs must be defined")
		endif()
	endif()
	
	set(${_arg_PROJECT_NAME}_BUILD_HEADERS_ONLY OFF)

	vcpkg_common_configure_project(${_arg_PROJECT_NAME} ${ARGV})
	
	merge_static_libs(
		${_arg_PROJECT_NAME}
		${_arg_STATIC_LIBS}
	)
	
	vcpkg_target_common(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
	
	add_library(${_arg_PROJECT_NAME}::${_arg_PROJECT_NAME} ALIAS ${_arg_PROJECT_NAME})
	
	vcpkg_target_install_library(${_arg_PROJECT_NAME} PUBLIC ${ARGV})
endfunction()


function(vcpkg_add_tests _arg_PROJECT_NAME)
	if(${VCPKG_DEVELOP_ENABLED})	
		cmake_parse_arguments(
			"_arg"
			""
			""
			"TEST_DIRS"
			${ARGN}
		)

		if(_arg_TEST_DIRS)
			enable_testing()
			foreach(test_dir _arg_TEST_DIRS)
				add_subdirectory(${test_dir})
			endforeach()
		endif()
	endif()
endfunction()


if(${VCPKG_DEVELOP_ENABLED})
	if(NOT VCPKG_DEVELOP_ROOT_DIR)
		message(FATAL_ERROR "VCPKG: VCPKG_DEVELOP_ROOT_DIR must be defined")
	endif()
endif()


if(VCPKG_DEVELOP_DIR)
	vcpkg_setup(DIR ${VCPKG_DEVELOP_DIR})
else()
	if(NOT VCPKG_DEVELOP_REPO)
		set(VCPKG_DEVELOP_REPO https://github.com/microsoft/vcpkg.git)
	endif()
	if(NOT VCPKG_DEVELOP_TAG)
		set(VCPKG_DEVELOP_TAG 22c8e3a23afc6be45020cd3f8c92bcea783ce8fa)
	endif()
	if(NOT VCPKG_DEVELOP_DIR)
		set(VCPKG_DEVELOP_DIR ${VCPKG_DEVELOP_ROOT_DIR}/vcpkg)
	endif()
	
	vcpkg_setup(
		REPO ${VCPKG_DEVELOP_REPO}
		TAG ${VCPKG_DEVELOP_TAG}
		DIR ${VCPKG_DEVELOP_DIR}
	)	
endif()


if(VCPKG_PORTS_DEVELOP_DIR)
	vcpkg_setup_ports(DIR ${VCPKG_PORTS_DEVELOP_DIR})
else()
	if(NOT VCPKG_PORTS_DEVELOP_REPO)
		set(VCPKG_PORTS_DEVELOP_REPO https://github.com/loopunit/vcpkg_ez.git)
	endif()
	if(NOT VCPKG_PORTS_DEVELOP_TAG)
		set(VCPKG_PORTS_DEVELOP_TAG HEAD)
	endif()
	if(NOT VCPKG_PORTS_DEVELOP_DIR)
		set(VCPKG_PORTS_DEVELOP_DIR ${VCPKG_DEVELOP_ROOT_DIR}/vcpkg_ports)
	endif()

	vcpkg_setup_ports(
		REPO ${VCPKG_PORTS_DEVELOP_REPO}
		TAG ${VCPKG_PORTS_DEVELOP_TAG}
		DIR ${VCPKG_PORTS_DEVELOP_DIR}
	)
endif()


vcpkg_standard_setup(${VCPKG_DEVELOP_ROOT_DIR}
	VCPKG_EZ_DIR 
		${vcpkg_ez_SOURCE_DIR}
	VCPKG_DIR 
		${vcpkg_SOURCE_DIR}
	VCPKG_PORTS_DIR 
		${vcpkg_ports_SOURCE_DIR}
	TARGET_TRIPLET
		${VCPKG_DEVELOP_TRIPLET}
)

if(${VCPKG_DEVELOP_ENABLED})
	include(${VCPKG_DEVELOP_ROOT_DIR}/scripts/buildsystems/vcpkg.cmake)
endif()
