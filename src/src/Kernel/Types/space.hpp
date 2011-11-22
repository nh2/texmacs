
/******************************************************************************
* MODULE     : space.hpp
* DESCRIPTION: spacing
* COPYRIGHT  : (C) 1999  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#ifndef SPACE_H
#define SPACE_H
#include "tree.hpp"

class space_rep: public tm_obj<space_rep> {
public:
  SI min;
  SI def;
  SI max;

  space_rep (SI def);
  space_rep (SI min, SI def, SI max);

  friend class space;
};

class space : public tm_ptr<space_rep> {
public:
  space (SI def=0);
  space (SI min, SI def, SI max);
  operator tree ();
  inline void operator += (space spc) {
    rep()->min += spc->min;
    rep()->def += spc->def;
    rep()->max += spc->max; }
};


bool operator == (space spc1, space spc2);
bool operator != (space spc1, space spc2);
tm_ostream& operator << (tm_ostream& out, space spc);
space copy (space spc);
space operator + (space spc1, space spc2);
space operator - (space spc1, space spc2);
space operator * (int i, space spc);
space operator / (space spc, int i);
space max (space spc1, space spc2);

#endif // defined SPACE_H
