
/******************************************************************************
* MODULE     : ns_widget.mm
* DESCRIPTION: Aqua widget class
* COPYRIGHT  : (C) 2007  Massimiliano Gubinelli
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#include "mac_cocoa.h" 

#include "ns_widget.h"
#include "ns_simple_widget.h"
#include "ns_other_widgets.h"
#include "ns_renderer.h"
#include "ns_utilities.h"
#include "ns_menu.h"


#include "gui.hpp"
#include "widget.hpp" 
#include "message.hpp"
#include "promise.hpp"
#include "analyze.hpp"

#include "ns_basic_widgets.h"

#import "TMView.h"
#import "TMButtonsController.h"

#define TYPE_CHECK(b) ASSERT (b, "type mismatch")
#define NOT_IMPLEMENTED \
  { if (DEBUG_EVENTS) cout << "STILL NOT IMPLEMENTED\n"; }

widget the_keyboard_focus(NULL);

@interface TMWindowController : NSWindowController
{
	ns_window_widget_rep *wid;
}
- (void) setWidget:(widget_rep*) w;
- (widget_rep*) widget;
@end



widget 
ns_widget_rep::plain_window_widget (string s) {
  (void) s;
  return widget ();
}

widget 
ns_widget_rep::make_popup_widget () {
  return this;
}

widget 
ns_widget_rep::popup_window_widget (string s) {
  (void) s;
  return widget();
}



TMMenuItem *
ns_widget_rep::as_menuitem() { 
  return [TMMenuItem alloc];  
}

/******************************************************************************
* ns_view_widget_rep
******************************************************************************/

#pragma mark ns_view_widget_rep

ns_view_widget_rep::ns_view_widget_rep(NSView *v) : 
  ns_widget_rep(), view(v) { 
  [v retain]; 
}

ns_view_widget_rep::~ns_view_widget_rep()  { 
  [view release]; 
}



void
ns_view_widget_rep::send (slot s, blackbox val) {
  switch (s) {
  case SLOT_NAME:
    {	
      check_type<string> (val, "SLOT_NAME");
      string name = open_box<string> (val);
      NSWindow *win = [view window];
      if (win) {
	[win setTitle:to_nsstring(name)];
      }
    }
    break;
  case SLOT_INVALIDATE:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord4>::id);
      coord4 p= open_box<coord4> (val);
      NSRect rect = to_nsrect(p);
      if (DEBUG_EVENTS) NSLog(@"invalidating %@",NSStringFromRect(rect));
      [view setNeedsDisplayInRect:rect];
    }
    break;
  case SLOT_INVALIDATE_ALL:
    {
      ASSERT (is_nil (val), "type mismatch");
      [view setNeedsDisplay:YES];
    }
    break;
  case SLOT_MOUSE_GRAB:
    NOT_IMPLEMENTED;
    //			send_mouse_grab (THIS, val);
    break;
  case SLOT_MOUSE_POINTER:
    NOT_IMPLEMENTED;
    //			send_mouse_pointer (THIS, val);
    break;
    
  case SLOT_KEYBOARD_FOCUS:
    //			send_keyboard_focus (THIS, val);
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      if (open_box<bool>(val)) the_keyboard_focus = this;
    }
    break;
	
  default:
    cout << "slot type= " << slot_name (s) << "\n";
    FAILED ("cannot handle slot type");
  }
}

/******************************************************************************
* Querying
******************************************************************************/

blackbox
ns_view_widget_rep::query (slot s, int type_id) {
  switch (s) {
  case SLOT_IDENTIFIER:
    TYPE_CHECK (type_id == type_helper<int>::id);
    return close_box<int> ([view window] ? 1 : 0);
  case SLOT_RENDERER:
    TYPE_CHECK (type_id == type_helper<renderer>::id);
    return close_box<renderer> ((renderer) the_aqua_renderer());
  case SLOT_POSITION:  
    {
      typedef pair<SI,SI> coord2;
      TYPE_CHECK (type_id == type_helper<coord2>::id);
      NSPoint pos = [view frame].origin;
      return close_box<coord2> (from_nspoint(pos));
    }
    
  default:
    FAILED ("cannot handle slot type");
    return blackbox ();
  }
}

/******************************************************************************
 * Notification of state changes
 ******************************************************************************/

void
ns_view_widget_rep::notify (slot s, blackbox new_val) {
  ns_widget_rep::notify (s, new_val);
}

/******************************************************************************
 * Read and write access of subwidgets
 ******************************************************************************/

