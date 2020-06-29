# Example portfile skeleton, copy to ports tree & modify accordingly

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

set(REPO_PATH https://???/???.git)
set(REPO_TAG ???)

include($ENV{VCPKG_PORT_LOOKUP_SCRIPT} OPTIONAL RESULT_VARIABLE USE_DEVELOPMENT_PORT)

if(USE_DEVELOPMENT_PORT)
	vcpkg_developer_port_redirect(${PORT})
	if(${PORT}_SOURCE_PATH)
		set(SOURCE_PATH ${${PORT}_SOURCE_PATH})
	endif()
endif()

if(NOT SOURCE_PATH)
	set(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/src/${PORT})
	
	if(USE_DEVELOPMENT_PORT)
		vcpkg_developer_repo_redirect(${PORT})
		
		if(${PORT}_REPO_PATH)
			set(REPO_PATH ${${PORT}_REPO_PATH})
		endif()
		
		if(${PORT}_REPO_TAG)
			set(REPO_TAG ${${PORT}_REPO_TAG})
		endif()
	endif()

	# Pull from git
	if(NOT EXISTS "${SOURCE_PATH}/.git")
		message(STATUS "Cloning and fetching submodules into ${SOURCE_PATH}")
		
		vcpkg_execute_required_process(
			COMMAND ${GIT} clone --depth 1 ${REPO_PATH} ${SOURCE_PATH}
			WORKING_DIRECTORY ${SOURCE_PATH}
			LOGNAME clone
		)
	
		vcpkg_execute_required_process(
			COMMAND ${GIT} config core.longpaths true
			WORKING_DIRECTORY ${SOURCE_PATH}
			LOGNAME config
		)
	
		vcpkg_execute_required_process(
			COMMAND ${GIT} submodule update --init --recursive
			WORKING_DIRECTORY ${SOURCE_PATH}
			LOGNAME submodule_update
		)
	endif()
	
	vcpkg_execute_required_process(
		COMMAND ${GIT} checkout --recurse-submodules ${REPO_TAG}
		WORKING_DIRECTORY ${SOURCE_PATH}
		LOGNAME checkout
	)
endif()

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
	OPTIONS
		-DVCPKG_DEVELOP_IS_PORT=ON
		-DVCPKG_DEVELOP_ROOT_DIR=$ENV{VCPKG_ROOT_DIR}
		-DVCPKG_DEVELOP_EZ_DIR=$ENV{VCPKG_EZ_DIR}
		-DVCPKG_DEVELOP_DIR=$ENV{VCPKG_DIR}
		-DVCPKG_PORTS_DEVELOP_DIR=$ENV{VCPKG_PORTS_DIR}
		-DVCPKG_DEVELOP_TRIPLET=$ENV{VCPKG_TRIPLET}
)

vcpkg_install_cmake()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/cmake/${PORT}")
    vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/${PORT})
elseif(EXISTS "${CURRENT_PACKAGES_DIR}/lib/${PORT}/cmake")
    vcpkg_fixup_cmake_targets(CONFIG_PATH lib/${PORT}/cmake)
endif()

vcpkg_copy_pdbs()

file(INSTALL ${SOURCE_PATH}/README.md DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
