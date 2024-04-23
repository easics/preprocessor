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
#include "PPDeferredCall.h"
#include <stdexcept>
#include <iostream>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <cstring>
#include <cstdio>
#include <limits.h>

extern int PreProcessdebug;
extern unsigned int PreProcessline;
extern unsigned int PreProcesscolumn;

int PreProcessparse(PreProcessParseContext * context);
PreProcessParseContext::DefineMap PreProcessParseContext::defines_;
bool PreProcessParseContext::addLineInfo = true;
std::ostream * PreProcessParseContext::result = 0;
PreProcessParseContext::IfNesting PreProcessParseContext::ifNesting_;
PreProcessParseContext::IncludeInfoArray PreProcessParseContext::includeStack_;
std::string PreProcessParseContext::currentFilename_;

static void expanduser(std::string & path);
static void expandvars(std::string & path);

void PreProcessParseContext::parseFile(const std::string & filename,
                                       bool top)
{
  // Keep current path
  char path[PATH_MAX];
  std::string pathBeforeCurrentParse = getcwd(path, PATH_MAX);

  // Change path to path of file to parse
  std::string::size_type slashPosition = filename.rfind('/');
  std::string directory;
  std::string filenameWithoutPath;
  if (slashPosition == std::string::npos)
    {
      directory = ".";
      filenameWithoutPath = filename;
    }
  else
    {
      directory = filename.substr(0, slashPosition);
      filenameWithoutPath = filename.substr(slashPosition + 1);
    }
  chdir(directory.c_str());

  PreProcessdebug = 0;
  filename_ = filename;
  FILE * f = fopen(filenameWithoutPath.c_str(), "r");
  auto defer1 = defer([&](){
        // Change path back to path before this parse
        chdir(pathBeforeCurrentParse.c_str());
              });
  if (!f)
    {
      throw std::runtime_error(makeErrorLocation() +
                               "Unable to open " + filename);
    }

  initScanner();
  auto defer2 = defer([&](){
                      fclose(f);
                      destroyScanner();
                      });
  includedFiles_.clear();
  setFile(f);
  std::string oldCurrentName = currentFilename_;
  currentFilename_ = filename;
  if (addLineInfo)
    {
      *result << "# 1 \"" << filename << "\"";
      if (!top)
        *result << " 1";
      *result << "\n";
    }
  if (!PreProcessparse(this))
    {
      if (top && !ifNesting_.empty())
        {
          throw std::runtime_error(makeErrorLocation() +
                                   "missing #endif");
        }
    }
  currentFilename_ = oldCurrentName;

  chdir(pathBeforeCurrentParse.c_str());
}

void PreProcessParseContext::addDefine(const std::string & name)
{
  auto equalPos = name.find('=');
  if (equalPos == std::string::npos)
    {
      defines_[name] = "";
    }
  else
    {
      auto defineName = name.substr(0, equalPos);
      defines_[defineName] = name.substr(equalPos+1);
    }
}

bool PreProcessParseContext::isDefined(const std::string & name)
{
  return defines_.find(name) != defines_.end();
}

void PreProcessParseContext::removeDefine(const std::string & name)
{
  defines_.erase(name);
}

void PreProcessParseContext::includeFile(const std::string & filename,
                                         unsigned int line)
{
  PreProcessParseContext context;
  IncludeInfo ii;
  ii.filename = filename_;
  ii.line = line;
  includeStack_.push_back(ii);
  std::string expandedFile = filename;
  expanduser(expandedFile);
  expandvars(expandedFile);
  context.parseFile(expandedFile, false);
  if (addLineInfo)
    {
      *result << "# " << line+1 << " \"" << filename_ << "\" 2\n";
    }
  includedFiles_.push_back(filename);
  auto subIncludedFiles = context.getIncludedFiles();
  includedFiles_.insert(includedFiles_.end(), subIncludedFiles.begin(),
                        subIncludedFiles.end());
  includeStack_.pop_back();
}

std::vector<std::string> PreProcessParseContext::getIncludedFiles() const
{
  return includedFiles_;
}

bool PreProcessParseContext::skip() // static
{
  for (IfNesting::const_iterator i=ifNesting_.begin(); i!=ifNesting_.end(); ++i)
    if (i->skip)
      return true;
  return false;
}

void PreProcessParseContext::addIf(bool conditionMatch) // static
{
  IfStatement ifstat;
  ifstat.hadTrueBranch = conditionMatch;
  ifstat.skip = !conditionMatch;
  ifstat.hadElse = false;
  ifNesting_.push_back(ifstat);
}