widget
ns_view_widget_rep::read (slot s, blackbox index) {
  switch (s) {
  case SLOT_WINDOW:
    check_type_void (index, "SLOT_WINDOW");
    return [(TMWindowController*)[[view window] windowController] widget];
  default:
    FAILED ("cannot handle slot type");
    return widget();
  }
}

void
ns_view_widget_rep::write (slot s, blackbox index, widget w) {
  switch (s) {
  default:
    FAILED ("cannot handle slot type");
  }
}


widget 
ns_view_widget_rep::plain_window_widget (string s)
// creates a decorated window with name s and contents w
{
  NSRect screen_frame = [[NSScreen mainScreen] visibleFrame];
	
  NSWindow *nsw = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) 
				     styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
				     backing:NSBackingStoreBuffered
				     defer:NO] autorelease];
  // NSView *view = ((ns_view_widget_rep*)w.rep)->get_nsview();
  //	NSRect frame = [[nsw contentView] frame];
  //	[view setFrame:frame];
  [nsw setContentView:view];
  [nsw setTitle:to_nsstring(s)];
  [nsw setAcceptsMouseMovedEvents:YES];
  //	[[nsw contentView] addSubview:view];
  //	[nsw setToolbar:((ns_tm_widget_rep*)w.rep)->toolbar];
  widget wid =  tm_new <ns_window_widget_rep> (nsw);
  return wid; 
}


#pragma mark ns_tm_widget_rep

NSString *TMToolbarIdentifier = @"TMToolbarIdentifier";
NSString *TMButtonsIdentifier = @"TMButtonsIdentifier";

@interface TMToolbarItem : NSToolbarItem
@end
@implementation TMToolbarItem
- (void)validate
{
  NSSize s = [[self view] frame].size;
  NSSize s2 = [self minSize];
  if ((s.width != s2.width)||(s.height!=s2.height)) {
    [self setMinSize:s];
    [self setMaxSize:s];
  }
  //	NSLog(@"validate\n");
}
@end



@interface TMWidgetHelper : NSObject
{
@public
  ns_tm_widget_rep *wid;
  NSToolbarItem *ti;
}
- (void)notify:(NSNotification*)obj;
@end

@implementation TMWidgetHelper
-(void)dealloc
{
  [ti release]; [super dealloc];
}
- (void)notify:(NSNotification*)n
{
  wid->layout();
}
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  if (itemIdentifier == TMButtonsIdentifier) {
    if (!ti) {
      ti = [[TMToolbarItem alloc] initWithItemIdentifier:TMButtonsIdentifier];
      [ti setView:[wid->bc bar]];
      NSRect f = [[wid->bc bar] frame];
      //	NSSize s = NSMakeSize(900,70);
      NSSize s = f.size;
      [ti setMinSize:s];
      [ti setMaxSize:s];
      
    }
    return ti;
  }
  return nil;
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects:TMButtonsIdentifier,nil];
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects:TMButtonsIdentifier,nil];
}
@end


