
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Printing;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

static class PDF
{
    const string D = "pdfium.dll";

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDF_InitLibrary();

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern IntPtr FPDF_LoadDocument(byte[] path, IntPtr password);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDF_CloseDocument(IntPtr doc);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDF_GetPageCount(IntPtr doc);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern IntPtr FPDF_LoadPage(IntPtr doc, int index);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDF_ClosePage(IntPtr page);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern double FPDF_GetPageWidth(IntPtr page);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern double FPDF_GetPageHeight(IntPtr page);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern IntPtr FPDFBitmap_Create(int w, int h, int alpha);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDFBitmap_Destroy(IntPtr bitmap);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDFBitmap_FillRect(
        IntPtr bitmap, int x, int y, int w, int h, uint color);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern IntPtr FPDFBitmap_GetBuffer(IntPtr bitmap);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDFBitmap_GetStride(IntPtr bitmap);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDF_RenderPageBitmap(
        IntPtr bitmap, IntPtr page,
        int x, int y, int w, int h, int rotate, int flags);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDF_RenderPage(
        IntPtr hdc, IntPtr page,
        int x, int y, int w, int h, int rotate, int flags);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern uint FPDF_GetLastError();

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern IntPtr FPDFText_LoadPage(IntPtr page);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDFText_ClosePage(IntPtr text);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDFText_CountChars(IntPtr text);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDFText_GetCharIndexAtPos(
        IntPtr text, double x, double y,
        double xTolerance, double yTolerance);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDFText_GetText(
        IntPtr text, int start, int count, ushort[] buffer);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern IntPtr FPDFText_FindStart(
        IntPtr text, byte[] search, uint flags, int startIndex);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDFText_FindNext(IntPtr search);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern int FPDFText_GetSchResultIndex(IntPtr search);

    [DllImport(D, CallingConvention=CallingConvention.StdCall)]
    public static extern void FPDFText_FindClose(IntPtr search);

[DllImport(D, CallingConvention=CallingConvention.StdCall)]
public static extern int FPDFText_GetCharBox(
    IntPtr text, int index,
    out double left, out double right,
    out double bottom, out double top);

}

class Program
{
    [STAThread]
    static void Main()
    {
        try
        {
            PDF.FPDF_InitLibrary();

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Viewer());
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.ToString(), "PDFium");
        }
    }
}

class Viewer : Form
{
    IntPtr doc = IntPtr.Zero;

    int pageCount;
    int pageNo;
    int rotation;
    int selectionStart = -1;
    int selectionEnd = -1;

    double zoom = 1.5;
    double pageWidth;
    double pageHeight;
int highlightStart = -1;
int highlightCount = 0;

//bool selecting = false;
    bool fitMode;
    bool fitWidth;

    PictureBox picture;
    Panel scroll;
    FlowLayoutPanel thumbs;
    Label status;
    ToolStrip toolbar;

    PrintDocument printer;
    int printPage;

