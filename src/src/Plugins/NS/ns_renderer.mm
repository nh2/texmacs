
/******************************************************************************
* MODULE     : ns_renderer.mm
* DESCRIPTION: Cocoa drawing interface class
* COPYRIGHT  : (C) 2006 Massimiliano Gubinelli
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#include "mac_cocoa.h"
#include "ns_renderer.h"
#include "analyze.hpp"
#include "image_files.hpp"
#include "file.hpp"

#include "ns_utilities.h"
#include "MacOS/mac_images.h"



/******************************************************************************
 * Cocoa images
 ******************************************************************************/

struct ns_image_rep: concrete_struct {
	NSImage* img;
	SI xo,yo;
	int w,h;
	ns_image_rep (NSImage* img2, SI xo2, SI yo2, int w2, int h2) :
      img (img2), xo (xo2), yo (yo2), w (w2), h (h2) { [img retain]; };
	~ns_image_rep()  {  [img release]; };
	friend class ns_image;
};

class ns_image {
  CONCRETE_NULL(ns_image);
  ns_image (NSImage* img2, SI xo2, SI yo2, int w2, int h2):
    rep (tm_new <ns_image_rep> (img2, xo2, yo2, w2, h2)) {}
};

CONCRETE_NULL_CODE(ns_image);

/******************************************************************************
 * CG images
 ******************************************************************************/

struct cg_image_rep: concrete_struct {
	CGImageRef img;
	SI xo,yo;
	int w,h;
	cg_image_rep (CGImageRef img2, SI xo2, SI yo2, int w2, int h2) :
      img (img2), xo (xo2), yo (yo2), w (w2), h (h2) { CGImageRetain(img); };
	~cg_image_rep()  {  CGImageRelease(img); };
	friend class cg_image;
};

class cg_image {
	CONCRETE_NULL(cg_image);
	cg_image (CGImageRef img2, SI xo2, SI yo2, int w2, int h2):
      rep (tm_new <cg_image_rep> (img2, xo2, yo2, w2, h2)) {}
};

CONCRETE_NULL_CODE(cg_image);

/******************************************************************************
 * Global support variables for all ns_renderers
 ******************************************************************************/

// bitmaps of all characters
static hashmap<basic_character,cg_image> character_image;
// image cache
//static hashmap<string,ns_image> images;

/******************************************************************************
 * ns_renderer
 ******************************************************************************/

ns_renderer_rep::ns_renderer_rep (int w2, int h2) :
  basic_renderer_rep (true, w2, h2), context(nil), view(nil)
{
}

ns_renderer_rep::~ns_renderer_rep () {
  if (context) end();
} ;

void 
ns_renderer_rep::begin (void * c) { 
  context = (NSGraphicsContext*)c; 
  [context retain];
//  CGContextBeginPage(context, NULL);
}

void 
ns_renderer_rep::end () { 
//  CGContextEndPage(context);
  [context release];    
//  CGContextRelease(context); 
  context = NULL;
  view = nil;
}

void
ns_renderer_rep::ensure_context () {
  if (context) [NSGraphicsContext setCurrentContext:context];
}


void
ns_renderer_rep::get_extents (int& w2, int& h2) {
    if (view) {
        NSSize sz = [view bounds].size;
        w2 = sz.width; h2 = sz.height;
    } else {
        w2 = w; h2 = h;
    }
}

void
ns_renderer_rep::set_zoom_factor (double zoom) {
    renderer_rep::set_zoom_factor (retina_factor * zoom);
    retina_pixel= pixel * retina_factor;
}

void
ns_set_color (color col) {
    [to_nscolor(col) set];
}