ns_tm_widget_rep::ns_tm_widget_rep(int mask) : ns_view_widget_rep([[[NSView alloc] initWithFrame:NSMakeRect(0,0,100,100)] autorelease]), 
  sv(nil), leftField(nil), rightField(nil), bc(nil), toolbar(nil) 
{
  // decode mask
  visibility[0] = (mask & 1)  == 1;  // header
  visibility[1] = (mask & 2)  == 2;  // main
  visibility[2] = (mask & 4)  == 4;  // context
  visibility[3] = (mask & 8)  == 8;  // user
  visibility[4] = (mask & 16) == 16; // footer
  
  
  NSSize s = NSMakeSize(100,20); // size of the right footer;
  NSRect r = [view bounds];
  NSRect r0 = r;
  //	r.size.height -= 100;
  //	r0.origin.y =+ r.size.height; r0.size.height = 100;
  NSRect r1 = r; r1.origin.y += s.height; r1.size.height -= s.height;
  NSRect r2 = r; r2.size.height = s.height;
  NSRect r3 = r2; 
  r2.size.width -= s.width; r3.origin.x =+ r2.size.width;
  sv = [[[NSScrollView alloc] initWithFrame:r1] autorelease];
  [sv setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [sv setHasVerticalScroller:YES];
  [sv setHasHorizontalScroller:YES];
  [sv setBorderType:NSNoBorder];
  //  [sv setBackgroundColor:[NSColor redColor]];
  [sv setBackgroundColor:[NSColor grayColor]];
  [sv setDocumentView:[[[NSView alloc] initWithFrame: NSMakeRect(0,0,100,100)] autorelease]];
  [view addSubview:sv];
  
  leftField = [[[NSTextField alloc] initWithFrame:r2] autorelease];
  rightField = [[[NSTextField alloc] initWithFrame:r3] autorelease];
  [leftField setAutoresizingMask:NSViewWidthSizable|NSViewMaxYMargin];
  [rightField setAutoresizingMask:NSViewMinXMargin|NSViewMaxYMargin];
  [leftField setEditable: NO];
  [rightField setEditable: NO];
  [leftField setBackgroundColor:[NSColor windowFrameColor]];
  [rightField setBackgroundColor:[NSColor windowFrameColor]];
  [leftField setBezeled:NO];
  [rightField setBezeled:NO];
  [rightField setAlignment:NSRightTextAlignment];
  [view addSubview:leftField];
  [view addSubview:rightField];
  
  bc = [[TMButtonsController alloc] init];
  //NSView *mt = [bc bar];
  //[mt setFrame:r0];
  //[mt setAutoresizingMask:NSViewMaxXMargin|NSViewMinYMargin];
  //[view addSubview:mt];
  //	[mt setPostsFrameChangedNotifications:YES];
  wh = [[TMWidgetHelper alloc] init];
  wh->wid = this;
#if 0
  [(NSNotificationCenter*)[NSNotificationCenter defaultCenter] addObserver:wh
			  selector:@selector(notify:)
			  name:NSViewFrameDidChangeNotification 
			  object:mt];
#endif
	
  toolbar = [[NSToolbar alloc] initWithIdentifier:TMToolbarIdentifier ];
  [toolbar setDelegate:wh];
  
  updateVisibility();
  
}

ns_tm_widget_rep::~ns_tm_widget_rep() 
{ 
  //	[(NSNotificationCenter*)[NSNotificationCenter defaultCenter] removeObserver:wh];
  [wh release];	
  [bc release]; 
}


void ns_tm_widget_rep::layout()
{
  NSSize s = NSMakeSize(100,20); // size of the right footer;
  NSRect r = [view bounds];
  NSRect r0 = r;
  //	NSRect rh = [[bc bar] frame];
  NSRect rh = NSMakeRect(0,0,0,0);
  r.size.height -= rh.size.height;
  r0.origin.y =+ r.size.height; r0.size.height = rh.size.height;
  NSRect r1 = r; r1.origin.y += s.height; r1.size.height -= s.height;
  NSRect r2 = r; r2.size.height = s.height;
  NSRect r3 = r2; 
  r2.size.width -= s.width; r3.origin.x =+ r2.size.width;
  r3.size.width -= r2.size.width + 15.0;
  [sv setFrame:r1];
  [leftField setFrame:r2];
  [rightField setFrame:r3];
  //[[bc bar] setFrame:r0];
  [NSApp setWindowsNeedUpdate:YES];
}


void ns_tm_widget_rep::updateVisibility()
{
  //FIXME: this implementation is from the Qt port. to be adapted.
#if 0
  mainToolBar->setVisible (visibility[1] && visibility[0]);
  contextToolBar->setVisible (visibility[2] && visibility[0]);
  userToolBar->setVisible (visibility[3] && visibility[0]);
  tm_mainwindow()->statusBar()->setVisible (visibility[4]);
#ifndef Q_WS_MAC
  tm_mainwindow()->menuBar()->setVisible (visibility[0]);
#endif
#endif
}



void
ns_tm_widget_rep::send (slot s, blackbox val) {
  switch (s) {
  case SLOT_EXTENTS:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord4>::id);
      coord4 p= open_box<coord4> (val);
      NSRect rect = to_nsrect(p);
      NSSize ws = [sv contentSize];
      NSSize sz = rect.size;
      sz.height = max (sz.height, ws.height );
      //			[[view window] setContentSize:rect.size];
      [[sv documentView] setFrameSize: sz];
    }
    break;
  case SLOT_HEADER_VISIBILITY:
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      bool f= open_box<bool> (val);
      visibility[0] = f;
      updateVisibility();
    }
    break;
  case SLOT_MAIN_ICONS_VISIBILITY:
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      bool f= open_box<bool> (val);
      visibility[1] = f;
      updateVisibility();
    }
    break;
  case SLOT_MODE_ICONS_VISIBILITY:
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      bool f= open_box<bool> (val);
      visibility[2] = f;
      updateVisibility();
    }
    break;
  case SLOT_USER_ICONS_VISIBILITY:
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      bool f= open_box<bool> (val);
      visibility[3] = f;
      updateVisibility();
    }
    break;
  case SLOT_FOOTER_VISIBILITY:
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      bool f= open_box<bool> (val);
      visibility[4] = f;
      updateVisibility();
    }
    break;
    
  case SLOT_LEFT_FOOTER:
    {
      TYPE_CHECK (type_box (val) == type_helper<string>::id);
      string msg = open_box<string> (val);
      [leftField setStringValue:to_nsstring_utf8 (tm_var_encode (msg))];
      [leftField displayIfNeeded];
    }
    break;
  case SLOT_RIGHT_FOOTER:
    {
      TYPE_CHECK (type_box (val) == type_helper<string>::id);
      string msg = open_box<string> (val);
      [rightField setStringValue:to_nsstring_utf8 (tm_var_encode (msg))];
      [rightField displayIfNeeded];
    }
    break;
    
  case SLOT_SCROLL_POSITION:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord2>::id);
      coord2 p= open_box<coord2> (val);
      NSPoint pt = to_nspoint(p);
      NSSize sz = [[sv contentView] bounds].size;
      if (DEBUG_EVENTS) cout << "Scroll position :" << pt.x << "," << pt.y << LF;
      [[sv documentView] scrollPoint:pt];
 //     [[sv documentView] scrollRectToVisible:NSMakeRect(pt.x,pt.y,1.0,1.0)];
    }
    break;
    
  case SLOT_SCROLLBARS_VISIBILITY:
    // ignore this: cocoa handles scrollbars independently
    //			send_int (THIS, "scrollbars", val);
    break;
    
  case SLOT_INTERACTIVE_MODE:
    {
      TYPE_CHECK (type_box (val) == type_helper<bool>::id);
      if (open_box<bool>(val) == true) {
        //FIXME: to postpone once we return to the runloop
	    do_interactive_prompt();
      }
    }
    break;
    
  case SLOT_ZOOM_FACTOR:
    {
      TYPE_CHECK (type_box (val) == type_helper<int>::id);
      simple_widget_rep *w = (simple_widget_rep *)[(TMView*)[sv documentView] widget];
      if (w) {
        double new_zoom = open_box<double> (val);
        if (DEBUG_EVENTS) cout << "New zoom factor :" << new_zoom << LF;
        w->handle_set_zoom_factor (new_zoom);
      }
      break;
    }

  case SLOT_FILE:
    {
      TYPE_CHECK (type_box (val) == type_helper<string>::id);
      string file = open_box<string> (val);
      if (DEBUG_EVENTS) cout << "File: " << file << LF;
//      view->window()->setWindowFilePath(to_qstring(file));
    }
      break;
      
      
  default:
    ns_view_widget_rep::send(s,val);
  }
}