    public Viewer()
    {
        Text = "PdfiumLite";
        Width = 1100;
        Height = 800;
        StartPosition = FormStartPosition.CenterScreen;

        AllowDrop = true;
        DragEnter += OnDragEnter;
        DragDrop += OnDragDrop;

        toolbar = new ToolStrip();
        toolbar.Dock = DockStyle.Top;

        AddButton("Open", Open);
        AddButton("−", delegate { SetZoom(zoom / 1.2); });
        AddButton("+", delegate { SetZoom(zoom * 1.2); });
        AddButton("Fit page", delegate {
            fitMode = true;
            fitWidth = false;
            ShowPage(pageNo);
        });
        AddButton("Fit width", delegate {
            fitMode = true;
            fitWidth = true;
            ShowPage(pageNo);
        });
        AddButton("Rotate", Rotate);
        AddButton("Find", Search);
        AddButton("Print", Print);

        SplitContainer split = new SplitContainer();
        split.Dock = DockStyle.Fill;

split.Orientation = Orientation.Vertical;
split.FixedPanel = FixedPanel.Panel1;
//split.IsSplitterFixed = false;
split.SplitterWidth = 5;

// Set initial size before panel constraints
split.Size = new Size(1000, 700);

split.Panel1MinSize = 90;
split.Panel2MinSize = 250;
split.SplitterDistance = 145;

split.SizeChanged += delegate
{
    if (split.Width > 400 &&
        split.SplitterDistance > 220)
        split.SplitterDistance = 145;
};
        thumbs = new FlowLayoutPanel();
        thumbs.Dock = DockStyle.Fill;
        thumbs.AutoScroll = true;
        thumbs.FlowDirection = FlowDirection.TopDown;
        thumbs.WrapContents = false;
        thumbs.BackColor = Color.LightGray;

        split.Panel1.Controls.Add(thumbs);

        scroll = new Panel();
        scroll.Dock = DockStyle.Fill;
        scroll.AutoScroll = true;
        scroll.BackColor = Color.DimGray;

        picture = new PictureBox();
        picture.SizeMode = PictureBoxSizeMode.Normal;
        picture.BackColor = Color.White;
        picture.Location = new Point(10, 10);

        picture.MouseDown += SelectStart;
        picture.MouseUp += SelectEnd;
        picture.MouseWheel += Wheel;

        scroll.Controls.Add(picture);
        split.Panel2.Controls.Add(scroll);

        status = new Label();
        status.Dock = DockStyle.Bottom;
        status.Height = 25;
        status.Text = "Ready";

        Controls.Add(split);
        Controls.Add(status);
        Controls.Add(toolbar);

        FormClosing += delegate { CloseDocument(); };
    }

void DrawHighlights(Graphics g, IntPtr page)
{
    if (highlightStart < 0 || highlightCount <= 0)
        return;

    IntPtr text = PDF.FPDFText_LoadPage(page);

    if (text == IntPtr.Zero)
        return;

    try
    {
        using (SolidBrush brush =
            new SolidBrush(Color.FromArgb(100, 255, 220, 0)))
        {
            for (int i = highlightStart;
                 i < highlightStart + highlightCount; i++)
            {
                double left, right, bottom, top;

                if (PDF.FPDFText_GetCharBox(
                    text, i,
                    out left, out right,
                    out bottom, out top) == 0)
                    continue;

                float x = (float)(left * zoom);
                float y = (float)((pageHeight - top) * zoom);

                float w = (float)((right - left) * zoom);
                float h = (float)((top - bottom) * zoom);

                g.FillRectangle(brush, x, y, w, h);
            }
        }
    }
    finally
    {
        PDF.FPDFText_ClosePage(text);
    }
}

    void AddButton(string name, EventHandler handler)
    {
        ToolStripButton b = new ToolStripButton(name);
        b.Click += handler;
        toolbar.Items.Add(b);
    }

    void OnDragEnter(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
            e.Effect = DragDropEffects.Copy;
    }

    void OnDragDrop(object sender, DragEventArgs e)
    {
        string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);