void
ns_renderer_rep::set_pencil (pencil p) {
  basic_renderer_rep::set_pencil (p);
  ensure_context ();
  ns_set_color (pen->get_color ());
  double pw= (((double) pen->get_width ()) / ((double) pixel));
#if 0
  if (pw <= pixel) {
    [NSBezierPath setDefaultLineWidth:1.0];
  }
  else {
    [NSBezierPath setDefaultLineWidth: (pen->w+thicken)/(1.0*pixel)];
  }
#else
  [NSBezierPath setDefaultLineWidth: pw];
#endif
    if (pen->get_type () == pencil_brush) {
        brush br= pen->get_brush ();
#if 0
        //FIXME: brushes
        QImage* pm= get_pattern_image (br, pixel);
        int pattern_alpha= br->get_alpha ();
        painter->setOpacity (qreal (pattern_alpha) / qreal (255));
        if (pm != NULL) {
            b= QBrush (*pm);
            double pox, poy;
            decode (0, 0, pox, poy);
            QTransform tr;
            tr.translate (pox, poy);
            b.setTransform (tr);
            p= QPen (b, pw);
        }
#endif
    }
  [NSBezierPath setDefaultLineCapStyle: ((pen->get_cap () == cap_round) ? NSRoundLineCapStyle : NSButtLineCapStyle)];
  [NSBezierPath setDefaultLineJoinStyle: NSRoundLineJoinStyle];
}

void
ns_renderer_rep::line (SI x1, SI y1, SI x2, SI y2) {
  double rx1, ry1, rx2, ry2;
  decode (x1, y1, rx1, ry1);
  decode (x2, y2, rx2, ry2);

  ensure_context ();
 // y1--; y2--; // top-left origin to bottom-left origin conversion
  [NSBezierPath strokeLineFromPoint:NSMakePoint(rx1,ry1) toPoint:NSMakePoint(rx2,ry2)];
}

void
ns_renderer_rep::lines (array<SI> x, array<SI> y) {
  int i, n= N(x);
  if ((N(y) != n) || (n<1)) return;
  STACK_NEW_ARRAY (pnt, NSPoint, n);
  ensure_context ();
  for (i=0; i<n; i++) {
    double xx, yy;
    decode (x[i], y[i], xx, yy);
    pnt[i] = NSMakePoint (xx,yy);
    if (i>0) [NSBezierPath strokeLineFromPoint:pnt[i-1] toPoint:pnt[i]]; // FIX: hack
  }
  STACK_DELETE_ARRAY (pnt);
}

void
ns_renderer_rep::clear (SI x1, SI y1, SI x2, SI y2) {
  x1= max (x1, cx1-ox); y1= max (y1, cy1-oy);
  x2= min (x2, cx2-ox); y2= min (y2, cy2-oy);
  // outer_round (x1, y1, x2, y2); might still be needed somewhere
  decode (x1, y1);
  decode (x2, y2);
	  if ((x1>=x2) || (y1<=y2)) return;
	NSRect rect = NSMakeRect (x1, y2, x2-x1, y1-y2);
  ensure_context ();
  ns_set_color (bg_brush->get_color ());
  [NSBezierPath fillRect:rect];
 // ns_set_color (pen->get_color ());
}

void
ns_renderer_rep::fill (SI x1, SI y1, SI x2, SI y2) {
  if ((x2>x1) && ((x2-x1)<pixel)) {
    SI d= pixel-(x2-x1);
    x1 -= (d>>1);
    x2 += ((d+1)>>1);
  }
  if ((y2>y1) && ((y2-y1)<pixel)) {
    SI d= pixel-(y2-y1);
    y1 -= (d>>1);
    y2 += ((d+1)>>1);
  }
  
  x1= max (x1, cx1-ox); y1= max (y1, cy1-oy);
  x2= min (x2, cx2-ox); y2= min (y2, cy2-oy);
  // outer_round (x1, y1, x2, y2); might still be needed somewhere
  if ((x1>=x2) || (y1>=y2)) return;
  
  decode (x1, y1);
  decode (x2, y2);
  ensure_context ();
  ns_set_color (pen->get_color ());
  [NSBezierPath fillRect:NSMakeRect(x1,y2,x2-x1,y1-y2)];
}

void
ns_renderer_rep::arc (SI x1, SI y1, SI x2, SI y2, int alpha, int delta) {
  if ((x1>=x2) || (y1>=y2)) return;
  double rx1, ry1, rx2, ry2;
  decode (x1, y1, rx1, ry1);
  decode (x2, y2, rx2, ry2);
  ensure_context ();
  //FIXME: XDrawArc (dpy, win, gc, x1, y2, x2-x1, y1-y2, alpha, delta);
}