blackbox
ns_tm_widget_rep::query (slot s, int type_id) {
  switch (s) {
  case SLOT_SCROLL_POSITION:
    {
      TYPE_CHECK (type_id == type_helper<coord2>::id);
      NSPoint pt = [[sv documentView] frame].origin;
      if (DEBUG_EVENTS)
        cout << "Position (" << pt.x << "," << pt.y << ")\n"; 
      return close_box<coord2> (from_nspoint(pt));
    }
        
  case SLOT_EXTENTS:
    {
      TYPE_CHECK (type_id == type_helper<coord4>::id);
      NSRect rect= [[sv documentView] frame];
      coord4 c= from_nsrect (rect);
      if (DEBUG_EVENTS) cout << "Canvas geometry (" << rect.origin.x 
        << "," << rect.origin.y
        << "," << rect.size.width
        << "," << rect.size.height
        << ")" << LF;
      return close_box<coord4> (c);
    }
        
        
  case SLOT_VISIBLE_PART:
    {
      TYPE_CHECK (type_id == type_helper<coord4>::id);
      NSRect rect= [sv documentVisibleRect];
      coord4 c= from_nsrect (rect);
      if (DEBUG_EVENTS) cout << "Visible region (" << rect.origin.x 
        << "," << rect.origin.y
        << "," << rect.size.width
        << "," << rect.size.height
        << ")" << LF;
      return close_box<coord4> (c);
    }

        
  case SLOT_USER_ICONS_VISIBILITY:
    TYPE_CHECK (type_id == type_helper<bool>::id);
    return close_box<bool> (visibility[3]);
        
  case SLOT_MODE_ICONS_VISIBILITY:
    TYPE_CHECK (type_id == type_helper<bool>::id);
    return close_box<bool> (visibility[2]);
    
  case SLOT_MAIN_ICONS_VISIBILITY:
    TYPE_CHECK (type_id == type_helper<bool>::id);
    return close_box<bool> (visibility[1]);
    
  case SLOT_HEADER_VISIBILITY:
    TYPE_CHECK (type_id == type_helper<bool>::id);
    return close_box<bool> (visibility[0]);
    
  case SLOT_FOOTER_VISIBILITY:
    TYPE_CHECK (type_id == type_helper<bool>::id);
    return close_box<bool> (visibility[4]);
    
  case SLOT_INTERACTIVE_INPUT:
    {
      TYPE_CHECK (type_id == type_helper<string>::id);
      return close_box<string> ( ((ns_input_text_widget_rep*) int_input.rep)->text );
      
    }
  case SLOT_INTERACTIVE_MODE:
    {
      TYPE_CHECK (type_id == type_helper<bool>::id);
      return close_box<bool> (false);  // FIXME: who needs this info?
    }
    
    
  default:
    return ns_view_widget_rep::query(s,type_id);
  }
}