        if (files.Length > 0)
            LoadPdf(files[0]);
    }

    void Open(object sender, EventArgs e)
    {
        using (OpenFileDialog d = new OpenFileDialog())
        {
            d.Filter = "PDF files|*.pdf";

            if (d.ShowDialog() == DialogResult.OK)
                LoadPdf(d.FileName);
        }
    }

    void LoadPdf(string filename)
    {
        try
        {
            CloseDocument();

            doc = PDF.FPDF_LoadDocument(
                Encoding.UTF8.GetBytes(filename + "\0"),
                IntPtr.Zero);

            if (doc == IntPtr.Zero)
                throw new Exception("PDFium error " +
                    PDF.FPDF_GetLastError());

            pageCount = PDF.FPDF_GetPageCount(doc);
            pageNo = 0;
            rotation = 0;
            zoom = 1.5;
            fitMode = false;

            BuildThumbnails();
            ShowPage(0);

            Text = "PdfiumLite - " + filename;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Open PDF");
        }
    }

    Bitmap Render(IntPtr page, double scale, int rotate)
    {
        double w = PDF.FPDF_GetPageWidth(page);
        double h = PDF.FPDF_GetPageHeight(page);

        if (rotate == 1 || rotate == 3)
        {
            double t = w;
            w = h;
            h = t;
        }

        int width = Math.Max(1, (int)Math.Ceiling(w * scale));
        int height = Math.Max(1, (int)Math.Ceiling(h * scale));

        if (width > 12000 || height > 12000)
            throw new Exception("Page render is too large.");

        IntPtr bmp = PDF.FPDFBitmap_Create(width, height, 0);

        if (bmp == IntPtr.Zero)
            throw new Exception("Cannot create bitmap.");

        try
        {
            PDF.FPDFBitmap_FillRect(
                bmp, 0, 0, width, height, 0xFFFFFFFF);

            PDF.FPDF_RenderPageBitmap(
                bmp, page, 0, 0, width, height, rotate, 1);

            IntPtr buffer = PDF.FPDFBitmap_GetBuffer(bmp);
            int stride = PDF.FPDFBitmap_GetStride(bmp);

            if (buffer == IntPtr.Zero || stride < width * 4)
                throw new Exception("Invalid bitmap buffer.");

            Bitmap result = new Bitmap(
                width, height, PixelFormat.Format32bppRgb);

            BitmapData data = result.LockBits(
                new Rectangle(0, 0, width, height),
                ImageLockMode.WriteOnly,
                PixelFormat.Format32bppRgb);

            try
            {
                byte[] row = new byte[width * 4];

                for (int y = 0; y < height; y++)
                {
                    Marshal.Copy(
                        new IntPtr(buffer.ToInt64() + (long)y * stride),
                        row, 0, row.Length);

                    Marshal.Copy(
                        row, 0,
                        new IntPtr(data.Scan0.ToInt64() +
                                   (long)y * data.Stride),
                        row.Length);
                }
            }
            finally
            {
                result.UnlockBits(data);
            }

            return result;
        }
        finally
        {
            PDF.FPDFBitmap_Destroy(bmp);
        }
    }

    void ShowPage(int number)
    {
        if (doc == IntPtr.Zero ||
            number < 0 || number >= pageCount)
            return;

        IntPtr page = IntPtr.Zero;

        try
        {
            page = PDF.FPDF_LoadPage(doc, number);

            if (page == IntPtr.Zero)
                throw new Exception("Cannot load page.");

            pageWidth = PDF.FPDF_GetPageWidth(page);
            pageHeight = PDF.FPDF_GetPageHeight(page);

            if (fitMode)
            {
                double w = pageWidth;
                double h = pageHeight;

                if (rotation == 1 || rotation == 3)
                {
                    double t = w;
                    w = h;
                    h = t;
                }

                double sx = Math.Max(1, scroll.ClientSize.Width - 30) / w;
                double sy = Math.Max(1, scroll.ClientSize.Height - 30) / h;

                zoom = fitWidth ? sx : Math.Min(sx, sy);
            }

            Bitmap image = Render(page, zoom, rotation);

            Image old = picture.Image;
            picture.Image = image;
            picture.Size = image.Size;

            if (old != null)
                old.Dispose();

            picture.Location = new Point(10, 10);
            scroll.AutoScrollPosition = new Point(0, 0);

using (Graphics g = Graphics.FromImage(picture.Image))
{
    DrawHighlights(g, page);
}

            pageNo = number;
            selectionStart = selectionEnd = -1;

            status.Text = "Page " + (pageNo + 1) +
                " / " + pageCount +
                "     Zoom " + (int)(zoom * 100) + "%";
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Render page");
        }
        finally
        {
            if (page != IntPtr.Zero)
                PDF.FPDF_ClosePage(page);
        }
    }

    void SetZoom(double value)
    {
        fitMode = false;
        zoom = Math.Max(0.15, Math.Min(8.0, value));
        ShowPage(pageNo);
    }

    void Wheel(object sender, MouseEventArgs e)
    {
        if ((Control.ModifierKeys & Keys.Control) != 0)
        {
            SetZoom(zoom * (e.Delta > 0 ? 1.15 : 0.87));
        }
        else
        {
            scroll.AutoScrollPosition = new Point(
                Math.Abs(scroll.AutoScrollPosition.X),
                Math.Max(0, Math.Abs(scroll.AutoScrollPosition.Y)
                    - (e.Delta > 0 ? 100 : -100)));
        }
    }

    void Rotate(object sender, EventArgs e)
    {
        rotation = (rotation + 1) % 4;
        ShowPage(pageNo);
    }

    void BuildThumbnails()
    {
        thumbs.Controls.Clear();

        for (int i = 0; i < pageCount; i++)
        {
            IntPtr page = PDF.FPDF_LoadPage(doc, i);

            if (page == IntPtr.Zero)
                continue;

            try
            {
                Bitmap image = Render(page, 0.20, 0);

                PictureBox p = new PictureBox();
                p.Image = image;
                p.SizeMode = PictureBoxSizeMode.Zoom;
                p.Size = new Size(135, 155);
                p.BackColor = Color.White;
                p.BorderStyle = BorderStyle.FixedSingle;
                p.Margin = new Padding(8);
                p.Tag = i;
                p.Click += ThumbnailClick;

                Label label = new Label();
                label.Text = "Page " + (i + 1);
                label.TextAlign = ContentAlignment.MiddleCenter;
                label.Width = 135;
                label.Height = 20;

                thumbs.Controls.Add(p);
                thumbs.Controls.Add(label);
            }
            finally
            {
                PDF.FPDF_ClosePage(page);
            }
        }
    }

    void ThumbnailClick(object sender, EventArgs e)
    {
        PictureBox p = (PictureBox)sender;
        ShowPage((int)p.Tag);
    }

    int GetCharacter(Point point)
    {
        IntPtr page = PDF.FPDF_LoadPage(doc, pageNo);

        if (page == IntPtr.Zero)
            return -1;

        try
        {
            IntPtr text = PDF.FPDFText_LoadPage(page);

            if (text == IntPtr.Zero)
                return -1;

            try
            {
                double x = point.X / zoom;
                double y = pageHeight - point.Y / zoom;

                return PDF.FPDFText_GetCharIndexAtPos(
                    text, x, y, 5, 5);
            }
            finally
            {
                PDF.FPDFText_ClosePage(text);
            }
        }
        finally
        {
            PDF.FPDF_ClosePage(page);
        }
    }

    void SelectStart(object sender, MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
            selectionStart = GetCharacter(e.Location);
    }

    void SelectEnd(object sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left ||
            selectionStart < 0)
            return;

        selectionEnd = GetCharacter(e.Location);

        if (selectionEnd < 0)
            return;

        int start = Math.Min(selectionStart, selectionEnd);
        int count = Math.Abs(selectionEnd - selectionStart) + 1;

        IntPtr page = PDF.FPDF_LoadPage(doc, pageNo);
        if (page == IntPtr.Zero) return;

        try
        {
            IntPtr text = PDF.FPDFText_LoadPage(page);
            if (text == IntPtr.Zero) return;

            try
            {
                ushort[] chars = new ushort[count + 1];

                PDF.FPDFText_GetText(
                    text, start, count, chars);

                char[] result = new char[count];

                for (int i = 0; i < count; i++)
                    result[i] = (char)chars[i];

                string selected = new string(result).TrimEnd('\0');

                if (selected.Length > 0)
                {
                    Clipboard.SetText(selected);
                    status.Text = "Copied " +
                        selected.Length + " characters";
                }
            }
            finally
            {
                PDF.FPDFText_ClosePage(text);
            }
        }
        finally
        {
            PDF.FPDF_ClosePage(page);
        }
    }

    void Search(object sender, EventArgs e)
    {
        if (doc == IntPtr.Zero) return;

        using (Form dialog = new Form())
        {
            dialog.Text = "Find text";
            dialog.Width = 350;
            dialog.Height = 125;
            dialog.StartPosition = FormStartPosition.CenterParent;

            TextBox input = new TextBox();
            input.SetBounds(10, 10, 310, 25);

            Button find = new Button();
            find.Text = "Find next";
            find.SetBounds(220, 45, 100, 27);
            find.DialogResult = DialogResult.OK;

            dialog.Controls.Add(input);
            dialog.Controls.Add(find);
            dialog.AcceptButton = find;

            if (dialog.ShowDialog(this) != DialogResult.OK ||
                input.Text.Length == 0)
                return;

            string query = input.Text;
            byte[] encoded = Encoding.Unicode.GetBytes(query + "\0");

            for (int n = 0; n < pageCount; n++)
            {
                int index = (pageNo + n) % pageCount;

                IntPtr page = PDF.FPDF_LoadPage(doc, index);
                if (page == IntPtr.Zero) continue;

                try
                {
                    IntPtr text = PDF.FPDFText_LoadPage(page);
                    if (text == IntPtr.Zero) continue;

                    try
                    {
                        IntPtr search = PDF.FPDFText_FindStart(
                            text, encoded, 0, 0);

                        if (search == IntPtr.Zero) continue;

                        try
                        {
                            if (PDF.FPDFText_FindNext(search) != 0)
                            {
                                int found =
                                    PDF.FPDFText_GetSchResultIndex(search);

highlightStart = found;
highlightCount = query.Length;

ShowPage(index);
picture.Invalidate();

status.Text = "Found '" + query +
    "' at character " + found;
return;

                            }
                        }
                        finally
                        {
                            PDF.FPDFText_FindClose(search);
                        }
                    }
                    finally
                    {
                        PDF.FPDFText_ClosePage(text);
                    }
                }
                finally
                {
                    PDF.FPDF_ClosePage(page);
                }
            }

            MessageBox.Show("Text not found.");
        }
    }