void
ns_renderer_rep::fill_arc (SI x1, SI y1, SI x2, SI y2, int alpha, int delta) {
  if ((x1>=x2) || (y1>=y2)) return;
  double rx1, ry1, rx2, ry2;
  decode (x1, y1, rx1, ry1);
  decode (x2, y2, rx2, ry2);
  ensure_context ();
  //FIXME: XFillArc (dpy, win, gc, x1, y2, x2-x1, y1-y2, alpha, delta);
}

void
ns_renderer_rep::polygon (array<SI> x, array<SI> y, bool convex) {  
  int i, n= N(x);
  if ((N(y) != n) || (n<1)) return;
  STACK_NEW_ARRAY (pnt, NSPoint, n);
  for (i=0; i<n; i++) {
    double xx,yy;
    decode (x[i], y[i], xx, yy);
    pnt[i] = NSMakePoint(xx,yy);
  }
  
  ensure_context ();
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path  appendBezierPathWithPoints:pnt count:n];
  [path setWindingRule:(convex? NSEvenOddWindingRule : NSNonZeroWindingRule)];
  [path fill];
  STACK_DELETE_ARRAY (pnt);
}

void
ns_renderer_rep::draw_triangle (SI x1, SI y1, SI x2, SI y2, SI x3, SI y3) {
  array<SI> x (3), y (3);
  x[0]= x1; y[0]= y1;
  x[1]= x2; y[1]= y2;
  x[2]= x3; y[2]= y3;
  NSPoint pnt[3];
  int i, n= N(x);
  if ((N(y) != n) || (n<1)) return;
  for (i=0; i<n; i++) {
     double xx,yy;
     decode (x[i], y[i], xx, yy);
     pnt[i] = NSMakePoint(xx,yy);
  }
  ensure_context ();
  NSBezierPath *path = [NSBezierPath bezierPath];
  [path  appendBezierPathWithPoints:pnt count:n];
  [path setWindingRule: NSEvenOddWindingRule];
  [path fill];
}


/******************************************************************************
 * Image rendering
 ******************************************************************************/

#if 0 // old code
void
ns_renderer_rep::image (url u, SI w, SI h, SI x, SI y, int alpha) {
  // Given an image of original size (W, H),
  // we display it at position (x, y) in a rectangle of size (w, h)
  
  // if (DEBUG_EVENTS) debug_events << "cg_renderer_rep::image " << as_string(u) << LF;
  (void) alpha; // FIXME
  
  w= w/pixel; h= h/pixel;
  decode (x, y);
  
  ensure_context ();

  //painter.setRenderHints (0);
  //painter.drawRect (QRect (x, y-h, w, h));
  
  NSImage *pm = NULL;
  if (suffix (u) == "png") {
    // rendering
    string suu = as_string (u);
    // debug_events << suu << LF;
    pm = [[NSImage alloc] initWithContentsOfFile:to_nsstring(suu)];
  }
  else if (suffix (u) == "ps" ||
           suffix (u) == "eps" ||
           suffix (u) == "pdf") {
    url temp= url_temp (".png");
    mac_image_to_png (u, temp, w, h);
//  system ("convert", u, temp);
    string suu = as_string (temp);
    pm = [[NSImage alloc] initWithContentsOfFile:to_nsstring(suu)];
    remove (temp);
  }
    
  if (pm == NULL ) {
    debug_events << "TeXmacs] warning: cannot render " << as_string (u) << "\n";
    return;
  }
 
  NSSize isz = [pm size];
  [pm setFlipped:YES];
//  [pm drawAtPoint:NSMakePoint(x,y) fromRect:NSMakeRect(0,0,w,h) operation:NSCompositeSourceAtop fraction:1.0];
  [pm drawInRect:NSMakeRect(x,y-h,w,h) fromRect:NSMakeRect(0,0,isz.width,isz.height) operation:NSCompositeSourceAtop fraction:1.0];
}

void
ns_renderer_rep::draw_clipped (NSImage *im, int w, int h, SI x, SI y) {
  decode (x , y );
  y--; // top-left origin to bottom-left origin conversion
  ensure_context ();
  [im drawAtPoint:NSMakePoint(x,y) fromRect:NSMakeRect(0,0,w,h) operation:NSCompositeSourceAtop fraction:1.0];
}

