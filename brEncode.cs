using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Collections.Generic;

class brEncode
{
  static void Main(string[] args)
  {
    if (args.Length < 1) { Console.WriteLine("Usage: brEncode input.pdf"); return; }
    string input = args[0];
    if (!File.Exists(input)) { Console.WriteLine("Input file not found: " + input); return; }
    string output = Path.Combine(
      Path.GetDirectoryName(input),
      Path.GetFileNameWithoutExtension(input) + "-brotli.pdf"
    );
    string exeDir = Path.GetDirectoryName(
      Assembly.GetExecutingAssembly().Location
    );
    string brotliExe = Path.Combine(exeDir, "brotli.exe");
    if (!File.Exists(brotliExe))
    {
      Console.WriteLine("brotli.exe not found beside this exe.");
      return;
    }
    byte[] pdf = File.ReadAllBytes(input);
    MemoryStream outPdf = new MemoryStream(pdf.Length);

// PRE-SCAN: find all object numbers referenced by /FontFile*
HashSet<int> fontStreamObjects = new HashSet<int>();
byte[] ff1 = Encoding.ASCII.GetBytes("/FontFile ");
byte[] ff2 = Encoding.ASCII.GetBytes("/FontFile2 ");
byte[] ff3 = Encoding.ASCII.GetBytes("/FontFile3 ");
int scan = 0;
while (scan < pdf.Length)
{
  int hit = IndexOf(pdf, ff1, scan);
  if (hit < 0) hit = IndexOf(pdf, ff2, scan);
  if (hit < 0) hit = IndexOf(pdf, ff3, scan);
  if (hit < 0) break;
  // Move to the number after the space
  int numStart = hit;
  while (numStart < pdf.Length && pdf[numStart] != ' ')
    numStart++;
  numStart++;
  // Extract digits
  int numEnd = numStart;
  while (numEnd < pdf.Length &&
      pdf[numEnd] >= '0' && pdf[numEnd] <= '9')
    numEnd++;
  if (numEnd > numStart)
  {
    string numStr = Encoding.ASCII.GetString(pdf, numStart, numEnd - numStart);
    int objNum;
    if (Int32.TryParse(numStr, out objNum))
    {
      if (!fontStreamObjects.Contains(objNum))
      {
        fontStreamObjects.Add(objNum);

        // *** C# 5 SAFE PRINT ***
        Console.WriteLine("Detected font stream object: " + objNum);
      }
    }
  }
  scan = numEnd;
}
Console.WriteLine("Total font streams detected: " + fontStreamObjects.Count);



    int pos = 0;
    while (pos < pdf.Length)
    {
      int objPos = IndexOf(pdf, Encoding.ASCII.GetBytes(" obj"), pos);
      if (objPos < 0)
      {
        outPdf.Write(pdf, pos, pdf.Length - pos);
        break;
      }
// find the true start of the object line ("n 0 obj")
      int objStart = FindObjStart(pdf, objPos);
      if (objStart < 0)
      {
        outPdf.Write(pdf, objPos, pdf.Length - objPos);
        break;
      }
  // right after objStart, read up to " obj"
  string objHeader = Encoding.ASCII.GetString(pdf, objStart, objPos - objStart);

  // e.g. "9 0"
  string[] parts = objHeader.Trim().Split(' ');
  int objNum = -1;

if (parts.Length < 2 || !Int32.TryParse(parts[0], out objNum) || objNum < 0)
{
  CopyOriginalObject(pdf, outPdf, objStart, ref pos);
  continue;
}
      // copy everything before this object (up to the start of "n 0 obj" line)
      outPdf.Write(pdf, pos, objStart - pos);
      // find end of "n 0 obj" line
      int afterObjLine = objPos + 4; // " obj"
      while (afterObjLine < pdf.Length &&
          pdf[afterObjLine] != (byte)'\n' &&
          pdf[afterObjLine] != (byte)'\r')
        afterObjLine++;
      if (afterObjLine < pdf.Length && pdf[afterObjLine] == (byte)'\r') afterObjLine++;
      if (afterObjLine < pdf.Length && pdf[afterObjLine] == (byte)'\n') afterObjLine++;
      int dictStart = afterObjLine;
      int dictEnd = IndexOf(pdf, Encoding.ASCII.GetBytes(">>"), dictStart);
      if (dictEnd < 0)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }
      string dict = Encoding.ASCII.GetString(pdf, dictStart, dictEnd - dictStart + 2);

bool isFontStream = fontStreamObjects.Contains(objNum);

// RULE 1: skip any object that has a dictionary entry /Metadata
if (dict.Contains("/Type") && dict.Contains("/Metadata"))
 {
 CopyOriginalObject(pdf, outPdf, objStart, ref pos);
 continue;
 }

// RULE 2: skip any object that has a dictionary entry /Length2 or /Length3
if (isFontStream)
{
    // If the dictionary contains /Length2 or /Length3, skip Brotli entirely
    if (dict.Contains("/Length2") || dict.Contains("/Length3"))
    {
        Console.WriteLine("Skipping multi-part font stream " + objNum);
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
    }
}

// RULE 3: analyse any object that has a Filter dictionary these files may still have compressed candidates
int lenWordIndex = dict.IndexOf("/Length");
if (lenWordIndex < 0)
{
    CopyOriginalObject(pdf, outPdf, objStart, ref pos);
    continue;
}

bool hasFilter = dict.Contains("/Filter");
bool isDCT    = dict.Contains("/DCTDecode");
bool isFlate  = dict.Contains("/FlateDecode");
bool isJPX    = dict.Contains("/JPXDecode");
bool isJBIG2  = dict.Contains("/JBIG2Decode");
bool isCCITT  = dict.Contains("/CCITTFaxDecode");

// Hard skip: filters we never Brotli-wrap
if (isJPX || isJBIG2 || isCCITT) {
    CopyOriginalObject(pdf, outPdf, objStart, ref pos);
    continue;
}
// Eligible if:
//   - no filter (raw stream), or
//   - DCTDecode, or
//   - FlateDecode (optional)
bool eligibleForBrotli =
    !hasFilter ||
    isDCT ||
    isFlate;
if (!eligibleForBrotli) {
    CopyOriginalObject(pdf, outPdf, objStart, ref pos);
    continue;
}



// RULE 4: for isFontStream fontfile ONLY use /Length1 else use normally by replace the /Length ### from return and pad more
      // find start of number after /Length (or /Length1)
      int afterLengthWord = lenWordIndex + 7; // "/Length"
      // if already Length1, skip the '1' in the word
      if (afterLengthWord < dict.Length && dict[afterLengthWord] == '1')
        afterLengthWord++;
      // skip spaces before number
      int numStart = afterLengthWord;
      while (numStart < dict.Length &&
          (dict[numStart] == ' ' || dict[numStart] == '\t' ||
          dict[numStart] == '\r' || dict[numStart] == '\n'))
        numStart++;
      int numEnd = numStart;
      while (numEnd < dict.Length && dict[numEnd] >= '0' && dict[numEnd] <= '9')
        numEnd++;
      int originalLength = 0;
      if (!Int32.TryParse(dict.Substring(numStart, numEnd - numStart), out originalLength) ||
        originalLength <= 0)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }
      // anchor for rewrite: the '1' of Length1 (Length^1)
      int anchorInDict = lenWordIndex + 7; // after "Length"
      int anchorGlobal = dictStart + anchorInDict;
// This is NEW add it
int originalTailLen = (dictEnd + 2) - anchorGlobal;  // +2 to include ">>"

