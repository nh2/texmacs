
/******************************************************************************
* MODULE     : new_view.hpp
* DESCRIPTION: View management
* COPYRIGHT  : (C) 1999-2012  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#ifndef NEW_VIEW_H
#define NEW_VIEW_H
#include "tree.hpp"
#include "url.hpp"
#include "new_buffer.hpp"

class editor;

class tm_view_rep;
typedef tm_view_rep* tm_view;

class tm_server_views_rep: virtual public tm_server_buffers_rep {
  
  tm_view the_view; // current view

  array<url> view_history;

protected:

  tm_server_views_rep () : the_view (NULL) {};
  ~tm_server_views_rep () {};

  // Low level types and routines
  tm_view concrete_view (url name);
  url     abstract_view (tm_view vw);
  void    detach_view (url u);
  url     get_recent_view (url name, bool s, bool o, bool a, bool p);
  

public:

  array<url> get_all_views ();
  array<url> buffer_to_views (url name);
  editor get_current_editor ();
  editor view_to_editor (url u);
  bool has_current_view ();
  void set_current_view (url u);
  url  get_current_view ();
  url  get_current_view_safe ();
  url  window_to_view (url win);
  url  view_to_buffer (url u);
  url  view_to_window (url u);
  url  get_new_view (url name);
  url  get_recent_view (url name);
  url  get_passive_view (url name);
  void delete_view (url u);
  void notify_rename_before (url old_name);
  void notify_rename_after (url new_name);
  void window_set_view (url win, url new_u, bool focus);
  void switch_to_buffer (url name);
  void focus_on_editor (editor ed);
  bool focus_on_buffer (url name);
  
private:
  
  void notify_set_view (url u);
  void notify_delete_view (url u);
  void attach_view (url win_u, url u);
  
  
};
#endif // defined NEW_VIEW_H
