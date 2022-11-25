/* This file is part of preprocessor. */
/*  */
/* preprocessor is free software: you can redistribute it and/or modify it under */
/* the terms of the GNU General Public License as published by the Free Software */
/* Foundation, either version 3 of the License, or (at your option) any later */
/* version. */
/*  */
/* preprocessor is distributed in the hope that it will be useful, but WITHOUT ANY */
/* WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A */
/* PARTICULAR PURPOSE. See the GNU General Public License for more details. */
/*  */
/* You should have received a copy of the GNU General Public License along with */
/* preprocessor. If not, see <https://www.gnu.org/licenses/>. */

%{
  #include "PreProcessParseContext.h"
  #include "PreProcess.tab.hpp"
  extern unsigned int PreProcessline;
  extern unsigned int PreProcesscolumn;
  #define ADD_COL PreProcesscolumn += yyleng
  #define YY_USER_ACTION yylloc->first_line = yylineno;
%}

%option noyywrap
%option reentrant
%option bison-bridge
%option bison-locations
%option yylineno
%option warn
%option debug

identifier      [a-zA-Z_][a-zA-Z0-9_]*
dquoted_str     \"[^"\n]*["\n]
space           [ \t]
number          [0-9]+

%x PP

%%

^{space}*[#]      { ADD_COL; BEGIN(PP); }
<PP>if            { ADD_COL; return TOKEN_IF; }
<PP>ifdef         { ADD_COL; return TOKEN_IFDEF; }
<PP>ifndef        { ADD_COL; return TOKEN_IFNDEF; }
<PP>else          { ADD_COL; return TOKEN_ELSE; }
<PP>elif          { ADD_COL; return TOKEN_ELIF; }
<PP>endif         { ADD_COL; return TOKEN_ENDIF; }
<PP>define        { ADD_COL; return TOKEN_DEFINE; }
<PP>defined       { ADD_COL; return TOKEN_DEFINED; }
<PP>include       { ADD_COL; return TOKEN_INCLUDE; }
<PP>undef         { ADD_COL; return TOKEN_UNDEF; }
<PP>!             { ADD_COL; return TOKEN_NOT; }
<PP>\(            { ADD_COL; return TOKEN_LEFT_PAREN; }
<PP>\)            { ADD_COL; return TOKEN_RIGHT_PAREN; }
<PP>\|\|          { ADD_COL; return TOKEN_OR; }
<PP>\&\&          { ADD_COL; return TOKEN_AND; }
<PP>{identifier}  { ADD_COL;
                    yylval->s = new std::string(yytext);
                    return TOKEN_IDENTIFIER; }
<PP>{dquoted_str} { yytext[yyleng-1] = 0;
                    yylval->s = new std::string(yytext+1);
                    return TOKEN_DQUOTED_STRING; }
<PP>{number}      { yylval->i = atoi(yytext); return TOKEN_NUMBER; }
<PP>[\n]          { ++PreProcessline; PreProcesscolumn = 1;
                    BEGIN(INITIAL); return TOKEN_EOL; }
<PP>[ ]           { ADD_COL; }
<PP>[\t]          { PreProcesscolumn += 8; }
<PP>[\r]          /* empty */;
<PP>            /* empty */;
<PP>.             { ADD_COL; return *yytext;}
^{space}*[^#\n].* { ADD_COL;
                    yylval->s = new std::string(yytext);
                    return TOKEN_BLOB_LINE; }
[ ]               { ADD_COL; }
[\t]              { PreProcesscolumn += 8; }
[\n]              { ++PreProcessline; PreProcesscolumn = 1; return TOKEN_EOL; }
[\r]              /* empty */;
                /* empty */;
.                 { ADD_COL; return *yytext;}

%%

unsigned int PreProcessline;
unsigned int PreProcesscolumn;

void PreProcessParseContext::initScanner()
{
  yylex_init(&scanner);
  PreProcessset_debug(0, scanner);
}

void PreProcessParseContext::destroyScanner()
{
  yylex_destroy(scanner);
}

void PreProcessParseContext::setFile(FILE * f)
{
  yyset_in(f, scanner);
}
