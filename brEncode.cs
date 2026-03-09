using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Collections.Generic;

class TryBrotli
{
  static void Main(string[] args)
  {
    if (args.Length < 1) { Console.WriteLine("Usage: TryBrotli input.pdf"); return; }
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

// RULE 1: skip any object that has a dictionary entry /Length2 or /Length3
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

// RULE 2: skip any object that has a Filter dictionary these files should have decompressed candidates
 if (dict.Contains("/Filter")) {
 CopyOriginalObject(pdf, outPdf, objStart, ref pos);
 continue;
 }
      int lenWordIndex = dict.IndexOf("/Length");
      if (lenWordIndex < 0)
      {
        CopyOriginalObject(pdf, outPdf, objStart, ref pos);
        continue;
      }

// RULE 3: for isFontStream fontfile ONLY use /Length1 else use normally by replace the /Length ### from return and pad more

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
  // FONT: keep strong safety
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


      // write object header and dict up to /Length anchor
      outPdf.Write(pdf, objStart, anchorGlobal - objStart);
      StringBuilder tail = new StringBuilder();

      // build new tail starting at the end of /Length
if (isFontStream)
{
      tail.Append("1 "); // the '1' of Length1 and a space
      tail.Append(originalLength);
      tail.Append("/Filter/BrotliDecode/Length ");
      tail.Append(broSize);
      tail.Append(">>\n");
}
else
{
  // NON-FONT: simple /Length replacement with Brotli filter
  // overwrite as: /Length <broSize>/Filter/BrotliDecode>>\n
  tail.Append(" ");    // space after /Length 
  tail.Append(broSize);
  tail.Append("/Filter/BrotliDecode>>\n");
}

      byte[] tailBytes = Encoding.ASCII.GetBytes(tail.ToString());
      outPdf.Write(tailBytes, 0, tailBytes.Length);

      // new stream position (after "stream\n")
      byte[] streamHeader = Encoding.ASCII.GetBytes("stream\n");
      int newStreamStart = (int)outPdf.Position + streamHeader.Length;
      int delta = newStreamStart - origStreamStart;

      outPdf.Write(streamHeader, 0, streamHeader.Length);
      outPdf.Write(broData, 0, broSize);

byte[] endStreamBytes = Encoding.ASCII.GetBytes("\nendstream\n");
outPdf.Write(endStreamBytes, 0, endStreamBytes.Length);

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
byte[] endObjBytes = Encoding.ASCII.GetBytes("endobj");
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