widget
ns_tm_widget_rep::read (slot s, blackbox index) {
  switch (s) {
  default:
    return ns_view_widget_rep::read(s,index);
  }
}



@interface TMMenuHelper : NSObject
{
@public
  NSMenuItem *mi;
  NSMenu *menu;
}
+ (TMMenuHelper *)sharedHelper;
- init;
- (void)setMenu:(NSMenu *)_mi;
@end

TMMenuHelper *the_menu_helper = nil;

@implementation TMMenuHelper
- init { 
  [super init]; mi = nil; menu = nil; 
  
  mi = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Menu" action:NULL keyEquivalent:@""];
  NSMenu *sm = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Menu"] autorelease];
  [mi  setSubmenu:sm];
  //[[NSApp mainMenu] removeItem: [[NSApp mainMenu] itemWithTitle:@"Help"]]; //FIXME: Help menu causes problems (crash)
  
  [[NSApp mainMenu] insertItem: mi atIndex:1];	
  //	[sm setDelegate: self];
  
  return self; 
}
- (void)setMenu:(NSMenu *)_m  
{ 
  if (menu) [menu release];  menu = _m; [menu retain];
  [mi  setSubmenu:menu];
  [menu setTitle:@"Menu"];	
};
- (void)dealloc { [mi release]; [menu release]; [super dealloc]; }
+ (TMMenuHelper *)sharedHelper 
{ 
  if (!the_menu_helper) 
    {
      the_menu_helper = [[TMMenuHelper alloc] init];
    }
  return the_menu_helper; 
}

#if 0
- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel
{
  return NO;
}
#endif
@end




void
ns_tm_widget_rep::write (slot s, blackbox index, widget w) {
  switch (s) {
  case SLOT_SCROLLABLE: 
    {
      check_type_void (index, "SLOT_SCROLLABLE");
      NSView *v = ((ns_view_widget_rep*) w.rep)->view;
      [sv setDocumentView: v];
      [[sv window] makeFirstResponder:v];
    }
    break;
  case SLOT_MAIN_MENU:
    check_type_void (index, "SLOT_MAIN_MENU");
    [[TMMenuHelper sharedHelper] setMenu:to_nsmenu(w)];
    break;
  case SLOT_MAIN_ICONS:
    check_type_void (index, "SLOT_MAIN_ICONS");
    [bc setMenu:to_nsmenu(w) forRow:0];
    layout();
    break;
  case SLOT_MODE_ICONS:
    check_type_void (index, "SLOT_MODE_ICONS");
    [bc setMenu:to_nsmenu(w) forRow:1];
    layout();
    break;
  case SLOT_FOCUS_ICONS:
    check_type_void (index, "SLOT_FOCUS_ICONS");
    [bc setMenu:to_nsmenu(w) forRow:2];
    layout();
    break;
  case SLOT_USER_ICONS:
    check_type_void (index, "SLOT_USER_ICONS");
    [bc setMenu:to_nsmenu(w) forRow:3];
    layout();
    break;
  case SLOT_INTERACTIVE_PROMPT:
    check_type_void (index, "SLOT_INTERACTIVE_PROMPT");
    int_prompt = concrete(w); 
    //			THIS << set_widget ("interactive prompt", concrete (w));
    break;
  case SLOT_INTERACTIVE_INPUT:
    check_type_void (index, "SLOT_INTERACTIVE_INPUT");
    int_input = concrete(w);
    //			THIS << set_widget ("interactive input", concrete (w));
    break;
  default:
    ns_view_widget_rep::write(s,index,w);
  }
}

widget
ns_tm_widget_rep::plain_window_widget (string s) {
  // creates a decorated window with name s and contents w
  widget w = ns_view_widget_rep::plain_window_widget(s);
  // to manage correctly retain counts
  ns_window_widget_rep * wid = (ns_window_widget_rep *)(w.rep);
  [[wid->get_windowcontroller() window] setToolbar:toolbar];
  return wid;
}



