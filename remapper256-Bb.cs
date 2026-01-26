using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

class DecoderGrid : Form
{
    TextBox[] mapBoxes;          // 256 cells, each 4 hex digits
    Dictionary<byte, char> map;  // 1-byte token -> UTF-16 char
    TextBox txtMojibake;
    TextBox txtInput;
    TextBox txtOutput;
    TextBox txtUtf16;
    Button btnConvert;
    Button btnImport;
    Button btnExport;
    Button btnReset;
    bool initializing = true;
    public DecoderGrid()
    {
        Text = "Decoder Grid (16×16, CSV import/export)";
        Width = 1024;
        Height = 850;
        StartPosition = FormStartPosition.CenterScreen;
        map = new Dictionary<byte, char>();
        mapBoxes = new TextBox[256];
        Font mono = new Font("Consolas", 9);
        // --- Top: Input / Output ---
        Label lblMoj = new Label();
        lblMoj.Text = "Mojibake Input (auto-convert to UTF-16BE hex):";
        lblMoj.Location = new Point(10, 10);
        lblMoj.Width = 500;
        Controls.Add(lblMoj);
        txtMojibake = new TextBox();
        txtMojibake.Name = "txtMojibake";
        txtMojibake.Font = mono;
        txtMojibake.Multiline = true;
        txtMojibake.ScrollBars = ScrollBars.Vertical;
        txtMojibake.Location = new Point(10, 33);
        txtMojibake.Width = 900;
        txtMojibake.Height = 70;
        Controls.Add(txtMojibake);
        btnConvert = new Button();
        btnConvert.Text = "To Hex →";
        btnConvert.Location = new Point(920, 50);
        btnConvert.Click += new EventHandler(BtnConvert_Click);
        Controls.Add(btnConvert);
        Label lblIn = new Label();
        lblIn.Text = "Input hex (double-byte tokens, e.g. 00410042 0043 or <004100420043>):";
        lblIn.Location = new Point(10, 107);
        lblIn.Width = 600;
        Controls.Add(lblIn);
        txtInput = new TextBox();
        txtInput.Font = mono;
        txtInput.Multiline = true;
        txtInput.ScrollBars = ScrollBars.Vertical;
        txtInput.Location = new Point(10, 130);
        txtInput.Width = 985;
        txtInput.Height = 70;
        txtInput.TextChanged += delegate(object s, EventArgs e)
        {
            if (initializing) return;
            Decode();
        };
        Controls.Add(txtInput);
        Label lblOut = new Label();
        lblOut.Text = "Output (Unicode text):";
        lblOut.Location = new Point(10, 204);
        lblOut.Width = 200;
        Controls.Add(lblOut);
        txtOutput = new TextBox();
        txtOutput.Font = mono;
        txtOutput.Multiline = true;
        txtOutput.ScrollBars = ScrollBars.Vertical;
        txtOutput.Location = new Point(10, 227);
        txtOutput.Width = 985;
        txtOutput.Height = 70;
        txtOutput.ReadOnly = true;
        Controls.Add(txtOutput);
        Label lblUtf16 = new Label();
        lblUtf16.Text = "Output UTF-16 hex:";
        lblUtf16.Location = new Point(10, 301);
        lblUtf16.Width = 200;
        Controls.Add(lblUtf16);
        txtUtf16 = new TextBox();
        txtUtf16.Font = mono;
        txtUtf16.Multiline = true;
        txtUtf16.ScrollBars = ScrollBars.Vertical;
        txtUtf16.Location = new Point(10, 324);
        txtUtf16.Width = 985;
        txtUtf16.Height = 70;
        txtUtf16.ReadOnly = true;
        Controls.Add(txtUtf16);
        btnImport = new Button();
        btnImport.Text = "Import CSV…";
        btnImport.Location = new Point(10, 400);
        btnImport.Click += new EventHandler(BtnImport_Click);
        Controls.Add(btnImport);
        btnExport = new Button();
        btnExport.Text = "Export CSV…";
        btnExport.Location = new Point(120, 400);
        btnExport.Click += new EventHandler(BtnExport_Click);
        Controls.Add(btnExport);
        btnReset = new Button();
        btnReset.Text = "Reset to default";
        btnReset.Location = new Point(230, 400);
        btnReset.Click += new EventHandler(BtnReset_Click);
        Controls.Add(btnReset);
        // --- Grid: 16×16 UTF-16 hex cells ---
        int gridTop = 430;
        int x0 = 10;
        int y0 = gridTop;
        int xStep = 60;
        int yStep = 22;
        int cols = 16;
        int rows = 16;
        for (int c = 0; c < cols; c++)
        {
            Label hdr = new Label();
            hdr.Text = "_" + c.ToString("X1");
            hdr.Location = new Point(x0 + 50 + c * xStep, y0);
            hdr.Width = 40;
            Controls.Add(hdr);
        }
        int bodyTop = y0 + 23;
        mapBoxes = new TextBox[256];
        for (int r = 0; r < rows; r++)
        {
            int rowBase = r * cols;
            int rowByte = r * 0x10;
            Label rowLbl = new Label();
            rowLbl.Text = rowByte.ToString("X2");
            rowLbl.Location = new Point(x0, bodyTop + r * yStep + 4);
            rowLbl.Width = 30;
            Controls.Add(rowLbl);
            for (int c = 0; c < cols; c++)
            {
                int index = rowBase + c; // 0..255
                TextBox tb = new TextBox();
                tb.Font = mono;
                tb.Location = new Point(x0 + 40 + c * xStep, bodyTop + r * yStep);
                tb.Width = 40;
                tb.MaxLength = 4;
                tb.TextChanged += delegate(object s, EventArgs e)
                {
                    if (initializing) return;
                    UpdateMapping();
                };
                Controls.Add(tb);
                mapBoxes[index] = tb;
            }
        }
        for (int i = 0; i < 256; i++)
        {
        //    if (i >= 0x20)
        //        mapBoxes[i].Text = i.ToString("X4");
        //    else
                mapBoxes[i].Text = "";
        }
        initializing = false;
        UpdateMapping();
    }

