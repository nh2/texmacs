
/******************************************************************************
* MODULE     : grammar.cpp
* DESCRIPTION: packrat parsing
* COPYRIGHT  : (C) 2009  Francis Jamet, Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#include "grammar.hpp"
#include "analyze.hpp"
#include "impl_language.hpp"
#include "Scheme/object.hpp"

parser_rep::parser_rep(hashmap<tree,tree> g, string s) { grammar=g; xstring=s;}

parser::parser (hashmap<tree,tree> g, string s) { 
  rep= tm_new<parser_rep> (g, s);
}

int
parser_rep::parse (tree parsing_tree, int pos) {
  if (pos >= N(xstring)) return -1;
  pair<tree,int> p(parsing_tree,pos);
  if (evaluated_pair->contains(p)) return evaluated_pair(p);
  if (wanted_pair->contains(p)) return -1;
  if ( L(parsing_tree)==as_tree_label("DOLLAR")) {
    if (! grammar->contains(parsing_tree)) return pos;
    tree regle;
    regle= grammar(parsing_tree);
    int opos=pos;
    p= pair<tree,int> (parsing_tree, opos);
    wanted_pair(p)= true;
    pos= parse(regle, pos);
    cout<<parsing_tree<<" "<<opos<<" "<<pos<<"\n";  //effacer wanted_pair apres
    evaluated_pair(p)= pos;
    wanted_pair->reset(p);
    return pos;
  }
  if (L(parsing_tree)==as_tree_label("OR") && N(parsing_tree)>=1) {    // or
    tree parsing_tree2;
    int i=0;
    int init_pos= pos;
    int opos;
    p= pair<tree, int> (parsing_tree, init_pos);
    wanted_pair(p)= true;
    do {
      parsing_tree2= parsing_tree[i];
      opos=pos;
      pos= parse(parsing_tree2, pos);
      i++;
    } while (opos==pos && i<N(parsing_tree));
    cout<<parsing_tree<<" "<<init_pos<<" "<<pos<<"\n";
    evaluated_pair(p)= pos;
    wanted_pair->reset(p);
    return pos;
  }
  if (L(parsing_tree)==as_tree_label("CONCAT") && N(parsing_tree)>=1) { 
    tree parsing_tree2;
    int i=0;
    int init_pos= pos;
    int opos;
    p= pair<tree, int> (parsing_tree, init_pos);
    wanted_pair(p)= true;
    do {
      parsing_tree2= parsing_tree[i];
      opos=pos;
      pos=parse(parsing_tree2, pos);
      i++;
    } while (opos<pos && i<N(parsing_tree));
    if (opos==pos) pos= init_pos;
    cout<<parsing_tree<<" "<<init_pos<<" "<<pos<<"\n";
    evaluated_pair(p)= pos;
    wanted_pair->reset(p);
    return pos;
  }
  if (L(parsing_tree)==as_tree_label("STAR") && N(parsing_tree)==1) {
    tree parsing_tree1;
    parsing_tree1= parsing_tree[0];
    int init_pos= pos;
    int opos;
    p= pair<tree, int> (parsing_tree, init_pos);    
    wanted_pair(p)= true;
    do {
      opos= pos;
      pos= parse(parsing_tree1, pos);
    } while (opos<pos && pos<N(xstring));
    cout<<parsing_tree<<" "<<init_pos<<" "<<pos<<"\n";
    evaluated_pair(p)= pos;
    wanted_pair->reset(p);
    return pos;
  }
  if (L(parsing_tree)==as_tree_label("RANGE") && N(parsing_tree)==2) {
    string s1,s2;
    s1= parsing_tree[0]->label;
    s2= parsing_tree[1]->label;
    int opos= pos;
    if (s1 <= xstring(pos,pos+1)
	&& xstring(pos,pos+1) <=s2) pos++;
    p= pair<tree, int> (parsing_tree, opos);
    cout<<parsing_tree<<" "<<opos<<" "<<pos<<"\n";
    evaluated_pair(p)= pos;
    wanted_pair->reset(p);
    return pos;
  }
  if (is_atomic(parsing_tree)) {
    string s;
    s= parsing_tree->label;
    int opos= pos;
    if (s == xstring(pos,pos+1)) pos++;
    p= pair<tree, int> (parsing_tree, opos);
    cout<<parsing_tree<<" "<<opos<<" "<<pos<<"\n";
    evaluated_pair(p)= pos;
    return pos;
  }
  return pos;
}

static hashmap<tree,tree>* global_grammar= NULL;

void
define_grammar_rule (tree var, tree gram) {
  if (global_grammar == NULL) global_grammar= new hashmap<tree,tree> ();
  (*global_grammar) (var)= gram;
}

int
grammar_parse (tree var, string s) {
  if (global_grammar == NULL) global_grammar= new hashmap<tree,tree> ();
  parser p (*global_grammar, s);
  return p->parse (var, 0);
}