      // find "stream"
      int streamKeywordPos = IndexOf(pdf, Encoding.ASCII.GetBytes("stream"), dictEnd);
      if (streamKeywordPos < 0)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }

      int streamLineEnd = streamKeywordPos + 6;
      int origStreamStart = streamLineEnd;
      if (origStreamStart < pdf.Length && pdf[origStreamStart] == 0x0D &&
        origStreamStart + 1 < pdf.Length && pdf[origStreamStart + 1] == 0x0A)
        origStreamStart += 2;
      else if (origStreamStart < pdf.Length && pdf[origStreamStart] == 0x0A)
        origStreamStart += 1;
      if (origStreamStart + originalLength > pdf.Length)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }
      // find endstream and endobj
      int endStreamPos = IndexOf(pdf, Encoding.ASCII.GetBytes("endstream"), origStreamStart + originalLength);
      if (endStreamPos < 0)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }
      int afterEndStream = endStreamPos + 9; // "endstream"
      int gapStart = afterEndStream;
      while (gapStart < pdf.Length &&
          (pdf[gapStart] == 0x20 || pdf[gapStart] == 0x0A ||
          pdf[gapStart] == 0x0D || pdf[gapStart] == 0x09))
        gapStart++;
      int endObjPos = IndexOf(pdf, Encoding.ASCII.GetBytes("endobj"), gapStart);
      if (endObjPos < 0)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }
      byte[] originalGap = SubArray(pdf, afterEndStream, endObjPos - afterEndStream);
      // extract original stream to temp
      string baseName = "obj" + objNum + "_len" + originalLength;
      string tempBin = Path.Combine(Path.GetTempPath(), baseName + ".bin");
      string tempBro = Path.Combine(Path.GetTempPath(), baseName + ".bro");
      // clean stale files
      if (File.Exists(tempBin)) File.Delete(tempBin);
      if (File.Exists(tempBro)) File.Delete(tempBro);
      // write raw
      File.WriteAllBytes(tempBin, SubArray(pdf, origStreamStart, originalLength));
      // run brotli default is max
      RunBrotli(brotliExe, tempBin, tempBro);
      // validate brotli result is available
      if (!File.Exists(tempBro))
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }
      long fileSizeLong = new FileInfo(tempBro).Length;
      int broSize = (int)fileSizeLong;

      // Guard against suspiciously tiny outputs (bad feed, error, etc.) can be 1 may be 11.
      // We accept 13 or more for say 60 reduced to 14 (gain of 46)
      if (isFontStream)
      {
        // FONT: keep strong safety may no longer be required ?
        if (broSize < 13)
        {
          CopyOriginalObject(pdf, outPdf, objStart, ref pos);
          continue;
        }
      // Enforce a gain of at least 45 bytes
      // NOTE about 40 chars required for the /Length as /Length1 #########/Filter/BrotliDecode/Length ######### and max text of both /Lengths
        if (originalLength - broSize < 45)
        {
          CopyOriginalObject(pdf, outPdf, objStart, ref pos);
          continue;
        }
      }
      else
      {
        // NON-FONT: only require that Brotli actually saves space
        if (broSize >= originalLength)
        {
          CopyOriginalObject(pdf, outPdf, objStart, ref pos);
          continue;
        }
        // Optional: very small outputs are suspicious
        if (broSize < 2)
        {
          CopyOriginalObject(pdf, outPdf, objStart, ref pos);
          continue;
        }
      }