    void ConvertMojibakeToHex(string input)
    {
    StringBuilder sb = new StringBuilder();
        foreach (char ch in input)
        {
        ushort code = (ushort)ch;
        if (sb.Length > 0)
            sb.Append(' ');
        sb.Append(code.ToString("X4"));
        }
        txtInput.Text = sb.ToString();
    }

    void BtnConvert_Click(object sender, EventArgs e)
    {
        if (string.IsNullOrEmpty(txtMojibake.Text))
        return;
        StringBuilder sb = new StringBuilder();
        foreach (char ch in txtMojibake.Text)
        {
            ushort code = (ushort)ch;
            if (sb.Length > 0)
                sb.Append(' ');
            sb.Append(code.ToString("X4"));
        }
        txtInput.Text = sb.ToString();
    }

    void BtnReset_Click(object sender, EventArgs e)
    {
        initializing = true;
        for (int i = 0; i < 256; i++)
        {
            if (i >= 0x20)
                mapBoxes[i].Text = i.ToString("X4");
            else
                mapBoxes[i].Text = "";
        }
        initializing = false;
        UpdateMapping();
    }

    void BtnImport_Click(object sender, EventArgs e)
    {
        OpenFileDialog ofd = new OpenFileDialog();
        ofd.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*";
        ofd.Title = "Import 16×16 UTF-16 hex grid";
        if (ofd.ShowDialog() != DialogResult.OK)
            return;
        try
        {
            string[] lines = File.ReadAllLines(ofd.FileName);
            if (lines.Length != 16)
            {
                MessageBox.Show("CSV must have exactly 16 lines.", "Import error",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            initializing = true;
            for (int r = 0; r < 16; r++)
            {
                string line = lines[r];
                string[] parts = line.Split(',');
                if (parts.Length != 16)
                {
                    MessageBox.Show("Each line must have exactly 16 comma-separated values.",
                        "Import error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    initializing = false;
                    return;
                }
                for (int c = 0; c < 16; c++)
                {
                    int index = r * 16 + c;
                    string cell = parts[c].Trim();
                    if (cell.Length == 0)
                    {
                        mapBoxes[index].Text = "";
                    }
                    else
                    {
                        // Normalize to 4 hex digits
                        string hex = cell.ToUpper();
                        if (hex.Length < 4)
                            hex = hex.PadLeft(4, '0');
                        // Validate hex
                        ushort dummy;
                        if (!ushort.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out dummy))
                        {
                            MessageBox.Show("Invalid hex value at row " + r + ", column " + c + ": " + cell,
                                "Import error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                            initializing = false;
                            return;
                        }
                        mapBoxes[index].Text = hex;
                    }
                }
            }
            initializing = false;
            UpdateMapping();
        }
        catch (Exception ex)
        {
            initializing = false;
            MessageBox.Show("Error importing CSV:\r\n" + ex.Message, "Import error",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    void BtnExport_Click(object sender, EventArgs e)
    {
        SaveFileDialog sfd = new SaveFileDialog();
        sfd.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*";
        sfd.Title = "Export 16×16 UTF-16 hex grid";
        sfd.FileName = "grid.csv";
        if (sfd.ShowDialog() != DialogResult.OK)
            return;
        try
        {
            StringBuilder sb = new StringBuilder();
            for (int r = 0; r < 16; r++)
            {
                if (r > 0)
                    sb.AppendLine();
                for (int c = 0; c < 16; c++)
                {
                    int index = r * 16 + c;
                    string cell = mapBoxes[index].Text.Trim().ToUpper();
                    if (c > 0)
                        sb.Append(',');
                    if (cell.Length == 0)
                    {
                        // empty cell
                    }
                    else
                    {
                        if (cell.Length < 4)
                            cell = cell.PadLeft(4, '0');
                        sb.Append(cell);
                    }
                }
            }
            File.WriteAllText(sfd.FileName, sb.ToString(), Encoding.UTF8);
        }
        catch (Exception ex)
        {
            MessageBox.Show("Error exporting CSV:\r\n" + ex.Message, "Export error",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

public static string ExtractPdfText(string raw)
{
    if (raw == null)
        return "";

    StringBuilder output = new StringBuilder();
    int len = raw.Length;

    int i = 0;
    int mode = 0; // 0 = outside, 1 = hex <>, 2 = literal ()

    while (i < len)
    {
        char ch = raw[i];

        // MODE 0 — OUTSIDE ANY STRING
        if (mode == 0)
        {
            if (ch == '<')
            {
                mode = 1;
                i++;
                continue;
            }
            if (ch == '(')
            {
                mode = 2;
                i++;
                continue;
            }
            i++;
            continue;
        }

        // MODE 1 — INSIDE <HEXSTRING>
        if (mode == 1)
        {
            if (ch == '>')
            {
                mode = 0;
                i++;
                continue;
            }

            // accept only hex digits
            if ((ch >= '0' && ch <= '9') ||
                (ch >= 'A' && ch <= 'F') ||
                (ch >= 'a' && ch <= 'f'))
            {
                output.Append(ch);
            }

            i++;
            continue;
        }

        // MODE 2 — INSIDE (LITERAL STRING)
        if (mode == 2)
        {
            if (ch == '\\')
            {
                // OCTAL ESCAPE
                int start = i + 1;
                int octLen = 0;

                while (start + octLen < len &&
                       octLen < 3 &&
                       raw[start + octLen] >= '0' &&
                       raw[start + octLen] <= '7')
                {
                    octLen++;
                }

                if (octLen > 0)
                {
                    string oct = raw.Substring(start, octLen);
                    int value = Convert.ToInt32(oct, 8);
                    output.Append(value.ToString("X2"));
                    i += 1 + octLen;
                    continue;
                }

                // ESCAPED CHARACTERS: \( \) \\
                if (start < len)
                {
                    char esc = raw[start];
                    int val = (int)esc;
                    output.Append(val.ToString("X2"));
                    i += 2;
                    continue;
                }

                i++;
                continue;
            }

            if (ch == ')')
            {
                mode = 0;
                i++;
                continue;
            }

            // literal character
            output.Append(((int)ch).ToString("X2"));
            i++;
            continue;
        }
    }

    return output.ToString();
}


void UpdateMapping()
{
    map.Clear();
    for (int cid = 0; cid < 256; cid++)
    {
        string hex = mapBoxes[cid].Text.Trim();
        if (hex.Length == 0)
            continue;
        if (hex.Length < 4)
            hex = hex.PadLeft(4, '0');
        ushort unicode;
        if (ushort.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out unicode))
        {
            map[(byte)cid] = (char)unicode;
        }
    }
    Decode();
}


void Decode()
{
    if (txtInput == null || txtOutput == null || txtUtf16 == null)
        return;
    string raw = txtInput.Text;
    if (string.IsNullOrWhiteSpace(raw))
    {
        txtOutput.Text = "";
        txtUtf16.Text = "";
        return;
    }
    // Clean input: remove < > whitespace etc.
    StringBuilder cleaned = new StringBuilder();
    foreach (char ch in raw)
    {
        if ("<> \n\r\t,;".IndexOf(ch) >= 0)
            continue;
        cleaned.Append(ch);
    }
    string hexStream = cleaned.ToString().Trim();
    if (hexStream.Length < 4)
    {
        txtOutput.Text = "";
        txtUtf16.Text = "";
        return;
    }
    StringBuilder sbText = new StringBuilder();
    StringBuilder sbUtf16 = new StringBuilder();
    // Process 4‑digit UTF‑16BE tokens
    for (int i = 0; i + 3 < hexStream.Length; i += 4)
    {
        string token = hexStream.Substring(i, 4);   // e.g. "0021"
        ushort index;
        // Parse UTF‑16BE token as grid index
        if (!ushort.TryParse(token, System.Globalization.NumberStyles.HexNumber, null, out index))
        {
            // Bad token → output '?'
            sbText.Append('?');
            if (sbUtf16.Length > 0) sbUtf16.Append(' ');
            sbUtf16.Append("003F");
            continue;
        }
        // Out of range → '?'
        if (index > 255)
        {
            sbText.Append('?');
            if (sbUtf16.Length > 0) sbUtf16.Append(' ');
            sbUtf16.Append("003F");
            continue;
        }
        // Lookup Unicode in grid cell
        string unicodeHex = mapBoxes[index].Text.Trim();
        if (unicodeHex.Length == 0)
        {
            // EMPTY CELL → '?'
            sbText.Append('?');
            if (sbUtf16.Length > 0) sbUtf16.Append(' ');
            sbUtf16.Append("003F");
            continue;
        }
        // Normalize to 4 digits
        if (unicodeHex.Length < 4)
            unicodeHex = unicodeHex.PadLeft(4, '0');
        ushort unicodeValue;
        if (!ushort.TryParse(unicodeHex, System.Globalization.NumberStyles.HexNumber, null, out unicodeValue))
        {
            // Bad Unicode → '?'
            sbText.Append('?');
            if (sbUtf16.Length > 0) sbUtf16.Append(' ');
            sbUtf16.Append("003F");
            continue;
        }
        // Convert Unicode to char
        char chOut = (char)unicodeValue;
        sbText.Append(chOut);
        if (sbUtf16.Length > 0) sbUtf16.Append(' ');
        sbUtf16.Append(unicodeValue.ToString("X4"));
    }
    txtOutput.Text = sbText.ToString();
    txtUtf16.Text = sbUtf16.ToString();
}

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.Run(new DecoderGrid());
    }
}