void ns_renderer_rep::draw (int c, font_glyphs fng, SI x, SI y) {
  // get the pixmap
  ensure_context ();
  basic_character xc (c, fng, std_shrinkf, 0, 0);
  cg_image mi = character_image [xc];
  if (is_nil(mi)) {
    // debug_events << "CACHING:" << c << "\n" ;
    SI xo, yo;
    glyph pre_gl= fng->get (c); if (is_nil (pre_gl)) return;
    glyph gl= shrink (pre_gl, std_shrinkf, std_shrinkf, xo, yo);
    int i, j, w= gl->width, h= gl->height;
    NSImage *im = [[NSImage alloc] initWithSize:NSMakeSize(w,h)];
    int nr_cols= std_shrinkf*std_shrinkf;
    if (nr_cols >= 64) nr_cols= 64;
    
    [im lockFocus];
    for (j=0; j<h; j++)
      for (i=0; i<w; i++) {
        int col = gl->get_x (i, j);
        [[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha: ((255*col)/(nr_cols+1))/255.0] set];
        [NSBezierPath fillRect:NSMakeRect(i,j,1,1)];
      }
    [im unlockFocus];
    
    ns_image mi2(im, xo, yo, w, h );
    mi = mi2;
    [im release]; // ns_image retains im
    character_image (xc)= mi;
    // FIXME: we must release the image at some point (this should be ok now, see ns_image)
  }
  
  // draw the character
  {
    CGContextRef cgc = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    (void) w; (void) h;
    int x1= x- mi->xo*std_shrinkf;
    int y1=  y+ mi->yo*std_shrinkf;
    decode (x1, y1);
    y1--; // top-left origin to bottom-left origin conversion
    CGRect r = CGRectMake(x1,y1,mi->w,mi->h);
    CGContextSetShouldAntialias (cgc, true);
    CGContextSaveGState (cgc);
    //  ns_set_color (context, pen->get_color ());
    CGContextClipToMask (cgc, r, (CGImage*)(mi->img));
    CGContextFillRect (cgc, r);
    CGContextRestoreGState (cgc);
  }
  
  
  // draw the character
  //  draw_clipped (mi->img, mi->w, mi->h,
  //               x- mi->xo*std_shrinkf, y+ mi->yo*std_shrinkf);
}
#endif

static CGContextRef 
MyCreateBitmapContext (int pixelsWide, int pixelsHigh) {
    int bitmapBytesPerRow   = (pixelsWide * 4);
    int bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);	
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    void *bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        //fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    CGContextRef context = CGBitmapContextCreate (bitmapData, pixelsWide,	pixelsHigh,	8,
                                                  bitmapBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    if (context == NULL) {
        free (bitmapData);
		// fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease (colorSpace);
    return context;
}


void
ns_renderer_rep::draw (int c, font_glyphs fng, SI x, SI y) {
	// get the pixmap
  ensure_context ();
	basic_character xc (c, fng, std_shrinkf, 0, 0);
	cg_image mi = character_image [xc];
	if (is_nil(mi)) {
		SI xo, yo;
		glyph pre_gl= fng->get (c); if (is_nil (pre_gl)) return;
		glyph gl= shrink (pre_gl, std_shrinkf, std_shrinkf, xo, yo);
		int i, j, w= gl->width, h= gl->height;
		CGImageRef im = NULL;
		{
			CGContextRef ic = MyCreateBitmapContext(w,h);
			int nr_cols= std_shrinkf*std_shrinkf;
			if (nr_cols >= 64) nr_cols= 64;
			//CGContextSetShouldAntialias(ic,true);
			CGContextSetBlendMode(ic,kCGBlendModeCopy);
			//CGContextSetRGBFillColor(ic,1.0,1.0,1.0,0.0);
			//CGContextFillRect(ic,CGRectMake(0,0,w,h));
			
			for (j=0; j<h; j++)
				for (i=0; i<w; i++) {
					int col = gl->get_x (i, j);
					CGContextSetRGBFillColor(ic, 0.0,0.0,0.0,  ((255*col)/(nr_cols+1))/255.0);
					CGContextFillRect(ic,CGRectMake(i,j,1,1));
				}
			im = CGBitmapContextCreateImage (ic);
			CGContextRelease (ic);
		}
		cg_image mi2 (im, xo, yo, w, h);
		mi = mi2;
		CGImageRelease(im); // cg_image retains im
		character_image (xc)= mi;
	}
	
	// draw the character
	{
    CGContextRef cgc = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];

		(void) w; (void) h;
		int x1= x- mi->xo*std_shrinkf;
		int y1=  y+ mi->yo*std_shrinkf;
		decode (x1, y1);
		y1--; // top-left origin to bottom-left origin conversion
		CGRect r = CGRectMake(x1,y1,mi->w,mi->h);
		CGContextSetShouldAntialias (cgc, true);
		CGContextSaveGState (cgc);
		//  cg_set_color (context, pen->get_color ());
		CGContextClipToMask (cgc, r, mi->img); 
		CGContextFillRect (cgc, r);
		CGContextRestoreGState (cgc);
	}  
}