#pragma mark ns_window_widget_rep



@implementation TMWindowController
- (void)setWidget:(widget_rep*) w
{
  wid = (ns_window_widget_rep*)w;
}

- (widget_rep*)widget
{
  return (ns_widget_rep*)wid;
}

@end

ns_window_widget_rep::ns_window_widget_rep(NSWindow *win) 
: widget_rep(), wc([[[TMWindowController alloc] initWithWindow:win] autorelease]) 
{ [wc retain]; [wc setWidget:this]; }

ns_window_widget_rep::~ns_window_widget_rep()  { [wc release]; }

TMWindowController *ns_window_widget_rep::get_windowcontroller() { return wc; }



void
ns_window_widget_rep::send (slot s, blackbox val) {
  switch (s) {
  case SLOT_SIZE:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord2>::id);
      coord2 p= open_box<coord2> (val);
      NSWindow *win = [wc window];
      if (win) {
        NSSize size = to_nssize(p);
        [win setContentSize:size];
      }
    }
    break;
  case SLOT_POSITION:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord2>::id);
      coord2 p= open_box<coord2> (val);
      NSWindow *win = [wc window];
      if (win) { 
        [win setFrameOrigin:to_nspoint(p)];
      }
    }
    break;
  case SLOT_VISIBILITY:
    {	
      check_type<bool> (val, "SLOT_VISIBILITY");
      bool flag = open_box<bool> (val);
      NSWindow *win = [wc window];
      if (win) {
        if (flag) [win makeKeyAndOrderFront:nil] ;
        else [win orderOut:nil]  ;
      }
    }	
    break;
  case SLOT_NAME:
    {	
      check_type<string> (val, "SLOT_NAME");
      string name = open_box<string> (val);
      NSWindow *win = [wc window];
      if (win) {
        NSString *title = to_nsstring(name);
        [win setTitle:title];
      }
    }
    break;
  case SLOT_FULL_SCREEN:
    check_type<bool> (val, "SLOT_FULL_SCREEN");
    //FIXME: Implement fullscreen mode
    // win->set_full_screen (open_box<bool> (val));
    break;
  case SLOT_UPDATE:
    NOT_IMPLEMENTED ;
    // send_update (THIS, val);
    break;
  case SLOT_REFRESH:
    NOT_IMPLEMENTED ;
    // send_refresh (THIS, val);
    break;
    
  default:
    FAILED ("cannot handle slot type");
  }
}


blackbox
ns_window_widget_rep::query (slot s, int type_id) {
  switch (s) {
  case SLOT_IDENTIFIER:
    TYPE_CHECK (type_id == type_helper<int>::id);
    return close_box<int> ((intptr_t) [wc window] ? 1 : 0);
  case SLOT_POSITION:  
    {
      typedef pair<SI,SI> coord2;
      TYPE_CHECK (type_id == type_helper<coord2>::id);
      NSRect frame = [[wc window] frame];
      return close_box<coord2> (from_nspoint(frame.origin));
    }
  case SLOT_SIZE:
    {
      typedef pair<SI,SI> coord2;
      TYPE_CHECK (type_id == type_helper<coord2>::id);
      NSRect frame = [[wc window] frame];
      return close_box<coord2> (from_nssize(frame.size));
    }
  default:
    FAILED ("cannot handle slot type");
    return blackbox ();
  }
}

/******************************************************************************
 * Notification of state changes
 ******************************************************************************/

void
ns_window_widget_rep::notify (slot s, blackbox new_val) {
  widget_rep::notify (s, new_val);
}

widget
ns_window_widget_rep::read (slot s, blackbox index) {
  switch (s) {
  default:
    FAILED ("cannot handle slot type");
    return widget();
  }
}

void
ns_window_widget_rep::write (slot s, blackbox index, widget w) {
  switch (s) {
  default:
    FAILED ("cannot handle slot type");
  }
}


/******************************************************************************
* simple_widget_rep
******************************************************************************/
#pragma mark simple_widget_rep

/******************************************************************************
* Constructor
******************************************************************************/

simple_widget_rep::simple_widget_rep ()
: ns_view_widget_rep ([[[TMView alloc] initWithFrame:NSMakeRect(0,0,1000,1000)] autorelease]) 
{ 
  [(TMView*)view setWidget:this];
}


/******************************************************************************
* Empty handlers for redefinition later on
******************************************************************************/

