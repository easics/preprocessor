# This file is part of preprocessor.
#
# preprocessor is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# preprocessor is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# preprocessor. If not, see <https://www.gnu.org/licenses/>.

## Target libraries
add_library(PreProcess STATIC)

target_include_directories(PreProcess
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

## Package dependencies
find_package(BISON)
find_package(FLEX)

BISON_TARGET(PreProcessParser
             ${CMAKE_CURRENT_SOURCE_DIR}/PreProcess.y
             ${CMAKE_CURRENT_BINARY_DIR}/PreProcess.tab.cpp
             COMPILE_FLAGS "-HPreProcess.tab.h -p PreProcess")
FLEX_TARGET(PreProcessScanner
            ${CMAKE_CURRENT_SOURCE_DIR}/PreProcess.l
            ${CMAKE_CURRENT_BINARY_DIR}/PreProcess.lex.cpp
            COMPILE_FLAGS "-P PreProcess")
ADD_FLEX_BISON_DEPENDENCY(PreProcessScanner PreProcessParser)

## File list
target_sources(PreProcess
  PRIVATE
    PreProcessParseContext.C
    ${BISON_PreProcessParser_OUTPUTS}
    ${FLEX_PreProcessScanner_OUTPUTS}
)
