cmake_minimum_required(VERSION 3.8)
project(interface_install_consumer)

find_package(ament_cmake REQUIRED)
find_package(openamr_nav_msgs REQUIRED)
find_package(openamr_ui_msgs REQUIRED)
find_package(rosidl_typesupport_cpp REQUIRED)

add_executable(verify_installed_interfaces src/consumer.cpp)
target_compile_features(verify_installed_interfaces PRIVATE cxx_std_17)
ament_target_dependencies(verify_installed_interfaces
  openamr_nav_msgs openamr_ui_msgs rosidl_typesupport_cpp)
install(TARGETS verify_installed_interfaces DESTINATION lib/${PROJECT_NAME})
ament_package()