/******************************************************************************
* Setting up and displaying xpm pixmaps
******************************************************************************/

#if 0
NSImage* xpm_init (url file_name)
{
  tree t= xpm_load (file_name);
  
  // get main info
  int ok, i=0, j, k, w, h, c, b, x, y;
  string s= as_string (t[0]);
  skip_spaces (s, i);
  ok= read_int (s, i, w);
  skip_spaces (s, i);
  ok= read_int (s, i, h) && ok;
  skip_spaces (s, i);
  ok= read_int (s, i, c) && ok;
  skip_spaces (s, i);
  ok= read_int (s, i, b) && ok;
  if ((!ok) || (N(t)<(c+1)) || (c<=0)) {
    failed_error << "File name= " << file_name << "\n";
    FAILED ("invalid xpm");
  }
  
  // setup colors
  string first_name;
  hashmap<string,color> pmcs;
  for (k=0; k<c; k++) {
    string s   = as_string (t[k+1]);
    string name= "";
    string def = "none";
    if (N(s)<b) i=N(s);
    else { name= s(0,b); i=b; }
    if (k==0) first_name= name;
    
    skip_spaces (s, i);
    if ((i<N(s)) && (s[i]=='s')) {
      i++;
      skip_spaces (s, i);
      while ((i<N(s)) && (s[i]!=' ') && (s[i]!='\t')) i++;
      skip_spaces (s, i);
    }
    if ((i<N(s)) && (s[i]=='c')) {
      i++;
      skip_spaces (s, i);
      j=i;
      while ((i<N(s)) && (s[i]!=' ') && (s[i]!='\t')) i++;
      def= locase_all (s (j, i));
    }
    pmcs(name)= xpm_color(def);
  }
  
  NSImage *im = [[NSImage alloc] initWithSize:NSMakeSize(w,h)];
  //[im setFlipped:YES];
  [im lockFocus];
  [[NSGraphicsContext currentContext] setCompositingOperation: NSCompositeCopy];
  
  // setup pixmap
  for (y=0; y<h; y++) {
    if (N(t)< (y+c+1)) s= "";
    else s= as_string (t[y+c+1]);
    for (x=0; x<w; x++) {
      string name;
      if (N(s)<(b*(x+1))) name= first_name;
      else name= s (b*x, b*(x+1));
      color pmc= pmcs[name];
      if (!pmcs->contains (name)) pmc= pmcs[first_name];
      ns_set_color(pmc);
      [NSBezierPath fillRect:NSMakeRect(x,h-1-y,1,1)];
    }
  }
  [im unlockFocus];
  return im;
}

NSImage *
xpm_image (url file_name)
{
  //ensure_context ();
  NSImage *image = nil;
  ns_image mi = images [as_string(file_name)];
  if (is_nil(mi)) {
    image = xpm_init (file_name);
    int w, h;
    NSSize imgSize = [image size];
    w = imgSize.width; h = imgSize.height;
    ns_image mi2(image,0,0,w,h);
    mi = mi2;
    images (as_string (file_name)) = mi2;
    [image release];
  }
  else image = mi->img;
  return image;
}
#endif

/******************************************************************************
 * main NS renderer
 ******************************************************************************/

ns_renderer_rep*
the_ns_renderer () {
  static ns_renderer_rep* the_renderer = NULL;
  if (!the_renderer) the_renderer= tm_new <ns_renderer_rep> ();
  return the_renderer;
}

/******************************************************************************
 * Shadow management methods
 ******************************************************************************/

