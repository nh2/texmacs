
/******************************************************************************
* MODULE     : tm_server_windows.cpp
* DESCRIPTION: Global window management
* COPYRIGHT  : (C) 1999-2012  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#include "tm_server_windows.hpp"
#include "tm_buffer.hpp"
#include "tm_window.hpp"
#include "convert.hpp"
#include "file.hpp"
#include "web_files.hpp"
#include "tm_link.hpp"
#include "message.hpp"
#include "dictionary.hpp"
#include "new_document.hpp"

/******************************************************************************
* Manage global list of windows
******************************************************************************/

extern int nr_windows;

/*
static path
reset (path p, int i) {
  if (is_nil (p)) return p;
  else if (p->item == i) return p->next;
  else return path (p->item, reset (p->next, i));
}
*/

url
tm_server_windows_rep::create_window_id () {
  url r= "tmfs://window/" * as_string (last_window);
  all_windows << r;
  last_window++;
  return r;
}

void
tm_server_windows_rep::destroy_window_id (url win) {
  for (int i=0; i<N(all_windows); i++)
    if (all_windows[i] == win) {
      all_windows= append (range (all_windows, 0, i),
                           range (all_windows, i+1, N(all_windows)));
      return;
    }
}

url
tm_server_windows_rep::abstract_window (tm_window win) {
  if (win == NULL) return url_none ();
  return win->id;
}

/******************************************************************************
* Low level creation and destruction of windows
******************************************************************************/


class kill_window_command_rep: public command_rep {
  url* id;
public:
  inline kill_window_command_rep (url* id2): id (id2) {}
  inline ~kill_window_command_rep () { tm_delete (id); }
  inline void apply () {
    object cmd= list_object (symbol_object ("safely-kill-window"),
                             object (*id));
    exec_delayed (scheme_cmd (cmd)); }
  tm_ostream& print (tm_ostream& out) { return out << "kill window"; }
};

url
tm_server_windows_rep::new_window (bool map_flag, tree geom) {
  int mask= 0;
  if (get_preference ("header") == "on") mask += 1;
  if (get_preference ("main icon bar") == "on") mask += 2;
  if (get_preference ("mode dependent icons") == "on") mask += 4;
  if (get_preference ("focus dependent icons") == "on") mask += 8;
  if (get_preference ("user provided icons") == "on") mask += 16;
  if (get_preference ("status bar") == "on") mask += 32;
  if (get_preference ("side tools") == "on") mask += 64;
  if (get_preference ("bottom tools") == "on") mask += 128;
  url* id= tm_new<url> (url_none ());
  command quit= tm_new<kill_window_command_rep> (id);
  tm_window win= tm_new<tm_window_rep> (this, texmacs_widget (mask, quit), geom);
  tm_window_table (win->id)= win;
  if (map_flag) win->map ();
  *id= abstract_window (win);
  return abstract_window (win);
}

bool
tm_server_windows_rep::delete_view_from_window (url win) {
  array<url> vs= get_all_views ();
  for (int i=0; i<N(vs); i++)
    if (view_to_window (vs[i]) == win) {
      detach_view (vs[i]);
      // delete_view (vs[i]);
      // Don't delete view alltogether, because at least one view is needed
      // for making the 'buffer_modified' predicate function appropriately
      return true;
    }
  return false;
}

void
tm_server_windows_rep::delete_window (url win_u) {
  tm_window win= concrete_window (win_u);
  if (win == NULL) return;
  while (delete_view_from_window (win_u)) {}
  win->unmap ();
  tm_window_table->reset (win->id);
  destroy_window_widget (win->win);
  tm_delete (win);
}

tm_window
tm_server_windows_rep::concrete_window (url win) {
  return tm_window_table [win];
}

/******************************************************************************
* Manage global list of windows
******************************************************************************/

array<url>
tm_server_windows_rep::windows_list () {
  return all_windows;
}

int
tm_server_windows_rep::get_nr_windows () {
  return nr_windows;
}

bool
tm_server_windows_rep::has_current_window () {
  tm_view vw= concrete_view (get_current_view_safe ());
  return vw != NULL && vw->win != NULL;
}

