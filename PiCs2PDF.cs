using System; using System.Text; using System.Collections.Generic; using System.Drawing; using System.Globalization; using System.IO; using System.IO.Compression;

class Program {
    static FileStream pdf;
    static List<long> positions = new List<long>();
    static List<string> pageRefs = new List<string>();
    static int objCount = 1;  // Start OBJ counter at 1 as we know 0 = Start position of file 

    static void Main(string[] args) {
        if (args.Length < 1) {
            Console.WriteLine("\nUsage: PiCs2PDF.exe x=Width y=Height [p=NN] o=L,T,R,B bg=RRGGBB auto=on|NN <file|folder> [output.pdf]");
            Console.WriteLine("\nUnits: Width/Height in mm, Optionally can be w=## & h=##. Also you can set either one and other to zer0");
            Console.WriteLine("Optional fixed media size can be over-riden using fixed p=ppi. Margins 0= and auto= are in mm.");
            Console.WriteLine("\nExample: PiCs2PDF.exe x=210 y=297 o=10,10,10,20 bg=ffffff auto=10 images out.pdf");
            return;
        }

        // Defaults for unattended use
        float pageWmm = 210;               // A4 width mm
        float pageHmm = 297;               // A4 height mm
        float userPpi = -1;                // Default: not set but allow for UsersChoice of set Pixels Per Inch
        float marginLeftMm = 0, marginTopMm = 0, marginRightMm = 0, marginBottomMm = 0; // Borderless
        Color? bgColor = null;             // Transparent
        bool autoRotate = false;           // No Page rotations
        float autoBottomMm = -1;           // -1 means not set
        string inputPath = null;           // Attempt input string as file or folder
        string outputPath = "output.pdf";  // Relative to caller

        foreach (string arg in args) {
            if (arg.StartsWith("x=") || arg.StartsWith("w="))
            {
                pageWmm = float.Parse(arg.Substring(2), CultureInfo.InvariantCulture);
            }
            else if (arg.StartsWith("y=") || arg.StartsWith("h="))
            {
                pageHmm = float.Parse(arg.Substring(2), CultureInfo.InvariantCulture);
            }
            else if (arg.StartsWith("p="))
            {
                userPpi = float.Parse(arg.Substring(2), CultureInfo.InvariantCulture);
            }
            else if (arg.StartsWith("o=")) {
                string[] parts = arg.Substring(2).Split(',');
                if (parts.Length == 4) {
                    marginLeftMm = float.Parse(parts[0], CultureInfo.InvariantCulture);
                    marginTopMm = float.Parse(parts[1], CultureInfo.InvariantCulture);
                    marginRightMm = float.Parse(parts[2], CultureInfo.InvariantCulture);
                    marginBottomMm = float.Parse(parts[3], CultureInfo.InvariantCulture);
                }
            }
            else if (arg.StartsWith("bg=")) {
                string hex = arg.Substring(3);
                int r = int.Parse(hex.Substring(0, 2), NumberStyles.HexNumber);
                int g = int.Parse(hex.Substring(2, 2), NumberStyles.HexNumber);
                int b = int.Parse(hex.Substring(4, 2), NumberStyles.HexNumber);
                bgColor = Color.FromArgb(r, g, b);
            }
            else if (arg.StartsWith("auto=")) {
                string val = arg.Substring(5).ToLowerInvariant();
                if (val == "on") autoRotate = true;
                else {
                    float mm;
                    if (float.TryParse(val, NumberStyles.Float, CultureInfo.InvariantCulture, out mm)) {
                        autoRotate = true;
                        autoBottomMm = mm;
                    }
                }
            }
            else if (inputPath == null) inputPath = arg;
            else outputPath = arg;
        }
        if (inputPath == null) {
            Console.WriteLine("No input file or folder specified. Call without options to see example usage");
            return;
        }
        string[] files;
        if (File.Exists(inputPath)) files = new string[] { inputPath };
        else if (Directory.Exists(inputPath)) files = Directory.GetFiles(inputPath);
        else {
            Console.WriteLine("Input not found: " + inputPath);
            return;
        }

        pdf = File.Open(outputPath, FileMode.Create);
        Write("%PDF-1.4\n");
        byte[] marker = new byte[] { (byte)'%', 0xE2, 0xE3, 0xCF, 0xD3, (byte)'\n' }; // Write high-bit binary marker line
        pdf.Write(marker, 0, marker.Length); 

        foreach (string file in files) {
            string ext = Path.GetExtension(file).ToLower();
            // We can only use single PDF viable image per page and parsable, thus we limit to those file extensions
            if (ext != ".png" && ext != ".bmp" && ext != ".jpg" &&
                ext != ".jpeg" && ext != ".tif" && ext != ".tiff" && ext != ".gif")
            {
                Console.WriteLine("Skipped unsupported format: " + file);
                continue; // move on to next file
            }
            Bitmap bmp;
            try
            {
                bmp = new Bitmap(file);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Failed to load image: " + file + " (" + ex.Message + ")");
                continue; // skip this file and move on
            }
            int imgW = bmp.Width;
            int imgH = bmp.Height;
            // Convert mm to points
            float pageW = MmToPt(pageWmm);
            float pageH = MmToPt(pageHmm);
            float marginLeft = MmToPt(marginLeftMm);
            float marginTop = MmToPt(marginTopMm);
            float marginRight = MmToPt(marginRightMm);
            float marginBottom = MmToPt(marginBottomMm);
            // Optional PPI override (user arg "p=NN")
            if (userPpi > 0)
            {
                pageW = imgW / userPpi * 72f;
                pageH = imgH / userPpi * 72f;
            }
            // Zero-dim handling
            if (pageWmm == 0 && pageHmm > 0)
            {
                pageH = MmToPt(pageHmm);
                pageW = pageH * imgW / imgH; // scale width portion
            }
            else if (pageHmm == 0 && pageWmm > 0)
            {
                pageW = MmToPt(pageWmm);
                pageH = pageW * imgH / imgW; // scale height portion
            }
            // Calculate orientation
            float curPageW = pageW;
            float curPageH = pageH;
            float curBottom = marginBottom;
            if (autoRotate && imgW > imgH) {
                float tmp = curPageW;
                curPageW = curPageH;
                curPageH = tmp;
                if (autoBottomMm >= 0) curBottom = MmToPt(autoBottomMm);
            }
            // PDF does not use Resolution or Inches but we are tied to consider such for input calculations
            float dpiX = bmp.HorizontalResolution;
            float dpiY = bmp.VerticalResolution;
            float workW = curPageW - marginLeft - marginRight;
            float workH = curPageH - marginTop - curBottom;
            float scaleX = workW / (imgW * 72f / dpiX);
            float scaleY = workH / (imgH * 72f / dpiY);
            float scale = Math.Min(scaleX, scaleY);
            float drawW = imgW * 72f / dpiX * scale;
            float drawH = imgH * 72f / dpiY * scale;
            float offsetX = marginLeft + (workW - drawW) / 2;
            float offsetY = curBottom + (workH - drawH) / 2;
            int imgObj = objCount++;     // At this stage all counters will be 1 so  /Image will be 1 4 7 etc.
            int contentObj = objCount++; // This should become 2 5 8 etc.
            int pageObj = objCount++;    // This should become 3 6 9 etc.

            // Define OBJ per /Image as length text integers. JPEG is always optimal DCT compression so passthrough. For others use Zip flate compression
            if (ext == ".jpg" || ext == ".jpeg") {
                byte[] jpegBytes = File.ReadAllBytes(file);
                positions.Add(pdf.Position);
                Write(string.Format("{0} 0 obj <</Type/XObject/Subtype/Image/Width {1}/Height {2}/ColorSpace/DeviceRGB/BitsPerComponent 8/Filter/DCTDecode/Length {3}>>\nstream\n",
                    imgObj, imgW, imgH, jpegBytes.Length));
                pdf.Write(jpegBytes, 0, jpegBytes.Length);
                Write("\nendstream\nendobj\n");
            } else {
                byte[] flateBytes = GetZlibRGB(bmp);
                positions.Add(pdf.Position);
                Write(string.Format("{0} 0 obj <</Type/XObject/Subtype/Image/Width {1}/Height {2}/ColorSpace/DeviceRGB/BitsPerComponent 8/Filter/FlateDecode/Length {3}>>\nstream\n",
                    imgObj, imgW, imgH, flateBytes.Length));
                pdf.Write(flateBytes, 0, flateBytes.Length);
                Write("\nendstream\nendobj\n");
            }

            // Define OBJ per page /Content stream. Optional background first then overlay image
            StringBuilder sb = new StringBuilder();
            if (bgColor.HasValue) {
                sb.AppendFormat(CultureInfo.InvariantCulture,
                    "{0} {1} {2} rg 0 0 {3} {4} re f\n",
                    bgColor.Value.R / 255.0, bgColor.Value.G / 255.0, bgColor.Value.B / 255.0,
                    PdfFloat(curPageW), PdfFloat(curPageH));
            }
            sb.AppendFormat(CultureInfo.InvariantCulture,
                "q {0} 0 0 {1} {2} {3} cm /Im{4} Do Q\n",
                    PdfFloat(drawW), PdfFloat(drawH), PdfFloat(offsetX), PdfFloat(offsetY), imgObj);

            string content = sb.ToString().TrimEnd('\r','\n'); // strip trailing newline, is this still needed 
            byte[] contentBytes = Encoding.ASCII.GetBytes(content);

            // Define OBJ per stream /Length
            positions.Add(pdf.Position);
            Write(string.Format("{0} 0 obj <</Length {1}>>\nstream\n", contentObj, contentBytes.Length));
            pdf.Write(contentBytes, 0, contentBytes.Length);
            Write("\nendstream\nendobj\n"); // optional white space padding would be another \n

            // Define OBJ per /Page media and resources.
            positions.Add(pdf.Position);
            Write(string.Format("{0} 0 obj <</Type/Page/Parent {1} 0 R/MediaBox[0 0 {2} {3}]/Resources<</XObject<</Im{4} {5} 0 R>>>>/Contents {6} 0 R>> endobj\n",
                pageObj, objCount + 1, PdfFloat(curPageW), PdfFloat(curPageH), imgObj, imgObj, contentObj));
            pageRefs.Add(string.Format("{0} 0 R", pageObj));
        }

        // Define OBJ per /Pages counted.
        if (pageRefs.Count == 0)
        {
            Console.WriteLine("No valid images processed. PDF aborted.");
            pdf.Close();
            File.Delete(outputPath); // optional cleanup
            return;
        }
        int pagesObj = objCount++;
        positions.Add(pdf.Position);
        Write(string.Format("{0} 0 obj <</Type/Pages/Kids[{1}]/Count {2}>> endobj\n",
            pagesObj, string.Join(" ", pageRefs.ToArray()), pageRefs.Count));

        // Define OBJ per /Catalog.
        int catalogObj = objCount++;
        positions.Add(pdf.Position);
        Write(string.Format("{0} 0 obj <</Type/Catalog/Pages {1} 0 R>> endobj\n", catalogObj, pagesObj));

        // Define Xref location and write trailer
        long startxref = pdf.Position;
        Write(string.Format("xref\n0 {0}\n0000000000 65535 f \n", objCount));
        foreach (long pos in positions)
            Write(string.Format("{0} 00000 n \n", pos.ToString("D10")));
        Write(string.Format("trailer <</Size {0}/Root {1} 0 R/Info<</Creator(PiCs2PDF)>>>>\nstartxref\n{2}\n%%EOF\n",
            objCount, catalogObj, startxref));

        // Finished
        pdf.Close();
        Console.WriteLine("PDF created successfully: " + outputPath);
    }