/* Shadows are auxiliary renderers which allow double buffering and caching of
 * graphics. TeXmacs has explicit double buffering from the X11 port. Maybe
 * it would be better to design a better API abstracting from the low level
 * details but for the moment the following code and the ns_proxy_renderer_rep
 * is designed to avoid double buffering : when texmacs asks
 * a ns_renderer_rep for a shadow it is given a proxy of the original renderer
 * texmacs uses this shadow for double buffering and the proxy will simply
 * forward the drawing operations to the original surface and neglect all the
 * syncronization operations
 *
 * to solve the second problem we do not draw directly on screen in QTMWidget.
 * Instead we maintain an internal pixmap which represents the state of the pixels
 * according to texmacs. When we are asked to initialize a ns_shadow_renderer_rep
 * we simply read the pixels form this backing store. At the Qt level then
 * (in QTMWidget) we make sure that the state of the backing store is in sync
 * with the screen via paintEvent/repaint mechanism.
 *
 */

class ns_shadow_renderer_rep: public ns_renderer_rep {
public:
  NSBitmapImageRep *px;
  ns_renderer_rep *master;
  
public:
  ns_shadow_renderer_rep (int _w, int _h);
  ~ns_shadow_renderer_rep ();
  
  void get_shadow (renderer ren, SI x1, SI y1, SI x2, SI y2);
};

class ns_proxy_renderer_rep: public ns_renderer_rep {
public:
  ns_renderer_rep *base;
  
public:
  ns_proxy_renderer_rep (ns_renderer_rep *_base, int ww, int hh)
  : ns_renderer_rep (ww, hh), base (_base) { context = base->context; }
  ~ns_proxy_renderer_rep () { };
  
  void new_shadow (renderer& ren);
  void get_shadow (renderer ren, SI x1, SI y1, SI x2, SI y2);
};


void
ns_renderer_rep::new_shadow (renderer& ren) {
  SI mw, mh, sw, sh;
  get_extents (mw, mh);
  if (ren != NULL) {
    ren->get_extents (sw, sh);
    if (sw != mw || sh != mh) {
      delete_shadow (ren);
      ren= NULL;
    } else
      static_cast<ns_renderer_rep*>(ren)->end();
    // cout << "Old: " << sw << ", " << sh << "\n";
  }
  
  if (ren == NULL)  ren= (renderer) tm_new<ns_proxy_renderer_rep> (this, mw, mh);
  
  if (ren) static_cast<ns_renderer_rep*>(ren)->begin(context);
  
  // cout << "Create " << mw << ", " << mh << "\n";
}

void
ns_renderer_rep::delete_shadow (renderer& ren)  {
  return;
  if (ren != NULL) {
    tm_delete (ren);
    ren= NULL;
  }
}

void
ns_renderer_rep::get_shadow (renderer ren, SI x1, SI y1, SI x2, SI y2) {
  // FIXME: we should use the routine fetch later
  ASSERT (ren != NULL, "invalid renderer");
  if (ren->is_printer ()) return;
  ns_renderer_rep* shadow= static_cast<ns_renderer_rep*>(ren);
  outer_round (x1, y1, x2, y2);
  x1= max (x1, cx1- ox);
  y1= max (y1, cy1- oy);
  x2= min (x2, cx2- ox);
  y2= min (y2, cy2- oy);
  shadow->ox= ox;
  shadow->oy= oy;
  shadow->master= this;
  shadow->cx1= x1+ ox;
  shadow->cy1= y1+ oy;
  shadow->cx2= x2+ ox;
  shadow->cy2= y2+ oy;
  
  decode (x1, y1);
  decode (x2, y2);
  if (x1<x2 && y2<y1) {
    NSRect rect = NSMakeRect(x1, y2, x2-x1, y1-y2);
    //    shadow->painter->setCompositionMode(QPainter::CompositionMode_Source);
    NSGraphicsContext *old_context = [[NSGraphicsContext currentContext] retain];
    [NSGraphicsContext setCurrentContext:context];
    NSBezierPath* clipPath = [NSBezierPath bezierPath];
    [clipPath appendBezierPathWithRect: rect];
    [clipPath setClip];
    [NSGraphicsContext setCurrentContext:old_context]; [old_context release];
    //    shadow->painter->drawPixmap (rect, px, rect);
    //    cout << "ns_shadow_renderer_rep::get_shadow "
    //         << rectangle(x1,y2,x2,y1) << LF;
    //  XCopyArea (dpy, win, shadow->win, gc, x1, y2, x2-x1, y1-y2, x1, y2);
  } else {
    //        shadow->painter->setClipRect(QRect());
  }
}

