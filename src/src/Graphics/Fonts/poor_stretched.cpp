
/******************************************************************************
* MODULE     : poor_stretched.cpp
* DESCRIPTION: Emulation of stretched fonts
* COPYRIGHT  : (C) 2016  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#include "font.hpp"
#include "analyze.hpp"
#include "frame.hpp"

/******************************************************************************
* True Type fonts
******************************************************************************/

struct poor_stretched_font_rep: font_rep {
  font   base;
  double factor;

  poor_stretched_font_rep (string name, font base, double factor);

  bool   supports (string c);
  void   get_extents (string s, metric& ex);
  void   get_xpositions (string s, SI* xpos);
  void   get_xpositions (string s, SI* xpos, bool lig);
  void   get_xpositions (string s, SI* xpos, SI xk);
  void   draw_fixed (renderer ren, string s, SI x, SI y, SI* xpos);
  void   draw_fixed (renderer ren, string s, SI x, SI y);
  void   draw_fixed (renderer ren, string s, SI x, SI y, bool lig);
  void   draw_fixed (renderer ren, string s, SI x, SI y, SI xk);
  font   magnify (double zoomx, double zoomy);
  void   advance_glyph (string s, int& pos);
  glyph  get_glyph (string s);
  int    index_glyph (string s, font_metric& fnm, font_glyphs& fng);
  double get_left_slope  (string s);
  double get_right_slope (string s);
  SI     get_left_correction  (string s);
  SI     get_right_correction  (string s);
};

/******************************************************************************
* Initialization of main font parameters
******************************************************************************/

poor_stretched_font_rep::poor_stretched_font_rep (
  string name, font b, double f):
    font_rep (name, b), base (b), factor (f)
{
  this->copy_math_pars (base);
  this->slope /= factor;
}

/******************************************************************************
* Getting extents and drawing strings
******************************************************************************/

bool
poor_stretched_font_rep::supports (string s) {
  return base->supports (s);
}

void
poor_stretched_font_rep::get_extents (string s, metric& ex) {
  base->get_extents (s, ex);
  ex->y1= (SI) floor (factor * ex->y1 + 0.5);
  ex->y2= (SI) floor (factor * ex->y2 + 0.5);
  ex->y3= (SI) floor (factor * ex->y3);
  ex->y4= (SI) ceil  (factor * ex->y4);
}

void
poor_stretched_font_rep::get_xpositions (string s, SI* xpos) {
  base->get_xpositions (s, xpos);
}

void
poor_stretched_font_rep::get_xpositions (string s, SI* xpos, bool lig) {
  base->get_xpositions (s, xpos, lig);
}

void
poor_stretched_font_rep::get_xpositions (string s, SI* xpos, SI xk) {
  base->get_xpositions (s, xpos, xk);
}

void
poor_stretched_font_rep::draw_fixed (renderer ren, string s,
                                     SI x, SI y, SI* xpos) {
  int i=0;
  while (i < N(s)) {
    int start= i;
    base->advance_glyph (s, i);
    string ss= s (start, i);
    font_metric fnm;
    font_glyphs fng;
    int c= index_glyph (ss, fnm, fng);
    //cout << "Drawing " << ss << ", " << c
    //     << " at " << (xpos[start]/PIXEL) << "\n";
    //cout << fng->get (c) << "\n\n";
    if (c >= 0) ren->draw (c, fng, start==0? x: x + xpos[start], y);
  }
}

void
poor_stretched_font_rep::draw_fixed (renderer ren, string s, SI x, SI y) {
  if (ren->is_screen) {
    STACK_NEW_ARRAY (xpos, SI, N(s)+1);
    get_xpositions (s, xpos);
    draw_fixed (ren, s, x, y, xpos);
    STACK_DELETE_ARRAY (xpos);
  }
  else {
    ren->set_transformation (scaling (point (1.0, factor), point (0.0, 0.0)));
    base->draw_fixed (ren, s, x, y);
    ren->reset_transformation ();
  }
}

void
poor_stretched_font_rep::draw_fixed (renderer ren, string s, SI x, SI y, bool l) {
  if (ren->is_screen) {
    STACK_NEW_ARRAY (xpos, SI, N(s)+1);
    get_xpositions (s, xpos, l);
    draw_fixed (ren, s, x, y, xpos);
    STACK_DELETE_ARRAY (xpos);
  }
  else {
    ren->set_transformation (scaling (point (1.0, factor), point (0.0, 0.0)));
    base->draw_fixed (ren, s, x, y, l);
    ren->reset_transformation ();
  }
}

void
poor_stretched_font_rep::draw_fixed (renderer ren, string s, SI x, SI y, SI xk) {
  if (ren->is_screen) {
    STACK_NEW_ARRAY (xpos, SI, N(s)+1);
    get_xpositions (s, xpos, xk);
    draw_fixed (ren, s, x, y, xpos);
    STACK_DELETE_ARRAY (xpos);
  }
  else {
    ren->set_transformation (scaling (point (1.0, factor), point (0.0, 0.0)));
    base->draw_fixed (ren, s, x, y, xk);
    ren->reset_transformation ();
  }
}

font
poor_stretched_font_rep::magnify (double zoomx, double zoomy) {
  return poor_stretched_font (base, zoomx, zoomy * factor);
}

/******************************************************************************
* Glyph manipulations
******************************************************************************/

void
poor_stretched_font_rep::advance_glyph (string s, int& pos) {
  base->advance_glyph (s, pos);
}

glyph
poor_stretched_font_rep::get_glyph (string s) {
  glyph gl= base->get_glyph (s);
  return stretched (gl, 1.0, factor);
}

int
poor_stretched_font_rep::index_glyph (string s, font_metric& fnm,
                                                font_glyphs& fng) {
  int c= base->index_glyph (s, fnm, fng);
  if (c < 0) return c;
  fnm= stretched (fnm, 1.0, factor);
  fng= stretched (fng, 1.0, factor);
  return c;
}

/******************************************************************************
* Stretched correction
******************************************************************************/

double
poor_stretched_font_rep::get_left_slope (string s) {
  return base->get_left_slope (s) / factor;
}

double
poor_stretched_font_rep::get_right_slope (string s) {
  return base->get_right_slope (s) / factor;
}

SI
poor_stretched_font_rep::get_left_correction (string s) {
  return base->get_left_correction (s);
}

SI
poor_stretched_font_rep::get_right_correction (string s) {
  return base->get_right_correction (s);
}

/******************************************************************************
* Interface
******************************************************************************/

font
poor_stretched_font (font base, double zoomx, double zoomy) {
  if (zoomx != zoomx) zoomx= 1.0;
  if (zoomy != zoomy) zoomy= 1.0;
  if (zoomx < 0.01) zoomx= 0.01;
  if (zoomy < 0.01) zoomy= 0.01;
  if (zoomx > 100.0) zoomx= 100.0;
  if (zoomy > 100.0) zoomy= 100.0;
  if (zoomx != 1.0)
    return poor_stretched_font (base->magnify (zoomx), 1.0, zoomy / zoomx);
  if (zoomy == 1.0)
    return base;
  string name=
    "poorstretched[" * base->res_name * "," * as_string (zoomy) * "]";
  return make (font, name, tm_new<poor_stretched_font_rep> (name, base, zoomy));
}
