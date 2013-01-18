;+
; NAME:
;    circletransform
;
; PURPOSE:
;    Performs a transform similar to a Hough transform
;    for detecting circular features in an image.
;
; CATEGORY:
;    Image analysis, feature detection
;
; CALLING SEQUENCE:
;    b = circletransform(a)
;
; INPUTS:
;    a: [nx,ny] image data
;
; KEYWORD PARAMETERS:
;    noise: estimate for additive pixel noise.
;        Default: noise estimated by MAD().C;
;    deinterlace: if set to an odd number, then only perform
;        transform on odd field of an interlaced image.
;        If set to an even number, transform even field.
;
; OUTPUTS:
;    b: [nx,ny] circle transform.  Peaks correspond to estimated
;        centers of circular features in a.
;
; KEYWORD OUTPUTS:
;    range: mean range used in tallying votes.
;
; PROCEDURE:
;    Compute the gradient of the image.  The local gradient at each
;    pixel defines a line along which the center of a circle may
;    lie.  Cast votes for pixels along the line in the transformed
;    image.  The pixels in the transformed image with the most votes
;    correspond to the centers of circular features in the original
;    image.
;
; REFERENCE:
; F. C. Cheong, B. Sun, R. Dreyfus, J. Amato-Grill, K. Xiao, L. Dixon
; & D. G. Grier,
; Flow visualization and flow cytometry with holographic video
; microscopy, Optics Express 17, 13071-13079 (2009)
;
; EXAMPLE:
;    IDL> b = circletransform(a)
;
; MODIFICATION HISTORY:
; 10/07/2008 Written by David G. Grier, New York University.
; 01/26/2009 DGG Added DEINTERLACE keyword. Gracefully handle
;    case when original image has no features. Documentation cleanups.
; 02/03/2009 DGG Replaced THRESHOLD keyword with NOISE.
; 06/10/2010 DGG Documentation fixes.  Added COMPILE_OPT.
; 05/02/2012 DGG Updated keyword parsing.  Formatting.
; 06/24/2012 DGG Streamlined index range checking in inner loop
;    to improve efficiency.
; 07/16/2012 DGG IMPORTANT: Center results on pixels, not on vertices!
;    Use array_indices for clarity.
; 11/10/2012 DGG Default range should be an integer.
;    Returned array should be cast to integer, not float
; 11/23/2012 DGG Use Savitzky-Golay estimate for derivative.
;    Eliminate SMOOTHFACTOR parameter.  Upgrade parameter checking.
; 11/25/2012 DGG Limit search range by uncertainty in gradient
;    direction.  Remove RANGE keyword.
; 11/30/2012 DGG Optionally return mean range as RANGE keyword.
; 01/16/2013 DGG estimate noise with MAD() by default.
;
; Copyright (c) 2008-2013 David G. Grier
;
;-

function circletransform, a_, $
                          noise = noise, $
                          range = range, $
                          deinterlace = deinterlace

COMPILE_OPT IDL2

umsg = 'USAGE: b = circletransform(a)'

if ~isa(a_, /number, /array) then begin
   message, umsg, /inf
   return, -1
endif
if size(a_, /n_dimensions) ne 2 then begin
   message, umsg, /inf
   message, 'A must be a two-dimensional numeric array', /inf
   return, -1
endif

sz = size(a_, /dimensions)
nx = sz[0]
ny = sz[1]

if ~isa(range, /scalar, /number) then range = 100

dodeinterlace = isa(deinterlace, /scalar, /number)
if dodeinterlace then begin
   n0 = deinterlace mod 2
   a = float(a_[*, n0:*:2])
endif else $
   a = float(a_)

if ~isa(noise, /scalar, /number) then $
   noise = mad(a)

; Third-order two-dimensional Savitzky-Golay filter over 5x5 image patch
dx = [[ 0.0738, -0.1048,  0.0000,  0.1048, -0.0738], $
      [-0.0119, -0.1476,  0.0000,  0.1476,  0.0119], $
      [-0.0405, -0.1619,  0.0000,  0.1619,  0.0405], $
      [-0.0119, -0.1476,  0.0000,  0.1476,  0.0119], $
      [ 0.0738, -0.1048,  0.0000,  0.1048, -0.0738]]
dadx = convol(a, dx, /center, /edge_truncate)
dady = convol(a, transpose(dx), /center, /edge_truncate)
if dodeinterlace then dady /= 2.
grada = sqrt(dadx^2 + dady^2)           ; magnitude of the gradient
dgrada = noise * sqrt(2. * total(dx^2)) ; error in gradient magnitude due to noise
w = where(grada gt 2.*dgrada, npts)     ; only consider votes with small angular uncertainty

b = intarr(nx, ny)              ; accumulator array for the result

if npts le 0 then return, b

xy = array_indices(grada, w)    ; coordinates of pixels with strong gradients
if dodeinterlace then xy[1,*] = 2.*xy[1,*] + n0
xy += 1.                        ; to center on pixels

grada = grada[w]                ; gradient direction at each pixel
costheta = dadx[w] / grada
sintheta = dady[w] / grada

rng = round(2./tan(dgrada/grada/2.)) ; range over which to cast votes (4 pixel error)
range = max(rng)
r = findgen(2.*range + 1.) - range

for i = 0L, npts-1L do begin 
   n0 = range - rng[i]
   n1 = range + rng[i]
   x = round(xy[0,i] + r[n0:n1] * costheta[i]) > 0 < nx-1
   y = round(xy[1,i] + r[n0:n1] * sintheta[i]) > 0 < ny-1
   b[x, y] += 1 
endfor

range = mean(rng)

return, b
end