void
ns_renderer_rep::put_shadow (renderer ren, SI x1, SI y1, SI x2, SI y2) {
  // FIXME: we should use the routine fetch later
  ASSERT (ren != NULL, "invalid renderer");
  if (ren->is_printer ()) return;
  if (context == static_cast<ns_renderer_rep*>(ren)->context) return;
  ns_shadow_renderer_rep* shadow= static_cast<ns_shadow_renderer_rep*>(ren);
  outer_round (x1, y1, x2, y2);
  x1= max (x1, cx1- ox);
  y1= max (y1, cy1- oy);
  x2= min (x2, cx2- ox);
  y2= min (y2, cy2- oy);
  decode (x1, y1);
  decode (x2, y2);
  if (x1<x2 && y2<y1) {
    NSRect rect = NSMakeRect(x1, y2, x2-x1, y1-y2);
    //    cout << "ns_shadow_renderer_rep::put_shadow "
    //         << rectangle(x1,y2,x2,y1) << LF;
    //    painter->setCompositionMode(QPainter::CompositionMode_Source);
    NSGraphicsContext *old_context = [[NSGraphicsContext currentContext] retain];
    [NSGraphicsContext setCurrentContext:context];
    [shadow->px drawInRect: rect];
    [NSGraphicsContext setCurrentContext:old_context]; [old_context release];
    //        painter->drawPixmap (rect, shadow->px, rect);
    //  XCopyArea (dpy, shadow->win, win, gc, x1, y2, x2-x1, y1-y2, x1, y2);
  }
}


void
ns_renderer_rep::apply_shadow (SI x1, SI y1, SI x2, SI y2)  {
  if (master == NULL) return;
  if (context == static_cast<ns_renderer_rep*>(master)->context) return;
  outer_round (x1, y1, x2, y2);
  decode (x1, y1);
  decode (x2, y2);
  static_cast<ns_renderer_rep*>(master)->encode (x1, y1);
  static_cast<ns_renderer_rep*>(master)->encode (x2, y2);
  master->put_shadow (this, x1, y1, x2, y2);
}


/******************************************************************************
 * proxy qt renderer
 ******************************************************************************/

void
ns_proxy_renderer_rep::new_shadow (renderer& ren) {
  SI mw, mh, sw, sh;
  get_extents (mw, mh);
  if (ren != NULL) {
    ren->get_extents (sw, sh);
    if (sw != mw || sh != mh) {
      delete_shadow (ren);
      ren= NULL;
    }
    else
      static_cast<ns_renderer_rep*>(ren)->end();
    // cout << "Old: " << sw << ", " << sh << "\n";
  }
  if (ren == NULL) {
    //        NSBitmapImageRep *img = [[NSBitmapImageRep alloc] init];
    //        ren= (renderer) tm_new<ns_shadow_renderer_rep> (QPixmap (mw, mh));
    ren= (renderer) tm_new<ns_shadow_renderer_rep> (mw, mh);
  }
  
  // cout << "Create " << mw << ", " << mh << "\n";
  static_cast<ns_renderer_rep*>(ren)->begin(context);
}