void PreProcessParseContext::addElif(bool conditionMatch) // static
{
  if (ifNesting_.empty())
    throw std::runtime_error(makeErrorLocation() + "elif without matching if");
  if (ifNesting_.back().hadElse)
    throw std::runtime_error(makeErrorLocation() +
                             "elif branch after a previous else ?");
  ifNesting_.back().skip = ifNesting_.back().hadTrueBranch || !conditionMatch;
  ifNesting_.back().hadTrueBranch = conditionMatch;
}

void PreProcessParseContext::addElse() // static
{
  if (ifNesting_.empty())
    throw std::runtime_error(makeErrorLocation() + "else without matching if");
  if (ifNesting_.back().hadElse)
    throw std::runtime_error(makeErrorLocation() +
                             "else branch after a previous else ?");
  ifNesting_.back().hadElse = true;
  ifNesting_.back().skip = ifNesting_.back().hadTrueBranch;
  ifNesting_.back().hadTrueBranch = true;
}

void PreProcessParseContext::endif() // static
{
  if (ifNesting_.empty())
    throw std::runtime_error(makeErrorLocation() + "endif without matching if");
  ifNesting_.pop_back();
}

std::string PreProcessParseContext::replaceDefines(const std::string & line) // static
{
  char alpha_numeric[] = "0123456789abcdefghijklmnopqrstuvwxyz"
                         "ABCDEFGHIJKLMNOPQRSTUVWXYZ_";
  auto isKeyword = [&](char c){ return strchr(alpha_numeric, c) != 0; };
  std::string replacedLine = line;
  for (auto define : defines_)
    {
      auto pos = replacedLine.find(define.first);
      auto defineSize = define.first.size();
      while (pos != std::string::npos)
        {
          bool beginOfWord = pos == 0 || !isKeyword(replacedLine[pos-1]);
          bool endOfWord = (pos + defineSize) == replacedLine.size() ||
            !isKeyword(replacedLine[pos + defineSize]);
          if (beginOfWord && endOfWord)
            {
              replacedLine = replacedLine.substr(0, pos) + define.second +
                             replacedLine.substr(pos + defineSize);
            }
          else
            ++pos;

          pos = replacedLine.find(define.first, pos);
        }
    }
  return replacedLine;
}

std::string PreProcessParseContext::getCurrentFilename() // static
{
  return currentFilename_;
}

static std::string itoa(unsigned int value)
{
  char result[64];
  sprintf(result, "%u", value);
  return result;
}

std::string PreProcessParseContext::makeErrorLocation() // static
{
  std::string result;
  for (IncludeInfoArray::const_reverse_iterator from=includeStack_.rbegin();
       from!=includeStack_.rend(); ++from)
    {
      result += "From " + from->filename + ":" + itoa(from->line) + "\n";
    }
  return result;
}

static void expanduser(std::string & path)
{
  int i, n;
  std::string userhome;
  std::string username;
  struct passwd * pwent;

  if (path.empty())
    return;

  if (path[0] != '~')
    return;

  i = 1;
  n = path.size();

  while(i<n && path[i]!='/')
    i++;

  if (i==1)
    {
      // ~/...
      if ((pwent = getpwuid(getuid())) == 0)
        return;
    }
  else
    {
      // ~user/...
      username = path.substr(1, i-1);
      if ((pwent = getpwnam(username.c_str())) == 0)
        return;
    }
  userhome = pwent->pw_dir;
  if (userhome[userhome.size()-1]=='/')
    i++;
  path = userhome + path.substr(i);
}

static void expandvars(std::string & path)
{
  unsigned int n;
  int offset = 0;
  int dollar_pos;
  char alpha_numeric[] = "0123456789abcdefghijklmnopqrstuvwxyz"
                         "ABCDEFGHIJKLMNOPQRSTUVWXYZ_";
  std::string env_var_name;
  int braced;

  while ((dollar_pos=path.find('$', offset)) != std::string::npos)
    {
      offset = dollar_pos + 1;
      braced = 0;
      if (path[dollar_pos+1] == '{' || path[dollar_pos+1] == '(')
        braced = 1;
      n = strspn(path.c_str()+dollar_pos+1+braced, alpha_numeric);
      if (n==0)
        continue;
      if (braced && path[dollar_pos+n+2] != '}' && path[dollar_pos+n+2] != ')')
        continue;
      env_var_name = path.substr(dollar_pos+1+braced, n);
      char * env_var_value = getenv(env_var_name.c_str());
      if (!env_var_value)
        continue;
      path = path.substr(0, offset-1) + env_var_value +
               path.substr(dollar_pos+n+1+braced*2);
      --offset;
    }
}