// at this point: broSize is plausible and worth using
      byte[] broData = File.ReadAllBytes(tempBro);

// --- CENTRAL DICTIONARY REWRITE POINT ---

string oldDict = dict;
string newDict = RewriteDictionary(dict, broSize, isFontStream);

// --- compute overhead based on full dictionary rewrite ---
int dictOverhead = newDict.Length - oldDict.Length;
int gain = originalLength - broSize;
const int safetyMargin = 45;

if (gain < dictOverhead + safetyMargin)
{
    CopyOriginalObject(pdf, outPdf, objStart, ref pos);
    continue;
}

// write object header explicitly
objHeader = objNum.ToString() + " 0 obj ";
byte[] objHeaderBytes = Encoding.ASCII.GetBytes(objHeader);
outPdf.Write(objHeaderBytes, 0, objHeaderBytes.Length);

// write rewritten dictionary
byte[] dictBytes = Encoding.ASCII.GetBytes(newDict);
outPdf.Write(dictBytes, 0, dictBytes.Length);

// --- now write stream header + broData ---
byte[] streamHeader = Encoding.ASCII.GetBytes("\nstream\n");
int newStreamStart = (int)outPdf.Position + streamHeader.Length;

outPdf.Write(streamHeader, 0, streamHeader.Length);
outPdf.Write(broData, 0, broSize);

// --- endstream ---
byte[] endStreamBytes = Encoding.ASCII.GetBytes("\nendstream\n");
outPdf.Write(endStreamBytes, 0, endStreamBytes.Length);

// --- padding logic stays the same ---

// original span from start of stream data to just after original "endstream"
int originalSpanToGap = afterEndStream - origStreamStart;

// new span from new stream start to just after new "endstream"
int padding =
  originalSpanToGap
  - (newStreamStart - origStreamStart)
  - broSize
  - endStreamBytes.Length;

if (padding < 0) padding = 0;

if (padding > 0)
{
  byte[] spaces = new byte[padding];
  for (int i = 0; i < padding; i++) spaces[i] = 0x20;
  outPdf.Write(spaces, 0, spaces.Length);
}