void
ns_proxy_renderer_rep::get_shadow (renderer ren, SI x1, SI y1, SI x2, SI y2) {
  // FIXME: we should use the routine fetch later
  ASSERT (ren != NULL, "invalid renderer");
  if (ren->is_printer ()) return;
  ns_renderer_rep* shadow= static_cast<ns_renderer_rep*>(ren);
  outer_round (x1, y1, x2, y2);
  x1= max (x1, cx1- ox);
  y1= max (y1, cy1- oy);
  x2= min (x2, cx2- ox);
  y2= min (y2, cy2- oy);
  shadow->ox= ox;
  shadow->oy= oy;
  shadow->cx1= x1+ ox;
  shadow->cy1= y1+ oy;
  shadow->cx2= x2+ ox;
  shadow->cy2= y2+ oy;
  shadow->master= this;
  decode (x1, y1);
  decode (x2, y2);
  
  NSGraphicsContext *old_context = [[NSGraphicsContext currentContext] retain];
  [NSGraphicsContext setCurrentContext:shadow->context];
  if (x1<x2 && y2<y1) {
    NSRect rect = NSMakeRect(x1, y2, x2-x1, y1-y2);
    
    
    NSBezierPath* clipPath = [NSBezierPath bezierPath];
    [clipPath appendBezierPathWithRect: rect];
    [clipPath setClip];
    
    
    //        shadow->painter->setClipRect(rect);
    
    //    shadow->painter->setCompositionMode(QPainter::CompositionMode_Source);
    NSBitmapImageRep *img = [base->view bitmapImageRepForCachingDisplayInRect:rect];
    //        QPixmap *_pixmap = static_cast<QPixmap*>(painter->device());
    if (img) {
      [img drawInRect:rect];
      //            shadow->painter->drawPixmap (rect, *_pixmap, rect);
    }
    //    cout << "ns_shadow_renderer_rep::get_shadow "
    //         << rectangle(x1,y2,x2,y1) << LF;
    //  XCopyArea (dpy, win, shadow->win, gc, x1, y2, x2-x1, y1-y2, x1, y2);
    
  } else {
    //shadow->painter->setClipRect(QRect());
  }
  [NSGraphicsContext setCurrentContext:old_context]; [old_context release];
  
}


/******************************************************************************
 * shadow qt renderer
 ******************************************************************************/

ns_shadow_renderer_rep::ns_shadow_renderer_rep (int _w, int _h)
// : ns_renderer_rep (_px.width(),_px.height()), px(_px)
: ns_renderer_rep (_w, _h), px(nil)
{
  px = [[NSBitmapImageRep alloc] init];
  [px setSize: NSMakeSize(w,h)];
  context = [[NSGraphicsContext graphicsContextWithBitmapImageRep: px] retain];
  //cout << px.width() << "," << px.height() << " " << LF;
  // painter->begin(&px);
}

ns_shadow_renderer_rep::~ns_shadow_renderer_rep ()
{
  [px release];
  [context release];
  context  = nil;
}

void
ns_shadow_renderer_rep::get_shadow (renderer ren, SI x1, SI y1, SI x2, SI y2) {
  // FIXME: we should use the routine fetch later
  ASSERT (ren != NULL, "invalid renderer");
  if (ren->is_printer ()) return;
  ns_shadow_renderer_rep* shadow= static_cast<ns_shadow_renderer_rep*>(ren);
  outer_round (x1, y1, x2, y2);
  x1= max (x1, cx1- ox);
  y1= max (y1, cy1- oy);
  x2= min (x2, cx2- ox);
  y2= min (y2, cy2- oy);
  shadow->ox= ox;
  shadow->oy= oy;
  shadow->cx1= x1+ ox;
  shadow->cy1= y1+ oy;
  shadow->cx2= x2+ ox;
  shadow->cy2= y2+ oy;
  shadow->master= this;
  decode (x1, y1);
  decode (x2, y2);
  NSGraphicsContext *old_context = [[NSGraphicsContext currentContext] retain];
  [NSGraphicsContext setCurrentContext:shadow->context];
  if (x1<x2 && y2<y1) {
    NSRect rect = NSMakeRect(x1, y2, x2-x1, y1-y2);
    
    NSBezierPath* clipPath = [NSBezierPath bezierPath];
    [clipPath appendBezierPathWithRect: rect];
    [clipPath setClip];
    
    //        shadow->painter->setClipRect(rect);
    [px drawInRect:rect];
    
    //    shadow->painter->setCompositionMode(QPainter::CompositionMode_Source);
    //        shadow->painter->drawPixmap (rect, px, rect);
    //    cout << "ns_shadow_renderer_rep::get_shadow "
    //         << rectangle(x1,y2,x2,y1) << LF;
    //  XCopyArea (dpy, win, shadow->win, gc, x1, y2, x2-x1, y1-y2, x1, y2);
  } else {
    //      shadow->painter->setClipRect(QRect());
  }
  [NSGraphicsContext setCurrentContext:old_context]; [old_context release];
  
}