    static float MmToPt(float mm) {
        return mm * 72f / 25.4f;
    }

    static string PdfFloat(double x, double target = double.NaN)
    {
        const double eps = 1e-4;                                 // Set a tolerance
        if (Math.Abs(x) < eps) x = 0.0;                          // Snap to near zero
        if (!double.IsNaN(target) && Math.Abs(x - target) < eps) // Snap to near box (e.g. page width/height)
            x = target;
        return x.ToString("0.#####", System.Globalization.CultureInfo.InvariantCulture);
    }

    // Function /Flate compression
    static byte[] GetZlibRGB(Bitmap bmp) {
        MemoryStream raw = new MemoryStream();
        for (int y = 0; y < bmp.Height; y++) {
            for (int x = 0; x < bmp.Width; x++) {
                Color c = bmp.GetPixel(x, y);
                raw.WriteByte(c.R);
                raw.WriteByte(c.G);
                raw.WriteByte(c.B);
            }
        }
        byte[] uncompressed = raw.ToArray();
        MemoryStream deflated = new MemoryStream();
        deflated.WriteByte(0x78);
        deflated.WriteByte(0x9C);
        DeflateStream deflate = new DeflateStream(deflated, CompressionMode.Compress, true);
        deflate.Write(uncompressed, 0, uncompressed.Length);
        deflate.Close();
        uint adler = Adler32(uncompressed);
        deflated.WriteByte((byte)((adler >> 24) & 0xFF));
        deflated.WriteByte((byte)((adler >> 16) & 0xFF));
        deflated.WriteByte((byte)((adler >> 8) & 0xFF));
        deflated.WriteByte((byte)(adler & 0xFF));
        return deflated.ToArray();
    }
    static uint Adler32(byte[] data) {
        const uint MOD_ADLER = 65521;
        uint a = 1, b = 0;
        foreach (byte d in data) {
            a = (a + d) % MOD_ADLER;
            b = (b + a) % MOD_ADLER;
        }
        return (b << 16) | a;
    }

    static void Write(string s) {
        byte[] bytes = Encoding.ASCII.GetBytes(s);
        pdf.Write(bytes, 0, bytes.Length);
    }
}

