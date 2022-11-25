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

%define api.pure

%locations
%define parse.error verbose
%debug

%parse-param { PreProcessParseContext * context }
%lex-param { void * scanner }

%{
  #include <string>

  class PreProcessParseContext;
%}

%union
{
  int i;
  std::string * s;
}

%token<s> TOKEN_BLOB_LINE "line of text"
%token<s> TOKEN_IDENTIFIER "identifier"
%token<s> TOKEN_DQUOTED_STRING "quoted string"
%token TOKEN_IFDEF       "ifdef"
%token TOKEN_ELSE        "else"
%token TOKEN_ELIF        "elif"
%token TOKEN_ENDIF       "endif"
%token TOKEN_DEFINE      "define"
%token TOKEN_DEFINED     "defined"
%token TOKEN_INCLUDE     "include"
%token TOKEN_NOT         "!"
%token TOKEN_LEFT_PAREN  "("
%token TOKEN_RIGHT_PAREN ")"
%token TOKEN_OR          "||"
%token TOKEN_AND         "&&"
%token TOKEN_EOL         "end-of-line"
%token TOKEN_IF          "if"
%token TOKEN_UNDEF       "undef"
%token TOKEN_IFNDEF      "ifndef"
%token TOKEN_NUMBER      "number"
%type<i> expression TOKEN_NUMBER

%left TOKEN_AND TOKEN_OR
%left '+' '-'
%left '*' '/'
%nonassoc TOKEN_NOT

%{
  #include <iostream>
  #include <sstream>
  #include <stdexcept>
  #include "PreProcessParseContext.h"

  int PreProcesslex(YYSTYPE * lval, YYLTYPE * lloc, void * scanner);
  void PreProcesserror(YYLTYPE * locp, PreProcessParseContext * context,
                       const char * message);

  #define scanner context->scanner
%}

%%

file            : line_list
                ;

line_list       :
                | line_list line
                ;

line            : TOKEN_BLOB_LINE TOKEN_EOL
                {
                  if (!context->skip())
                    {
                      *context->result << *$1;
                    }
                  *context->result << '\n';
                  delete $1;
                }
                | TOKEN_EOL
                {
                  *context->result << '\n';
                }
                | preprocessor_statement
                ;

preprocessor_statement : ifdef_statement
                       | ifndef_statement
                       | if_statement
                       | else_statement
                       | elif_statement
                       | endif_statement
                       | define_statement
                       | undef_statement
                       | include_statement
                       | line_statement
                       ;

ifdef_statement : TOKEN_IFDEF TOKEN_IDENTIFIER TOKEN_EOL
                {
                  *context->result << '\n';
                  context->addIf(context->isDefined(*$2));
                  delete $2;
                }
                ;

ifndef_statement : TOKEN_IFNDEF TOKEN_IDENTIFIER TOKEN_EOL
                 {
                   *context->result << '\n';
                   context->addIf(!context->isDefined(*$2));
                   delete $2;
                 }
                 ;

else_statement : TOKEN_ELSE TOKEN_EOL
               {
                 *context->result << '\n';
                 context->addElse();
               }
               ;

elif_statement : TOKEN_ELIF expression TOKEN_EOL
               {
                 *context->result << '\n';
                 context->addElif($2!=0);
               }
               ;

endif_statement : TOKEN_ENDIF TOKEN_EOL
                {
                  *context->result << '\n';
                  context->endif();
                }

expression : TOKEN_LEFT_PAREN expression TOKEN_RIGHT_PAREN
           {
             $$ = $2;
           }
           | TOKEN_DEFINED TOKEN_LEFT_PAREN TOKEN_IDENTIFIER TOKEN_RIGHT_PAREN
           {
             $$ = context->isDefined(*$3)?1:0;
             delete $3;
           }
           | TOKEN_NOT expression
           {
             $$ = !$2;
           }
           | expression TOKEN_AND expression
           {
             $$ = $1 && $3;
           }
           | expression TOKEN_OR expression
           {
             $$ = $1 || $3;
           }
           | expression '+' expression { $$ = $1 + $3; }
           | expression '-' expression { $$ = $1 - $3; }
           | expression '*' expression { $$ = $1 * $3; }
           | expression '/' expression { $$ = $1 / $3; }
           | TOKEN_NUMBER              { $$ = $1; }
           ;

if_statement : TOKEN_IF expression TOKEN_EOL
             {
               *context->result << '\n';
               context->addIf($2!=0);
             }
             ;

include_statement : TOKEN_INCLUDE TOKEN_DQUOTED_STRING TOKEN_EOL
                  {
                    if (!context->skip())
                      context->includeFile(*$2, yyloc.first_line);
                    delete $2;
                  }
                  ;

define_statement : TOKEN_DEFINE TOKEN_IDENTIFIER TOKEN_EOL
                 {
                   context->addDefine(*$2);
                   *context->result << '\n';
                   delete $2;
                 }
                 ;

undef_statement : TOKEN_UNDEF TOKEN_IDENTIFIER TOKEN_EOL
                {
                  context->removeDefine(*$2);
                  *context->result << '\n';
                  delete $2;
                }

line_statement : TOKEN_NUMBER TOKEN_DQUOTED_STRING
               {
                  if (!context->skip())
                    {
                      *context->result << "# " << $1 << " \"" << *$2 << '"';
                    }
                  *context->result << '\n';
                  delete $2;
               };

%%

void PreProcesserror(YYLTYPE * loc, PreProcessParseContext * context,
                     const char * message)
{
  std::ostringstream s;
  s << loc->first_line << ":" << message << "\n";
  throw std::runtime_error(s.str());
}
