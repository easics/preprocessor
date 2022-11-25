// This file is part of preprocessor.
//
// preprocessor is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// preprocessor is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// preprocessor. If not, see <https://www.gnu.org/licenses/>.


#include "PreProcessParseContext.h"
#include <iostream>

int main(int argc, char * argv[])
{
  PreProcessParseContext context;
  context.result = &std::cout;
  context.parseFile("test.txt");
  return 0;
}