tm_window
tm_server_windows_rep::concrete_window () {
  tm_view vw= concrete_view (get_current_view ());
  ASSERT (vw->win != NULL, "no window attached to view");
  return vw->win;
}

url
tm_server_windows_rep::get_current_window () {
  tm_window win= concrete_window ();
  return abstract_window (win);
}

array<url>
tm_server_windows_rep::buffer_to_windows (url name) {
  array<url> r, vs= buffer_to_views (name);
  for (int i=0; i<N(vs); i++) {
    url win= view_to_window (vs[i]);
    if (!is_none (win)) r << win;
  }
  return r;
}

url
tm_server_windows_rep::window_to_buffer (url win) {
  return view_to_buffer (window_to_view (win));
}

url
tm_server_views_rep::window_to_view (url win) {
  array<url> vs= get_all_views ();
  for (int i=0; i<N(vs); i++)
    if (view_to_window (vs[i]) == win)
      return vs[i];
  return url_none ();
}

void
tm_server_windows_rep::window_set_buffer (url win, url name) {
  url old= window_to_view (win);
  if (is_none (old) || view_to_buffer (old) == name) return;
  window_set_view (win, get_passive_view (name), false);
}

void
tm_server_windows_rep::window_focus (url win) {
  if (win == get_current_window ()) return;
  url old= window_to_view (win);
  if (is_none (old)) return;
  set_current_view (old);
}

/******************************************************************************
* Other subroutines
******************************************************************************/

void
tm_server_windows_rep::create_buffer (url name, tree doc) {
  if (!is_nil (concrete_buffer (name))) return;
  set_buffer_tree (name, doc);
}

void
tm_server_windows_rep::new_buffer_in_this_window (url name, tree doc) {
  if (is_nil (concrete_buffer (name)))
    create_buffer (name, doc);
  switch_to_buffer (name);
}

url
tm_server_windows_rep::new_buffer_in_new_window (url name, tree doc, tree geom) {
  if (is_nil (concrete_buffer (name)))
    create_buffer (name, doc);
  url win= new_window (true, geom);
  window_set_view (win, get_passive_view (name), true);
  return win;
}

/******************************************************************************
* Exported routines
******************************************************************************/

url
tm_server_windows_rep::create_buffer () {
  url name= make_new_buffer ();
  switch_to_buffer (name);
  return name;
}

url
tm_server_windows_rep::open_window (tree geom) {
  url name= make_new_buffer ();
  return new_buffer_in_new_window (name, tree (DOCUMENT), geom);
}

void
tm_server_windows_rep::clone_window () {
  url win= new_window ();
  window_set_view (win, get_passive_view (get_current_buffer ()), true);
}

void
tm_server_windows_rep::kill_buffer (url name) {
  array<url> vs= buffer_to_views (name);
  for (int i=0; i<N(vs); i++)
    if (!is_none (vs[i])) {
      url prev= get_recent_view (name, false, true, false, true);
      if (is_none (prev)) {
        prev= get_recent_view (name, false, true, false, false);
        if (is_none (prev)) break;
        prev= get_new_view (view_to_buffer (prev));
      }
      window_set_view (view_to_window (vs[i]), prev, false);
    }
  remove_buffer (name);
}

void
tm_server_windows_rep::kill_window (url wname) {
  array<url> vs= get_all_views ();
  for (int i=0; i<N(vs); i++) {
    url win= view_to_window (vs[i]);
    if (!is_none (win) && win != wname) {
      set_current_view (vs[i]);
      // FIXME: make sure that win obtains the focus of the GUI too
      delete_window (wname);
      return;
    }
  }
  if (number_of_servers () == 0) get_server () -> quit ();
  else delete_window (wname);
}

void
tm_server_windows_rep::kill_current_window_and_buffer () {
  if (N(bufs) <= 1) get_server () -> quit();
  url name= get_current_buffer ();
  array<url> vs= buffer_to_views (get_current_buffer ());
  url win= get_current_window ();
  bool kill= true;
  for (int i=0; i<N(vs); i++)
    if (view_to_window (vs[i]) != win)
      kill= false;
  kill_window (win);
  if (kill) remove_buffer (name);
}