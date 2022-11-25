<!--- This file is part of preprocessor. -->
<!---  -->
<!--- preprocessor is free software: you can redistribute it and/or modify it under -->
<!--- the terms of the GNU General Public License as published by the Free Software -->
<!--- Foundation, either version 3 of the License, or (at your option) any later -->
<!--- version. -->
<!---  -->
<!--- preprocessor is distributed in the hope that it will be useful, but WITHOUT ANY -->
<!--- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A -->
<!--- PARTICULAR PURPOSE. See the GNU General Public License for more details. -->
<!---  -->
<!--- You should have received a copy of the GNU General Public License along with -->
<!--- preprocessor. If not, see <https://www.gnu.org/licenses/>. -->

# Preprocessor

A simple preprocessor

## Compilation

Compilation is done with [CMAKE](https://cmake.org/)

Generate the project build system:

```bash
cmake -B build -S ./
```

By default the build system will use Makefiles.
To use Ninja files you can run the following command:

```bash
cmake -B build -S ./ -G Ninja
```

Build the project:

```bash
cmake --build build
```

To specify the maximum number of concurrent processes when building, you can use
the following option:

```bash
cmake --build build -j 4
```