void
simple_widget_rep::handle_get_size_hint (SI& w, SI& h) {
  gui_root_extents (w, h);  
}

void
simple_widget_rep::handle_notify_resize (SI w, SI h) {
  (void) w; (void) h; 
}

void
simple_widget_rep::handle_keypress (string key, time_t t) {
  (void) key; (void) t;
}

void
simple_widget_rep::handle_keyboard_focus (bool has_focus, time_t t) {
  (void) has_focus; (void) t;
}

void
simple_widget_rep::handle_mouse (string kind, SI x, SI y, int mods, time_t t) {
  (void) kind; (void) x; (void) y; (void) mods; (void) t;
}

void
simple_widget_rep::handle_set_zoom_factor (double zoom) {
  (void) zoom;
}

void
simple_widget_rep::handle_clear (SI x1, SI y1, SI x2, SI y2) {
  (void) x1; (void) y1; (void) x2; (void) y2;
}

void
simple_widget_rep::handle_repaint (SI x1, SI y1, SI x2, SI y2) {
  (void) x1; (void) y1; (void) x2; (void) y2;
}


void
simple_widget_rep::send (slot s, blackbox val) {
  if (DEBUG_QT) cout << "ns_simple_widget_rep::send " << slot_name(s) << LF;
  switch (s) {
    case SLOT_INVALIDATE:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord4>::id);
      coord4 p= open_box<coord4> (val);
      if (DEBUG_QT)
        cout << "Invalidating rect " << rectangle(p.x1,p.x2,p.x3,p.x4) << LF;
      ns_renderer_rep* ren = (ns_renderer_rep*)get_renderer (this);
      if (ren) {
        SI x1 = p.x1, y1 = p.x2, x2 = p.x3, y2 = p.x4;    
        ren->outer_round (x1, y1, x2, y2);
        ren->decode (x1, y1);
        ren->decode (x2, y2);
        //tm_canvas()->invalidate_rect (x1,y2,x2,y1);
      }
    }
      break;
    case SLOT_INVALIDATE_ALL:
    {
      ASSERT (is_nil (val), "type mismatch");
      if (DEBUG_QT)
        cout << "Invalidating all"<<  LF;
      //tm_canvas()->invalidate_all ();
    }
      break;
    case SLOT_CURSOR:
    {
      TYPE_CHECK (type_box (val) == type_helper<coord2>::id);
      coord2 p= open_box<coord2> (val);
      //QPoint pt = to_qpoint(p);
      //tm_canvas() -> setCursorPos(pt);
    }
      break;
      
    default:
      if (DEBUG_QT) cout << "[ns_simple_widget_rep] ";
      ns_view_widget_rep::send (s, val);
      //      FAILED ("unhandled slot type");
  }
  
}



blackbox
simple_widget_rep::query (slot s, int type_id) {
  return ns_view_widget_rep::query(s,type_id);
}

void
simple_widget_rep::notify (slot s, blackbox new_val) {
  ns_view_widget_rep::notify (s, new_val);
}

/******************************************************************************
 * Read and write access of subwidgets
 ******************************************************************************/

widget
simple_widget_rep::read (slot s, blackbox index) {
  return ns_view_widget_rep::read(s,index);
}

void
simple_widget_rep::write (slot s, blackbox index, widget w) {
  ns_view_widget_rep::write(s,index,w);
}




/******************************************************************************
* Window widgets
******************************************************************************/

#pragma mark Widget interface


widget plain_window_widget (widget w, string s, command c)
// creates a decorated window with name s and contents w
{
  return concrete(w)->plain_window_widget(s);
}

widget popup_window_widget (widget w, string s) 
// creates an undecorated window with name s and contents w
{
  return concrete(w)->popup_window_widget(s);
}

void   destroy_window_widget (widget w) {  
// destroys a window as created by the above routines
  (void) w;
}

/******************************************************************************
 * Top-level widgets, typically given as an argument to plain_window_widget
 * See also message.hpp for specific messages for these widgets
 ******************************************************************************/

widget texmacs_widget (int mask, command quit) 
// the main TeXmacs widget and a command which is called on exit
// the mask variable indicates whether the menu, icon bars, status bar, etc.
// are visible or not
{
  (void) mask; (void) quit; // FIXME: handle correctly mask and quit

  widget w = tm_new <ns_tm_widget_rep> (mask);
  return w; 
}





widget popup_widget (widget w) 
// a widget container which results w to be unmapped as soon as
// the pointer quits the widget
// used in edit_mouse.cpp to implement a contextual menu in the canvas
{
  return concrete(w)->make_popup_widget();
}