void Print(object sender, EventArgs e)
{
    if (doc == IntPtr.Zero)
        return;

    printer = new PrintDocument();
    printer.DocumentName = "PDF document";

    printer.BeginPrint += delegate
    {
        printPage = 0;
    };

    printer.PrintPage += PrintPage;

    using (PrintDialog d = new PrintDialog())
    {
        d.Document = printer;
        d.UseEXDialog = true;

        if (d.ShowDialog() == DialogResult.OK)
            printer.Print();
    }

    printer.Dispose();
    printer = null;
}
void PrintPage(object sender, PrintPageEventArgs e)
{
    if (printPage >= pageCount)
    {
        e.HasMorePages = false;
        return;
    }

    IntPtr page = PDF.FPDF_LoadPage(doc, printPage);

    if (page == IntPtr.Zero)
        throw new Exception("Cannot load print page.");

    try
    {
        double pdfWidth = PDF.FPDF_GetPageWidth(page);
        double pdfHeight = PDF.FPDF_GetPageHeight(page);

        // Printer resolution
        double dpiX = e.Graphics.DpiX;
        double dpiY = e.Graphics.DpiY;

        // Convert PDF points (72 per inch) to printer pixels
        double widthPixels = pdfWidth * dpiX / 72.0;
        double heightPixels = pdfHeight * dpiY / 72.0;

        Rectangle bounds = e.MarginBounds;

        // Available printable area in printer pixels
        double scale = Math.Min(
            bounds.Width / widthPixels,
            bounds.Height / heightPixels);

        int width = (int)(widthPixels * scale);
        int height = (int)(heightPixels * scale);

        int x = bounds.Left + (bounds.Width - width) / 2;
        int y = bounds.Top + (bounds.Height - height) / 2;

        IntPtr hdc = e.Graphics.GetHdc();

        try
        {
            PDF.FPDF_RenderPage(
                hdc,
                page,
                x, y,
                width, height,
                0, 1);
        }
        finally
        {
            e.Graphics.ReleaseHdc(hdc);
        }

        printPage++;

        e.HasMorePages = printPage < pageCount;
    }
    finally
    {
        PDF.FPDF_ClosePage(page);
    }
}



    void CloseDocument()
    {
        if (doc != IntPtr.Zero)
        {
            PDF.FPDF_CloseDocument(doc);
            doc = IntPtr.Zero;
        }

        if (picture != null && picture.Image != null)
        {
            Image old = picture.Image;
            picture.Image = null;
            old.Dispose();
        }

        if (thumbs != null)
        {
            foreach (Control c in thumbs.Controls)
            {
                PictureBox p = c as PictureBox;

                if (p != null && p.Image != null)
                {
                    Image old = p.Image;
                    p.Image = null;
                    old.Dispose();
                }
            }

            thumbs.Controls.Clear();
        }
    }
}
