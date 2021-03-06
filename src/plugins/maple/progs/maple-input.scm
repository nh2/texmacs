
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : maple-input.scm
;; DESCRIPTION : Maple input converters
;; COPYRIGHT   : (C) 1999  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (maple-input)
  (:use (utils plugins plugin-convert)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Specific conversion routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (maple-input-var-row r)
  (if (nnull? r)
      (begin
	(display ", ")
	(plugin-input (car r))
	(maple-input-var-row (cdr r)))))

(define (maple-input-row r)
  (display "[")
  (plugin-input (car r))
  (maple-input-var-row (cdr r))
  (display "]"))

(define (maple-input-var-rows t)
  (if (nnull? t)
      (begin
	(display ", ")
	(maple-input-row (car t))
	(maple-input-var-rows (cdr t)))))

(define (maple-input-rows t)
  (display "matrix([")
  (maple-input-row (car t))
  (maple-input-var-rows (cdr t))
  (display "])"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(plugin-input-converters maple
  (rows maple-input-rows))