/******************************************************************************
 *  Widgets which are not strictly required by TeXmacs
 *  their implementation is void
 ******************************************************************************/

widget
empty_widget () {
  // an empty widget of size zero
  NOT_IMPLEMENTED;
  return widget();
}

widget
glue_widget (bool hx, bool vx, SI w, SI h) {
  //{ return widget(); }
  // an empty widget of minimal width w and height h and which is horizontally
  // resp. vertically extensible if hx resp. vx is true
  NOT_IMPLEMENTED;
  (void) hx; (void) vx; (void) w; (void) h;
  return tm_new <ns_view_widget_rep> ([[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 50, 50)] autorelease]);
}

widget
glue_widget (tree col, bool hx, bool vx, SI w, SI h) {
  (void) col;
  return glue_widget (hx, vx, w, h);
}

widget
extend (widget w, array<widget> a) {
  (void) a;
  return w;
}

widget
wait_widget (SI width, SI height, string message) { 
  // a widget of a specified width and height, displaying a wait message
  // this widget is only needed when using the X11 plugin
  (void) width; (void) height; (void) message;
  return widget(); 
}



/******************************************************************************
 * TeXmacs interface for the creation of widgets.
 * See Graphics/Gui/widget.hpp for comments.
 ******************************************************************************/

//widget horizontal_menu (array<widget> arr) { return widget(); }
//widget vertical_menu (array<widget> arr) { return widget(); }
//widget horizontal_list (array<widget> arr) { return widget(); }
//widget vertical_list (array<widget> arr)  { return widget(); }
widget aligned_widget (array<widget> lhs, array<widget> rhs, SI hsep, SI vsep, SI lpad, SI rpad)  { return widget(); }
widget tabs_widget (array<widget> tabs, array<widget> bodies)  { return widget(); }
widget icon_tabs_widget (array<url> us, array<widget> ts, array<widget> bs)  { return widget(); }
widget wrapped_widget (widget w, command cmd) { return widget(); }
//widget tile_menu (array<widget> a, int cols)  { return widget(); }
//widget minibar_menu (array<widget> arr)  { return widget(); }
//widget menu_separator (bool vertical)  { return widget(); }
//widget menu_group (string name, int style)  { return widget(); }
//widget pulldown_button (widget w, promise<widget> pw)  { return widget(); }
//widget pullright_button (widget w, promise<widget> pw)  { return widget(); }
//widget menu_button (widget w, command cmd, string pre, string ks, int style)  { return widget(); }
//widget balloon_widget (widget w, widget help)  { return widget(); }
//widget text_widget (string s, int style, color col, bool tsp)  { return widget(); }
//widget xpm_widget (url file_name)  { return widget(); }
widget toggle_widget (command cmd, bool on, int style)  { return widget(); }
widget enum_widget (command cmd, array<string> vals, string val, int style, string width)  { return widget(); }
widget choice_widget (command cmd, array<string> vals, array<string> chosen) { return widget(); }
widget choice_widget (command cmd, array<string> vals, string cur) { return widget(); }
widget choice_widget (command cmd, array<string> vals, string cur, string filter)  { return widget(); }
widget user_canvas_widget (widget wid, int style)  { return widget(); }
widget resize_widget (widget w, int style, string w1, string h1,
                      string w2, string h2, string w3, string h3)  { return widget(); }
widget hsplit_widget (widget l, widget r)  { return widget(); }
widget vsplit_widget (widget t, widget b)  { return widget(); }
widget refresh_widget (string tmwid, string kind)  { return widget(); }
//widget glue_widget (bool hx, bool vx, SI w, SI h)  { return widget(); }
//widget glue_widget (tree col, bool hx, bool vx, SI w, SI h)  { return widget(); }
//widget inputs_list_widget (command call_back, array<string> prompts)  { return widget(); }
//widget input_text_widget (command call_back, string type, array<string> def,
//                          int style, string width)  { return widget(); }
//widget color_picker_widget (command call_back, bool bg, array<tree> proposals)  { return widget(); }
//widget file_chooser_widget (command cmd, string type, bool save)  { return widget(); }
//widget printer_widget (command cmd, url ps_pdf_file)  { return widget(); }
//widget texmacs_widget (int mask, command quit)  { return widget(); }
widget ink_widget (command cb)  { return widget(); }

//// Widgets which are not strictly required by TeXmacs have void implementations

//widget empty_widget () { NOT_IMPLEMENTED; return widget(); }
//widget extend (widget w, array<widget> a) { (void) a; return w; }
//widget wait_widget (SI width, SI height, string message) {
//  (void) width; (void) height; (void) message; return widget();
//}