// write original gap and endobj
outPdf.Write(originalGap, 0, originalGap.Length);
// now explicitly close the object
byte[] endObjBytes = Encoding.ASCII.GetBytes("\nendobj\n");
outPdf.Write(endObjBytes, 0, endObjBytes.Length);
      pos = endObjPos + 6;
    }

    File.WriteAllBytes(output, outPdf.ToArray());
    Console.WriteLine("Wrote: " + output);
  }

  static int IndexOf(byte[] data, byte[] pattern, int start)
  {
    if (pattern.Length == 0) return -1;
    for (int i = start; i <= data.Length - pattern.Length; i++)
    {
      bool match = true;
      for (int j = 0; j < pattern.Length; j++)
      {
        if (data[i + j] != pattern[j])
        {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static int FindObjStart(byte[] data, int objPos)
  {
    int i = objPos;
    while (i > 0 && data[i] != (byte)'\n' && data[i] != (byte)'\r')
      i--;
    if (i < 0) return -1;
    return i + 1;
  }

  static byte[] SubArray(byte[] data, int index, int length)
  {
    byte[] result = new byte[length];
    Buffer.BlockCopy(data, index, result, 0, length);
    return result;
  }

  static void RunBrotli(string brotliExe, string input, string output)
  {
    ProcessStartInfo psi = new ProcessStartInfo();
    psi.FileName = brotliExe;
    psi.Arguments = "-Z \"" + input + "\" -o \"" + output + "\""; // Z slould be "best"
    psi.CreateNoWindow = true;
    psi.UseShellExecute = false;
    psi.RedirectStandardOutput = true;
    psi.RedirectStandardError = true;

    try
    {
      using (Process p = Process.Start(psi))
      {
        p.WaitForExit();
      }
    }
    catch (Exception ex)
    {
      Console.WriteLine("Error running brotli: " + ex.Message);
    }
  }

  static string RewriteDictionary(string dict, int broSize, bool isFontStream)
{
    string d = dict;

    // 1. Rewrite /Filter

    if (!d.Contains("/Filter"))
    {
        // No filter: insert /Filter/BrotliDecode before >>
        int insertPos = d.LastIndexOf(">>", StringComparison.Ordinal);
        if (insertPos > 0)
            d = d.Insert(insertPos, "/Filter/BrotliDecode");
    }
    else if (d.Contains("/Filter["))
    {
        // Already an array: insert Brotli at start of array
        int arrayStart = d.IndexOf("/Filter[", StringComparison.Ordinal);
        int bracketPos = d.IndexOf('[', arrayStart);
        if (bracketPos > 0)
            d = d.Insert(bracketPos + 1, "/BrotliDecode ");
    }
    else if (d.Contains("/Filter/"))
    {
        // Compact single filter: /Filter/DCTDecode or /Filter/FlateDecode etc.
        // Turn "/Filter/Name" into "/Filter[/BrotliDecode /Name]"
        int filterPos = d.IndexOf("/Filter/", StringComparison.Ordinal);
        if (filterPos >= 0)
        {
            int nameStart = filterPos + "/Filter/".Length;
            int nameEnd = nameStart;

            // read until next '/' or '>' or whitespace
            while (nameEnd < d.Length &&
                   d[nameEnd] != '/' &&
                   d[nameEnd] != '>' &&
                   !char.IsWhiteSpace(d[nameEnd]))
            {
                nameEnd++;
            }

            string filterName = d.Substring(nameStart, nameEnd - nameStart); // e.g. "DCTDecode"

            string replacement = "/Filter[/BrotliDecode /" + filterName + "]";
            d = d.Remove(filterPos, ("/Filter/".Length + filterName.Length))
                 .Insert(filterPos, replacement);
        }
    }

    // 2. Rewrite /Length or /Length1

    if (isFontStream)
    {
        d = RewriteLengthEntry(d, "/Length1", broSize);
        d = RemoveLengthEntry(d, "/Length");
    }
    else
    {
        d = RewriteLengthEntry(d, "/Length", broSize);
        d = RemoveLengthEntry(d, "/Length1");
    }

    return d;
}

  static string RewriteLengthEntry(string dict, string key, int broSize)
{
    int pos = dict.IndexOf(key, StringComparison.Ordinal);
    if (pos < 0) return dict;

    int numStart = pos + key.Length;
    while (numStart < dict.Length && char.IsWhiteSpace(dict[numStart]))
        numStart++;

    int numEnd = numStart;
    while (numEnd < dict.Length && char.IsDigit(dict[numEnd]))
        numEnd++;

    if (numEnd > numStart)
    {
        dict = dict.Remove(numStart, numEnd - numStart)
                   .Insert(numStart, broSize.ToString());
    }
    else
    {
        dict = dict.Insert(numStart, " " + broSize.ToString());
    }

    return dict;
}

  static string RemoveLengthEntry(string dict, string key)
{
    int pos = dict.IndexOf(key, StringComparison.Ordinal);
    if (pos < 0) return dict;

    int end = pos + key.Length;
    while (end < dict.Length && char.IsWhiteSpace(dict[end]))
        end++;
    while (end < dict.Length && char.IsDigit(dict[end]))
        end++;

    return dict.Remove(pos, end - pos);
}


  static void CopyOriginalObject(byte[] pdf, MemoryStream outPdf, int objStart, ref int pos)
  {
    int endObj = IndexOf(pdf, Encoding.ASCII.GetBytes("endobj"), objStart);
    if (endObj < 0)
    {
      outPdf.Write(pdf, objStart, pdf.Length - objStart);
      pos = pdf.Length;
      return;
    }
    int len = endObj + 6 - objStart;
    outPdf.Write(pdf, objStart, len);
    pos = endObj + 6;
  }
}
