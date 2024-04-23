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
  #include "PreProcess.tab.h"
  extern unsigned int PreProcessline;
  extern unsigned int PreProcesscolumn;
  static std::string partialLine;
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
%x PPEXPR
%x PPSTR
%x NONPP

%%

^{space}*[#]      { ADD_COL; BEGIN(PP); partialLine = yytext; }
<PP>if            { ADD_COL; BEGIN(PPEXPR); return TOKEN_IF; }
<PP>ifdef         { ADD_COL; BEGIN(PPEXPR); return TOKEN_IFDEF; }
<PP>ifndef        { ADD_COL; BEGIN(PPEXPR); return TOKEN_IFNDEF; }
<PP>else          { ADD_COL; return TOKEN_ELSE; }
<PP>elif          { ADD_COL; BEGIN(PPEXPR); return TOKEN_ELIF; }
<PP>endif         { ADD_COL; return TOKEN_ENDIF; }
<PP>define        { ADD_COL; BEGIN(PPEXPR); return TOKEN_DEFINE; }
<PP>defined       { ADD_COL; return TOKEN_DEFINED; }
<PP>include       { ADD_COL; BEGIN(PPSTR); return TOKEN_INCLUDE; }
<PP>undef         { ADD_COL; return TOKEN_UNDEF; }
<PP>[ ]           { ADD_COL; }
<PP>[\t]          { PreProcesscolumn += 8; }
<PP>.             { ADD_COL; BEGIN(NONPP); partialLine += yytext; }
<PP>\n            { ++PreProcessline; PreProcesscolumn = 1;
                    BEGIN(INITIAL); return TOKEN_EOL; }
<PPEXPR>!         { ADD_COL; return TOKEN_NOT; }
<PPEXPR>\(        { ADD_COL; return TOKEN_LEFT_PAREN; }
<PPEXPR>\)        { ADD_COL; return TOKEN_RIGHT_PAREN; }
<PPEXPR>\|\|      { ADD_COL; return TOKEN_OR; }
<PPEXPR>\&\&      { ADD_COL; return TOKEN_AND; }
<PPEXPR>{identifier}  { ADD_COL;
                    yylval->s = new std::string(yytext);
                    return TOKEN_IDENTIFIER; }
<PPSTR>{dquoted_str} { yytext[yyleng-1] = 0;
                    yylval->s = new std::string(yytext+1);
                    BEGIN(INITIAL);
                    return TOKEN_DQUOTED_STRING; }
<PPSTR>{space}*   { ADD_COL; }
<PPSTR>.          { ADD_COL; return *yytext; }
<PPEXPR>{number}  { yylval->i = atoi(yytext); return TOKEN_NUMBER; }
<PPEXPR>[ ]       { ADD_COL; }
<PPEXPR>[\t]      { PreProcesscolumn += 8; }
<PPEXPR>[\r]      /* empty */;
<PPEXPR>        /* empty */;
<PPEXPR>.         { ADD_COL; BEGIN(INITIAL); partialLine = yytext; }
<PPEXPR>\n        { ++PreProcessline; PreProcesscolumn = 1;
                    BEGIN(INITIAL); return TOKEN_EOL; }
^{space}*[^#\n]*  { ADD_COL; BEGIN(NONPP); partialLine = yytext; }
<NONPP>.*         { ADD_COL;
                    yylval->s = new std::string(partialLine + yytext);
                    partialLine.clear();
                    return TOKEN_BLOB_LINE; }
<NONPP>\n         { ++PreProcessline; PreProcesscolumn = 1; BEGIN(INITIAL);
                    if (!partialLine.empty())
                      {
                        yylval->s = new std::string(partialLine);
                        partialLine.clear();
                        return TOKEN_BLOB_LINE;
                      }
                  }
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
