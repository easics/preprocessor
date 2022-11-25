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

#ifndef PreProcessParseContext_h_
#define PreProcessParseContext_h_

#include <string>
#include <iostream>
#include <cstdio>
#include <map>
#include <vector>

/**
 * Preprocessor.
 *
 * Supports following features :
 * - #if, #ifdef, #ifndef
 * - #define, #undef
 * - #inclute "file" (with the t replaced with a d, otherwise cma gets confused)
 *
 * The #if condition can be :
 * - a numerical expression
 * - defined() function
 * - &&, ||, !
 *
 * To use, create an instance of this class, set the result member to what you
 * like (ofstream or ostringstream) and call parseFile. \n
 * You can add predefined macros with addDefine.
 */
class PreProcessParseContext
{
public:
  // Indicates if an if-statement has had a true condition
  struct IfStatement
    {
      bool skip;
      bool hadTrueBranch;
      bool hadElse;
    };
  typedef std::vector<IfStatement> IfNesting;

  PreProcessParseContext() : scanner(0) {}
  void parseFile(const std::string & filename, bool top=true);
  void addDefine(const std::string & name);
  bool isDefined(const std::string & name);
  void removeDefine(const std::string & name);
  void includeFile(const std::string & filename, unsigned int line);
  std::vector<std::string> getIncludedFiles() const;

  void * scanner;
  static std::ostream * result;
  static bool skip();
  static void addIf(bool conditionMatch);
  static void addElif(bool conditionMatch);
  static void addElse();
  static void endif();

  // configuration
  static bool addLineInfo;
protected:
  struct IncludeInfo
    {
      std::string filename;
      unsigned int line;
      std::string path;
    };
  typedef std::vector<IncludeInfo> IncludeInfoArray;

  // 3 functions defined in PreProcess.l
  void initScanner();
  void destroyScanner();
  void setFile(FILE * f);
  static std::string makeErrorLocation();

  typedef std::map<std::string, std::string> DefineMap;
  static DefineMap defines_;
  static IfNesting ifNesting_;
  static IncludeInfoArray includeStack_;
  std::string filename_;
  static std::string currentFilename_;

  std::vector<std::string> includedFiles_;
};

#endif
