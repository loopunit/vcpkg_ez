macro(vcpkg_developer_port_redirect _arg_PORT_NAME)
	#message(FATAL_ERROR "VCPKG: Ports are disabled for: ${_arg_PORT_NAME}")
	message(STATUS "VCPKG: Ports are disabled, lookup will do nothing for: ${_arg_PORT_NAME}")
endmacro()