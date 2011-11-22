
/******************************************************************************
* MODULE     : rel_hashmap.hpp
* DESCRIPTION: see rel_hashmap.cpp
* COPYRIGHT  : (C) 1999  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#ifndef REL_HASMAP_H
#define REL_HASMAP_H
#include "hashmap.hpp"

template<class T, class U> class rel_hashmap;
template<class T, class U> class rel_hashmap_rep;

template<class T, class U> 
class rel_hashmap : public tm_null_ptr<rel_hashmap_rep<T,U> > {
public:
  inline rel_hashmap () {}
  inline rel_hashmap (U init);
  inline rel_hashmap (hashmap<T,U> item);
  inline rel_hashmap (hashmap<T,U> item, rel_hashmap<T,U> next);
  U  operator [] (T x);
  U& operator () (T x);
};

template<class T, class U> 
class rel_hashmap_rep : public tm_obj<rel_hashmap_rep<T,U> > {
public:
  hashmap<T,U>     item;
  rel_hashmap<T,U> next;

  inline rel_hashmap_rep<T,U> (hashmap<T,U> item2, rel_hashmap<T,U> next2):
    item(item2), next(next2) {}
  bool contains (T x);
  void extend ();
  void shorten ();
  void merge ();
  void find_changes (hashmap<T,U>& CH);
  void find_differences (hashmap<T,U>& CH);
  void change (hashmap<T,U> CH);

  friend class rel_hashmap<T,U>;
};

#define TMPL template<class T, class U>
TMPL inline rel_hashmap<T,U>::rel_hashmap (U init):
  tm_null_ptr<rel_hashmap_rep<T,U> > (tm_new<rel_hashmap_rep<T,U> > (hashmap<T,U> (init), rel_hashmap<T,U> ())) {}
TMPL inline rel_hashmap<T,U>::rel_hashmap (hashmap<T,U> item):
  tm_null_ptr<rel_hashmap_rep<T,U> > (tm_new<rel_hashmap_rep<T,U> > (item, rel_hashmap<T,U> ())) {}
TMPL inline rel_hashmap<T,U>::rel_hashmap
  (hashmap<T,U> item, rel_hashmap<T,U> next):
    tm_null_ptr<rel_hashmap_rep<T,U> > (tm_new<rel_hashmap_rep<T,U> > (item, next)) {}

TMPL tm_ostream& operator << (tm_ostream& out, rel_hashmap<T,U> H);
#undef TMPL

#include "rel_hashmap.cpp"

#endif // defined REL_HASMAP_H
