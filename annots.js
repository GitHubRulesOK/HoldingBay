"use strict";
/*
Usage:
  mutool run annots.js [-m=MODE] [-#] [-a=Subtype[,S..,S..] [-b] [-v] [-d] [-e] [-f] [-n]
                       [-o="FILE"] [-p=r,a,n-g,e] [-q] [-r="FILE"] [-t | -t="Text"] input.pdf

See defaults below for use of switches.
*/

// --- Argument settings --- -m=mode and -a=annotSubtypes are tested as toLowerCase  but not "fuzzy"
var mode = "report"; var maxCount = false; var annotSubtypes = null; var blockMode = false; var verbose = false; var Debug = false;
var decomSave = false; var flateSave = false; var noSave = false; var outname = null; var pageSpec = null; var pageMap = null;
var quieter = false; var reportFile = null; var pokeText = null; var inname = null; var pdfDirty = false; var totalMatches = 0;
for (var i = 0; i < scriptArgs.length; i++) {
  var arg = scriptArgs[i];
  if (arg.indexOf("-m=") === 0) mode = arg.slice(3).toLowerCase();
  else if (arg === "-#") maxCount = true;
  else if (arg.indexOf("-a=") === 0) {
    var raw = arg.slice(3).trim();
    if (raw === "") {
        annotSubtypes = null;
    } else {
        annotSubtypes = raw.split(",");
        for (var j = 0; j < annotSubtypes.length; j++) {
            annotSubtypes[j] = annotSubtypes[j].replace(/^\//, "").toLowerCase();
        }
    }
  }
  else if (arg === "-b") blockMode = true;
  else if (arg === "-v") verbose = true;
// -c only used by addAnot.js
  else if (arg === "-d") Debug = true;
  else if (arg === "-e") decomSave = true;
  else if (arg === "-f") flateSave = true;
// -i only used by addAnot.js
  else if (arg === "-n") noSave = true;
  else if (arg.indexOf("-o=") === 0) outname = arg.slice(3);
  else if (arg.indexOf("-p=") === 0) pageSpec = arg.slice(3);
  else if (arg === "-q") quieter = true;
  else if (arg.indexOf("-r=") === 0) reportFile = arg.slice(3);
// -s only used by addAnot.js
  else if (arg === "-t") pokeText = true;
  else if (arg.indexOf("-t=") === 0) pokeText = arg.slice(3);
  else if (arg[0] !== "-") inname = arg;
}
if (!inname) { print(" Usage: mutool run annots.js [-m=MODE] [-#] [-a=Subtype[,S..,S..] [-b] [-v] [-d] [-e] [-f] [-n]\n" +
"                             [-o=\"FILE\"] [-p=r,a,n-g,e] [-q] [-r=\"FILE\"] [-t | -t=\"text\"]  input.pdf\n" +
" Modes:\n" +
"   -m=         MODE =Report (Default) or =TextUnder also shows underlying page text (case insensitive)\n" +
"   -m=         MODE =DelAnnots | =DelLinks (case insensitive) Removes -a=Subtype,S on page(ranges) \n" +
"   -#          N/A (count still to be defined)\n" +
"   -a=         subType filters (e.g. Highlight,StrikeOut,Link) no /Slash. Report Default =All in page(s)\n" +
"   -b          use block mode for report and/or console output (single lines for grepping)\n" +
"   -v          more verbose/extra outputs, use with caution on large files (limit page range)\n" +
" Flags:\n" +
"   -d          show debug flow at console\n" +
"   -e          save expanded objects in PDF outputs (images and fonts will be compacted)\n" +
"   -f          save flated objects in PDF outputs (images and fonts will be compacted)\n" +
"   -n          no-save (don't save cleaned PDF nor a list TXT)\n" +
"   -o=\"FILE\"   output PDF (default: input-changed.pdf)\n" +
"   -p=\"LIST\"   Process Pages Range (Report Default without -p: All)\n" +
"   -q          quieter (reduce console output except errors)\n" +
"   -r=\"FILE\"   write report to TXT (Default: input-list.txt)\n" +
"   -t          embed underlying Text string into annotation\n" +
"   -t=\"text\"   embed a custom text as the comment (annots may not support all UTF characters)\n" +
"\n" +
"  * Notes: -# and -t=\"text\" are still work in progress \n"
); quit(); }
/* ---------------
     LOAD PDF
----------------*/
var doc = mupdf.PDFDocument(inname); if (!doc.isPDF()) throw new Error("Not a PDF");
if (doc.needsPassword()) throw new Error("Encrypted PDF"); var pageCount = doc.countPages();
// PDF active NOW we can collect results
var txtOut = new Buffer();
var defaultReportFile = inname.replace(/\.pdf$/i, "") + "-list.txt";
if (mode === "delannots" || mode === "dellinks") defaultReportFile = inname.replace(/\.pdf$/i, "") + "-changed.txt";
var defaultOutPdf = inname.replace(/\.pdf$/i, "") + "-changed.pdf";
/* ---------------
 Page selection
----------------*/
// If user gave no -p=, default to "1-total"
if (!pageSpec) pageSpec = "1-" + pageCount;
// parsePageS is a later function, thus as "hoisted" is available
var pageMap = parsePageS(pageSpec, pageCount);
var pageString = Object.keys(pageMap).join(",");
/* ---------------
 Debug start args 
----------------*/
if (Debug) {
    print("DEBUG: inname = " + inname +
          ", mode = " + mode +
          ", pageCount = " + pageCount +
          ", pageSpec = " + pageSpec +
          "\n , pageMap = " + pageString +
          "\n , defaultReportFile = " + defaultReportFile);
}
/* ---------------
 Helper functions
----------------*/
var csvEsc = function(s){ return '"' + String(s||'').replace(/"/g,'""') + '"'; };
var padL = function(s,w){ s=(s===null?"null":String(s)); while(s.length<w) s=" "+s; return s; };
var padR = function(s,w){ s=(s===null?"null":String(s)); while(s.length<w) s+=" "; return s; };
var safeString = function(v){ return (v === null || v === undefined) ? "null" : ("" + v); };
var classifyLiteral = function(raw){
    var lit = String(raw || '');
    var first = lit.replace(/^\s+/, '').charAt(0);

    if (first === '<') {
        // Inline hexTXTtoUTF
        var hex = lit.replace(/^[\s<]+|[\s>]+$/g, '')
                     .replace(/\s+/g, '')
                     .toUpperCase();
        if (hex.slice(0,4) === 'FEFF')
            hex = hex.slice(4);

        var H = '0123456789ABCDEF';
        var bytes = [];
        for (var i = 0; i < hex.length; i += 2) {
            var hi = H.indexOf(hex.charAt(i));     if (hi < 0) hi = 0;
            var lo = H.indexOf(hex.charAt(i+1));   if (lo < 0) lo = 0;
            bytes.push(((hi << 4) | lo) & 0xFF);
        }

        var utf16 = '';
        for (var j = 0; j + 1 < bytes.length; j += 2)
            utf16 += String.fromCharCode((bytes[j] << 8) | bytes[j+1]);
        utf16 = utf16.replace(/^\uFEFF+/, '');

        var low = '';
        for (var j2 = 0; j2 + 1 < bytes.length; j2 += 2)
            low += String.fromCharCode(bytes[j2+1]);

        if (utf16 && utf16.length)
            return { type:'HEX_UTF16', decoded:utf16, hex:hex, low:low };

        if (low && low.length)
            return { type:'ANSI_LOWBYTE', decoded:low, hex:hex, low:low };

        return { type:'OTHER_HEX', decoded:hex, hex:hex };
    }

    // Inline unescapePdfString
    var s = lit;
    var out = '';
    for (var i3 = 0; i3 < s.length; i3++) {
        var ch = s.charAt(i3);
        if (ch.charCodeAt(0) !== 92) { // '\'
            out += ch;
            continue;
        }
        i3++;
        if (i3 >= s.length) {
            out += String.fromCharCode(92);
            break;
        }
        var esc = s.charAt(i3);
        var ec = esc.charCodeAt(0);

        if (ec === 110) { out += "\n"; continue; } // n
        if (ec === 114) { out += "\r"; continue; } // r
        if (ec === 116) { out += "\t"; continue; } // t
        if (ec === 98)  { out += "\b"; continue; } // b
        if (ec === 102) { out += "\f"; continue; } // f
        if (ec === 40)  { out += "(";  continue; }
        if (ec === 41)  { out += ")";  continue; }
        if (ec === 92)  { out += "\\"; continue; }

        if (ec >= 48 && ec <= 55) {
            var oct = esc;
            for (var k = 0; k < 2; k++) {
                if (i3 + 1 < s.length) {
                    var nx = s.charAt(i3 + 1);
                    var nc = nx.charCodeAt(0);
                    if (nc >= 48 && nc <= 55) {
                        i3++;
                        oct += nx;
                        continue;
                    }
                }
                break;
            }
            var code = 0;
            for (var m = 0; m < oct.length; m++)
                code = (code << 3) + (oct.charCodeAt(m) - 48);
            out += String.fromCharCode(code & 0xFF);
            continue;
        }

        out += esc;
    }

    var plain = out;
    var isAscii = true;
    for (var i4 = 0; i4 < plain.length; i4++) {
        var c = plain.charCodeAt(i4);
        if (c === 0 || c < 9) { isAscii = false; break; }
    }

    return { type: isAscii ? 'PLAIN_ASCII' : 'UNKNOWN', decoded: plain };
};


/* ---------------
 Parse page-range
  Left-to-right:
- ranges add pages
- odd/even current set
- add single number
- "end" = maxPages
----------------*/
function parsePageS(spec, maxPages) {
    var map = {};
    if (!spec) {
        // default: all pages
        for (var p = 1; p <= maxPages; p++) map[p] = true;
        return map;
    }
    var parts = String(spec).split(",");
    // working set as a map
    var current = {};
    for (var i = 0; i < parts.length; i++) {
        var part = parts[i].trim();
        if (!part) continue;
        var low = part.toLowerCase();
        // odd / even refine current set if non-empty, otherwise global
        if (low === "odd" || low === "even") {
            var wantOdd = (low === "odd");
            // if current is empty, start from full range
            var base = current;
            var hasAny = false;
            for (var k in base) { hasAny = true; break; }
            if (!hasAny) {
                base = {};
                for (var p2 = 1; p2 <= maxPages; p2++) base[p2] = true;
            }
            var refined = {};
            for (var k2 in base) {
                var n = k2|0;
                if (n<1 || n>maxPages) continue;
                if (wantOdd && (n % 2 === 1)) refined[n] = true;
                if (!wantOdd && (n % 2 === 0)) refined[n] = true;
            }
            current = refined;
            continue;
        }
        // range or single
        var dash = part.indexOf("-");
        if (dash > 0) {
            var aStr = part.slice(0, dash).trim();
            var bStr = part.slice(dash + 1).trim().toLowerCase();
            var a = parseInt(aStr, 10);
            var b;
            if (bStr === "end") {
                b = maxPages;
            } else {
                b = parseInt(bStr, 10);
                if (isNaN(b)) b = maxPages;
            }
            if (isNaN(a)) continue;
            if (a > b) { var t=a; a=b; b=t; }
            for (var p = a; p <= b; p++) {
                if (p>=1 && p<=maxPages) current[p] = true;
            }
        } else {
            var n = parseInt(part, 10);
            if (!isNaN(n) && n>=1 && n<=maxPages) current[n] = true;
        }
    }
    // if nothing selected, default to all
    var has = false;
    for (var k3 in current) { has = true; break; }
    if (!has) {
        for (var p3 = 1; p3 <= maxPages; p3++) current[p3] = true;
    }
    return current;
}

/* ---------------
   Page walker
----------------*/
function forEachPage(doc, pageMap, fn) {
    for (var p = 1; p <= pageCount; p++) {
        if (!pageMap[p]) continue;

        var page = null;
        try { page = doc.loadPage(p - 1); }
        catch(e) { continue; }

        if (!page) continue;

        fn(page, p - 1); // p-1 = zero-based index

        if (page.free) page.free();
    }
}
/* ---------------
 Annotation walker
----------------*/
function forEachAnnot(page, fn) {
    var ann = null;
    try { ann = page.getAnnotations(); } catch(e) { return; }
    if (!ann || !ann.length) return;
    for (var i = ann.length - 1; i >= 0; i--) { fn(ann[i], i); }
}
/* ---------------
  Subtype filters
----------------*/
function subtypeMatches(obj, filters) {
    if (!filters) return false;   // no -a → delete nothing
    var st = obj.get("Subtype");
    if (!st) return false;
    st = String(st).replace(/^\//, "").toLowerCase();
    // wildcard = match all
    if (filters.indexOf("*") !== -1 || filters.indexOf("all") !== -1) return true;
    for (var i = 0; i < filters.length; i++) {
        if (st === filters[i]) return true;
    }
    return false;
}
/* ---------------
 TextUnder helpers
Returns: { text: "merged\ntext",
           rect: [x0, y0, x1, y1] }
--------------- */
function extractTextFromQuads(page, quads) {
    var sText = page.toStructuredText("preserve-whitespace,words");
    var H = page.getBounds()[3];
    var parts = [];

    for (var q = 0; q < quads.length; q += 8) {
        var x0 = quads[q+0], y0 = H - quads[q+1];
        var x1 = quads[q+2], y1 = H - quads[q+3];
        var x2 = quads[q+4], y2 = H - quads[q+5];
        var x3 = quads[q+6], y3 = H - quads[q+7];

        var left   = Math.min(x0, x1, x2, x3);
        var right  = Math.max(x0, x1, x2, x3);
        var top    = Math.min(y0, y1, y2, y3);
        var bottom = Math.max(y0, y1, y2, y3);

        var text = "";
        sText.walk({
            onChar: function(c, origin) {
                var ox = origin[0], oy = origin[1];
                if (ox >= left && ox <= right && oy >= top && oy <= bottom)
                    text += c;
            }
        });

        parts.push(text);
    }

    var merged = parts.join("\n");
    return merged.length ? merged : null;
}
function extractTextFromRect(page, rect) {
    if (!rect || rect.length < 4) return null;

    var H = page.getBounds()[3];

    // Convert PDF user-space rect → MuPDF device-space rect
    var left   = rect[0];
    var right  = rect[2];
    var top    = H - rect[3];
    var bottom = H - rect[1];

    var sText = page.toStructuredText("preserve-whitespace,words");

    // Use the selection engine (glyph bounding boxes)
    var txt = sText.copy([left, top], [right, bottom]);

    return txt && txt.trim().length ? txt : null;
}


function getQuadPoints(dict) {
    var qp = null;
    try { qp = dict.get("QuadPoints"); } catch(e) {}
    if (!qp) return null;

    var out = [];
    for (var i = 0; i < qp.length; i++)
        out.push(qp.get(i));

    return out.length >= 8 ? out : null;
}

function extractTextUnder(page, annotObj) {
if (Debug) print ("DEBUG: entered extractTextUnder");
    var sText = page.toStructuredText("preserve-whitespace,words");
    var H = page.getBounds()[3];
    var dict = annotObj.getObject();
    var qp = null;
    try { qp = dict.get("QuadPoints"); } catch (e) {}
    if (!qp) {
        var r = dict.get("Rect");
        if (!r)
            return { text: "", rect: annotObj.getRect() };
        qp = [
            r.get(0), r.get(3),
            r.get(2), r.get(3),
            r.get(0), r.get(1),
            r.get(2), r.get(1)
        ];
    } else {
        var tmp = [];
        for (var i = 0; i < qp.length; i++)
            tmp.push(qp.get(i));
        qp = tmp;
    }
    var quads = qp;
    var parts = [];
    var minX = null, minY = null, maxX = null, maxY = null;
    for (var q = 0; q < quads.length; q += 8) {
        var x0 = quads[q+0], y0 = H - quads[q+1];
        var x1 = quads[q+2], y1 = H - quads[q+3];
        var x2 = quads[q+4], y2 = H - quads[q+5];
        var x3 = quads[q+6], y3 = H - quads[q+7];
        var left   = Math.min(x0, x1, x2, x3);
        var right  = Math.max(x0, x1, x2, x3);
        var top    = Math.min(y0, y1, y2, y3);
        var bottom = Math.max(y0, y1, y2, y3);
        if (minX === null) {
            minX = left;  maxX = right;
            minY = top;   maxY = bottom;
        } else {
            minX = Math.min(minX, left);
            maxX = Math.max(maxX, right);
            minY = Math.min(minY, top);
            maxY = Math.max(maxY, bottom);
        }
        var textract = "";
        sText.walk({
            onChar: function(c, origin) {
                var ox = origin[0], oy = origin[1];
                if (ox >= left && ox <= right && oy >= top && oy <= bottom)
                    textract += c;
            }
        });
        parts.push(textract);
    }
if (Debug) print ("DEBUG: leaving extractTextUnder");
    return {
        text: parts.join("\n"),
        rect: [ minX, minY, maxX, maxY ]
    };
}


function printVerboseTextUnder(page, pg, j, annotObj, mergedText) {
if (Debug) print ("DEBUG: entered printVerboseTextUnder");
    var sText = page.toStructuredText("preserve-whitespace,words");
    var H = page.getBounds()[3];
    var dict = annotObj.getObject();
var qp = dict.get("QuadPoints");
if (!qp) {
    // No quads → print a single empty rect and the merged text
    var quadRect = "[]";
    var line = [
        padL(pg+1,4),
        padL(j+1,4),
        padL(1,3),
        padR(quadRect,44),
        csvEsc(mergedText)
    ].join(',');
    if (!quieter) print(line);
    txtOut.write(line + "\n");
    return;
}
    var quads = [];
    for (var i = 0; i < qp.length; i++)
        quads.push(qp.get(i));
    for (var q = 0; q < quads.length; q += 8) {
        var x0 = quads[q+0], y0 = H - quads[q+1];
        var x1 = quads[q+2], y1 = H - quads[q+3];
        var x2 = quads[q+4], y2 = H - quads[q+5];
        var x3 = quads[q+6], y3 = H - quads[q+7];
        var left   = Math.min(x0, x1, x2, x3);
        var right  = Math.max(x0, x1, x2, x3);
        var top    = Math.min(y0, y1, y2, y3);
        var bottom = Math.max(y0, y1, y2, y3);
        var textract = "";
        sText.walk({
            onChar: function(c, origin) {
                var ox = origin[0], oy = origin[1];
                if (ox >= left && ox <= right && oy >= top && oy <= bottom)
                    textract += c;
            }
        });
        // Build a single CSV field for the MuPDF rect
        var quadRect = "[" +
            left.toFixed(2) + " " +
            top.toFixed(2) + " " +
            right.toFixed(2) + " " +
            bottom.toFixed(2) + "]";
        var line = [
            padL(pg+1,4),
            padL(j+1,4),
            padL((q/8)+1,3),
            padR(quadRect,44),   // SAME WIDTH as PDF rect column
            csvEsc(textract)
        ].join(',');
        if (!quieter) print(line);
        txtOut.write(line + "\n");
if (Debug) print ("DEBUG: leaving printVerboseTextUnder");
    }
}


/* ---------------
       MAIN
 report / TextUnder
----------------*/
function runReportMode(doc, pageMap, verbose) {
    var total = 0;
if (Debug) { print("DEBUG: runReportMode mode = " + mode + ", pageCount = " + pageCount + ", page(s) = " + pageString + ", doc [object ...] = " + doc); }
    forEachPage(doc, pageMap, function(page, pg) {
        var pageObj = page.getObject();
if (Debug) print("DEBUG: loaded pageObj = " + pageObj + " = PDF page [" + pg +"] human \(" + (pg+1) + "\)");
        var annots = page.getAnnotations(); 
if (Debug) print("DEBUG: getAnnotations returned " + annots.length + " annotations");
        if (!annots) {
if (Debug) print("DEBUG: No annotations on this page");
            return;
        }
        // --- MAIN ANNOTATION LOOP ---
        for (var j = 0; j < annots.length; j++) {
if (Debug) print("DEBUG: Calling page.getAnnot [" + j + "]");
            var annotObj = annots[j];
            if (!annotObj) {
if (Debug) print("DEBUG: annotObj is null");
                continue;
            }
            var dict = annotObj.getObject();
if (Debug) print("DEBUG: dict entry = " + dict);
            if (!subtypeMatches(dict, annotSubtypes)) {
if (Debug) print("DEBUG: annotSubtype does not match");
                continue;
            }
            // ---------------- TextUnder MODE ----------------
var mergedText = null;
    if (Debug) print("DEBUG: New in TextUnder mode");
// 1. Try QuadPoints first
var qp = getQuadPoints(dict);
if (qp) {
    mergedText = extractTextFromQuads(page, qp);
}
    if (Debug) print("DEBUG: Returned mergedText from Quads = " + mergedText);
// 2. If QuadPoints failed, try Rect
if (mergedText === null) {
    var rect = dict.get("Rect");
    if (rect)
        mergedText = extractTextFromRect(page, rect);
}
    if (Debug) print("DEBUG: Returned mergedText from Rect = " + mergedText);
// 3. If still null → no text under annotation
// mergedText stays null
    if (Debug) print("DEBUG: Returned mergedText Null ? = " + mergedText);


            // ---------------- NORMAL report MODE ----------------
if (Debug) print("DEBUG: normal Report mode");

            var subtype  = dict.get("Subtype");
            var rect     = dict.get("Rect");
            var author   = dict.get("T");
            var modified = dict.get("M");
            var raw      = dict.get("Contents");
            var info     = classifyLiteral(raw);

            var decoded = info.decoded;
            if (decoded) decoded = decoded.replace(/\r?\n/g, "\\n");

            var line = verbose
                ? [ padL(pg+1,4), padL(j+1,4), padR(safeString(author),10), padR(safeString(subtype),10),
                    padR(safeString(modified),23), padR(safeString(rect),44), csvEsc(decoded),
                    csvEsc(info.hex || '') ].join(',')
                : [ padL(pg+1,4), padL(j+1,4), padR(safeString(subtype),10), padR(safeString(modified),23),
                    padR(safeString(rect),44), csvEsc(decoded) ].join(',');

            if (!quieter) print(line);
            txtOut.write(line + "\n");
            total++;
       
// After normal report, print TextUnder extracted text
if (Debug) print ("DEBUG: Start printing MergedTextUnder");
if (Debug) print ("DEBUG: Start with call printVerboseTextUnder");
if (mode === "textunder") {
    if (verbose)
        printVerboseTextUnder(page, pg, j, annotObj, mergedText);
    else {
if (Debug) print ("DEBUG: ELSE INLINE");
        var line = [ padL(pg+1,4), padL(j+1,4), csvEsc(mergedText)].join(',');
        if (!quieter) print(line);
        txtOut.write(line + "\n");
    }
if (Debug) print ("DEBUG: After call printVerboseTextUnder");
if (Debug) print ("DEBUG: Test if pokeText");
    // Write-back ONLY if -t or -t=STRING
    if (pokeText === true) {
        annotObj.setContents(String(mergedText));
        annotObj.update();
        pdfDirty = true;
    }
    else if (typeof pokeText === "string") {
        annotObj.setContents(String(pokeText));
        annotObj.update();
        pdfDirty = true;
    }
if (Debug) print ("DEBUG: Done printinting MergedTextUnder");
  }

 }
        if (Debug) print("DEBUG: finished annotation loop for page " + pg);
    });

    if (Debug) print("DEBUG: END total=" + total);
    if (!quieter) print("Total matches: " + total);
    txtOut.write("Total matches: " + total + "\n");

    return total;
}

/* ---------------
   MODE: DELETE
 ANNOTS OR LINKS
----------------*/
function runDeleteMode(doc, pageMap, itemGetter, itemDeleter, label) {
    var removed = 0;
    var perPage = {};
    if (!annotSubtypes) { print("Hint: Did you forget -a=Links OR -a=All ?"); throw "Delete mode aborted: missing -a subtype"; }
//  if (!annotSubtypes) { print("Hint: Did you forget -a=Links OR -a=All ?"); return;} 
    forEachPage(doc, pageMap, function(page, pg) {
        var items = itemGetter(page);
        if (Debug) print("DEBUG: loaded PDF page [" + pg +"] human \(" + (pg+1) + "\) itemGetter = " + (items ? items.length : 0) + " items");
        if (!items || !items.length) return;
        // delete from end to avoid index shift
        for (var i = items.length - 1; i >= 0; i--) {
            try {
                itemDeleter(page, items[i]);
                removed++;
                perPage[pg] = (perPage[pg] || 0) + 1;
                pdfDirty = true;
                if (Debug) print("DEBUG: deleted item " + (+i+1) + " on page " + (pg+1));
            } catch (e) {
                if (Debug) print("DEBUG: delete failed: " + e);
            }
        }

        if (Debug) print("DEBUG: finished delete loop for page " + (+pg+1));
    });

    if (!quieter) {
        for (var p in perPage)
            print("Page " + (+p+1) + ": removed " + perPage[p] + " " + label);
        print("Total " + label + " removed: " + removed);
    }

    for (var p in perPage)
        txtOut.write("Page " + p + ": removed " + perPage[p] + " " + label + "\n");
    txtOut.write("Total " + label + " removed: " + removed + "\n");

    return removed;
}


/* ---------------
 EXECUTE MODE USE
 FUNCTIONS above
----------------*/
if (mode === "report" || mode === "textunder") {
    runReportMode(doc, pageMap, verbose);

    if (maxCount) {
        if (doc.close) doc.close();
        quit();
    }
}
/* ---------------
 MODE: DEL ANNOTS
----------------*/
if (mode === "delannots") {
    runDeleteMode(
        doc,
        pageMap,
        function(page) {
            var ann = page.getAnnotations();
            if (!ann) return [];
            var out = [];
            for (var i = 0; i < ann.length; i++) {
                var obj = ann[i].getObject ? ann[i].getObject() : ann[i];
                if (subtypeMatches(obj, annotSubtypes))
                    out.push(ann[i]);
            }
            return out;
        },
        function(page, annot) {
            if (page.deleteAnnotation)
                page.deleteAnnotation(annot);
            else if (annot.remove)
                annot.remove();
        },
        "annotations"
    );
}
/* ---------------
MODE: DELETE LINKS
----------------*/
if (mode === "dellinks") {
    runDeleteMode(
        doc,
        pageMap,
        function(page) {
            return page.getLinks() || [];
        },
        function(page, link) {
            page.deleteLink(link);
        },
        "links"
    );
}

/* ---------------
MODE:  reserved
----------------*/ 
/* ---------------
below need resolving to types like above
if (mode === "delRaw") {
    runDeleteMode(
        doc,
        pageMap,
        page => getRawObjects(page),   // function
        (page, raw) => raw.delete("Key"),
        "raw objects"
    );
}
runDeleteMode(doc, pageMap,
    page => page.getAnnotations().filter(a => subtype == "Widget"),
    (page, a) => page.deleteAnnotation(a),
    "widgets"
);
above need resolving to types
----------------*/ 

/* ------------------------------
   FINAL SAVE
--------------------------------*/
if (Debug) print("Debug now at saving")
  // Determine final output filenames
  var finalReport = reportFile || defaultReportFile;
  var finalPdf = outname || defaultOutPdf;
if (Debug) { print("Resolved finalReport = " + finalReport); print("Resolved finalPdf = " + finalPdf); }
  // Write report file
if (Debug) print("at final save / close inname= " + inname + " finalPdf= " + finalPdf);
try {
    txtOut.save(finalReport);
    if (!quieter) print("Annotation report written to: " + finalReport);
} catch(e) {
    print("Failed to write report: " + e);
}
// Write PDF only if modified
print("pdfDirty=" + pdfDirty)
if (!noSave && pdfDirty) {
    try {
        if (flateSave)      doc.save(finalPdf, "appearance=all,garbage=deduplicate,decrypt,sanitize,compress-effort=100");
        else if (decomSave) doc.save(finalPdf, "appearance=all,garbage=deduplicate,decrypt,sanitize,decompress");
        else                doc.save(finalPdf, "appearance=all,garbage=deduplicate,decrypt,sanitize");
        if (!quieter) print("Saved PDF as: " + finalPdf);
    } catch(e) {
        print("Save failed: " + e);
    }
}

if (Debug) print("at final close")

